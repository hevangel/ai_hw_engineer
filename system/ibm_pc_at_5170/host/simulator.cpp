// Persistent simulator of the IBM PC AT 5170 with the IBM VGA card, for the
// web front end (host/server.py) and for long unattended batch runs.
//
// The machine is host/ibm_pc_at_5170_vga_host.sv: src/ibm_pc_at_5170_vga.sv
// unchanged plus read-only taps. It is clocked exactly as tb/post_runner.cpp
// clocks the VGA machine in scripts/run_post_card.sh (processor ready with
// no added wait states, the 8254 clock from OSC / 12 on the AT19 time base,
// two video clocks per processor clock, the same refresh acknowledge and
// the same memory map and open-bus rules), but it writes no trace or
// oracle logs. A keyboard (host/at_keyboard.hpp) is attached to the
// keyboard connector.
//
// Memory: 640 KB base RAM at 000000h, the 64 KB BIOS ROM at 0F0000h and
// FF0000h, and optionally N KB of expansion RAM from 100000h (--ext-kb=N,
// for example 1408 for a 2 MB machine). The expansion RAM is host memory
// like the base RAM (no memory card is modeled); the CMOS image still
// records 640 KB, so the BIOS reports the difference as it would on a
// real machine whose setup has not been run.
//
// usage:
//   simulator BIOS_ROM VGA_ROM [options]            line protocol on stdin
//   simulator BIOS_ROM VGA_ROM --batch=CLOCKS --out=DIR [options]
// options:
//   --ext-kb=N         expansion RAM from 100000h (default 0, max 14336)
//   --script=FILE      scripted key input (see host/README section in the
//                      system README): "at CLOCK", "wait CLOCKS",
//                      "when \"TEXT\"" rules, each followed by keys
//   --save-every=N     batch: write status and the latest frame every N
//                      processor clocks (default 50,000,000)
//   --until-script     batch: end when the last script rule has fired and
//                      its keys have been typed
//   --fst=PATH         where CAPTURE writes its waveform
// Diskette media options (--fda/--fdb) belong to the diskette adapter's
// branch; see the integration point marked DISKETTE below.
//
// Commands (one reply line each, JSON):
//   STATE | RUN n | RESET | KEY code make | TYPE tokens... | FRAME | TEXT
//   PPM path | PEEK addr len | CAPTURE n | QUIT
#include "Vibm_pc_at_5170_vga_host.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include "at_keyboard.hpp"
#include <zlib.h>
#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

// DISKETTE: integration point for the diskette adapter branch
// (system/ibm-pc-at-5170-fdc). Its media model tb/at_diskette_media.hpp is
// included here when the build defines AT_DISKETTE; Machine::clock() calls
// diskette_service() once per processor clock after the memory cycle (the
// DMA host interface), and main() hands --fda/--fdb to diskette_options().
#ifdef AT_DISKETTE
#include "at_diskette_media.hpp"
#endif

using Dut = Vibm_pc_at_5170_vga_host;

namespace {
constexpr uint32_t kBaseEnd = 0xa0000, kExtBase = 0x100000;
constexpr uint8_t kOpenBus = 0xff;   // ASSUMPTION AT14
// Must match ibm_pc_at_5170_vga and post_runner.cpp (AT19).
constexpr uint64_t kVidHz = 24000000, kOscHz = 14318180;
// Processor clock on the AT19 time base, for real-time fractions.
constexpr double kAt19Hz = 24e6;
// Picoseconds per quarter processor clock in waveform captures (24 MHz).
constexpr uint64_t kQuarterPs = 10417;
// Script key events are spaced 30 ms apart on the keyboard's time base
// (6 processor clocks per microsecond, AT20).
constexpr uint64_t kKeyGap = 30 * 6000;

std::string hex(uint32_t v, int width) {
    char buf[16];
    std::snprintf(buf, sizeof buf, "%0*X", width, v);
    return buf;
}

std::string hexbytes(const std::vector<uint8_t>& v) {
    std::string s;
    for (size_t i = 0; i < v.size(); i++) s += (i ? " " : "") + hex(v[i], 2);
    return s;
}

std::vector<uint8_t> read_file(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) throw std::runtime_error("cannot read " + path);
    return {std::istreambuf_iterator<char>(f), {}};
}

std::string json_string(const std::string& s) {
    std::string o = "\"";
    for (char c : s) {
        if (c == '"' || c == '\\') { o += '\\'; o += c; }
        else if (uint8_t(c) < 0x20) o += ' ';
        else o += c;
    }
    return o + '"';
}

std::string base64(const std::vector<uint8_t>& v) {
    static const char* t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string o;
    o.reserve((v.size() + 2) / 3 * 4);
    for (size_t i = 0; i < v.size(); i += 3) {
        uint32_t n = uint32_t(v[i]) << 16;
        if (i + 1 < v.size()) n |= uint32_t(v[i + 1]) << 8;
        if (i + 2 < v.size()) n |= v[i + 2];
        o += t[(n >> 18) & 63];
        o += t[(n >> 12) & 63];
        o += i + 1 < v.size() ? t[(n >> 6) & 63] : '=';
        o += i + 2 < v.size() ? t[n & 63] : '=';
    }
    return o;
}

// Set 2 make codes of the 84-key AT keyboard ([TR] 4-12) by name, for
// scripts and the TYPE command.
const std::map<std::string, uint8_t>& key_names() {
    static const std::map<std::string, uint8_t> m = {
        {"Esc", 0x76}, {"Tab", 0x0d}, {"Enter", 0x5a}, {"Space", 0x29}, {"Backspace", 0x66},
        {"Ctrl", 0x14}, {"Alt", 0x11}, {"Shift", 0x12}, {"LShift", 0x12}, {"RShift", 0x59},
        {"CapsLock", 0x58}, {"NumLock", 0x77}, {"ScrollLock", 0x7e}, {"SysRq", 0x84},
        {"F1", 0x05}, {"F2", 0x06}, {"F3", 0x04}, {"F4", 0x0c}, {"F5", 0x03},
        {"F6", 0x0b}, {"F7", 0x83}, {"F8", 0x0a}, {"F9", 0x01}, {"F10", 0x09},
        {"KP7", 0x6c}, {"KP8", 0x75}, {"KP9", 0x7d}, {"KP-", 0x7b}, {"KP4", 0x6b},
        {"KP5", 0x73}, {"KP6", 0x74}, {"KP+", 0x79}, {"KP1", 0x69}, {"KP2", 0x72},
        {"KP3", 0x7a}, {"KP0", 0x70}, {"KP.", 0x71}, {"KP*", 0x7c},
        {"Home", 0x6c}, {"Up", 0x75}, {"PgUp", 0x7d}, {"Left", 0x6b}, {"Right", 0x74},
        {"End", 0x69}, {"Down", 0x72}, {"PgDn", 0x7a}, {"Ins", 0x70}, {"Del", 0x71},
    };
    return m;
}

// Character -> (set 2 code, shifted) for typed text, US layout ([TR] 4-17).
bool char_key(char c, uint8_t& code, bool& shift) {
    static const std::string plain = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./ ";
    static const std::string shifted = "~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>? ";
    static const uint8_t codes[] = {
        0x0e, 0x16, 0x1e, 0x26, 0x25, 0x2e, 0x36, 0x3d, 0x3e, 0x46, 0x45, 0x4e, 0x55,
        0x15, 0x1d, 0x24, 0x2d, 0x2c, 0x35, 0x3c, 0x43, 0x44, 0x4d, 0x54, 0x5b, 0x5d,
        0x1c, 0x1b, 0x23, 0x2b, 0x34, 0x33, 0x3b, 0x42, 0x4b, 0x4c, 0x52,
        0x1a, 0x22, 0x21, 0x2a, 0x32, 0x31, 0x3a, 0x41, 0x49, 0x4a, 0x29};
    if (c == '\n') { code = 0x5a; shift = false; return true; }
    size_t i = plain.find(c);
    if (i != std::string::npos) { code = codes[i]; shift = false; return true; }
    i = shifted.find(c);
    if (i != std::string::npos) { code = codes[i]; shift = true; return true; }
    return false;
}

// Key tokens -> make/break events: NAME, A+B+C (held together, released in
// reverse) or "quoted text" (escapes \n, \" and \\).
std::vector<std::pair<uint8_t, bool>> parse_keys(const std::string& text) {
    std::vector<std::pair<uint8_t, bool>> ev;
    size_t i = 0;
    while (i < text.size()) {
        if (std::isspace(uint8_t(text[i]))) { ++i; continue; }
        if (text[i] == '"') {
            ++i;
            while (i < text.size() && text[i] != '"') {
                char c = text[i++];
                if (c == '\\' && i < text.size()) { c = text[i++]; if (c == 'n') c = '\n'; }
                uint8_t code; bool shift;
                if (!char_key(c, code, shift)) throw std::runtime_error(std::string("no key for '") + c + "'");
                if (shift) ev.push_back({0x12, true});
                ev.push_back({code, true});
                ev.push_back({code, false});
                if (shift) ev.push_back({0x12, false});
            }
            ++i;
            continue;
        }
        size_t j = i;
        while (j < text.size() && !std::isspace(uint8_t(text[j]))) ++j;
        std::string tok = text.substr(i, j - i);
        i = j;
        std::vector<uint8_t> combo;
        size_t s = 0;
        while (true) {
            size_t p = tok.find('+', s + 1);   // "KP+" keeps its plus
            std::string name = tok.substr(s, p == std::string::npos ? std::string::npos : p - s);
            auto it = key_names().find(name);
            uint8_t code; bool shift;
            if (it != key_names().end()) code = it->second;
            else if (name.size() == 1 && char_key(name[0], code, shift)) {}
            else if (name.size() == 2 && std::isxdigit(uint8_t(name[0])) && std::isxdigit(uint8_t(name[1])))
                code = uint8_t(std::stoul(name, nullptr, 16));
            else throw std::runtime_error("unknown key " + name);
            combo.push_back(code);
            if (p == std::string::npos) break;
            s = p + 1;
        }
        for (uint8_t c : combo) ev.push_back({c, true});
        for (auto it = combo.rbegin(); it != combo.rend(); ++it) ev.push_back({*it, false});
    }
    return ev;
}

// Reads 80 x 25 text from a 720 x 400 frame with the 8 x 16 font of the
// VGA ROM, as scripts/check_frame.py does (9-dot cells, the ROM's
// replacement glyphs, ninth column repeated for C0h-DFh). Unknown cells
// (the cursor, graphics) read as '?'.
class ScreenReader {
public:
    explicit ScreenReader(const std::vector<uint8_t>& rom) {
        static const uint8_t g01[16] = {0, 0, 0x7e, 0x81, 0xa5, 0x81, 0x81, 0xbd, 0x99, 0x81, 0x81, 0x7e, 0, 0, 0, 0};
        std::vector<uint8_t> key(16, 0);
        key.insert(key.end(), g01, g01 + 16);
        auto it = std::search(rom.begin(), rom.end(), key.begin(), key.end());
        if (it == rom.end()) return;
        const size_t at = size_t(it - rom.begin());
        std::map<int, std::array<uint8_t, 16>> patch;
        for (size_t i = at + 16 * 256; i + 17 <= rom.size() && rom[i]; i += 17) {
            std::array<uint8_t, 16> r{};
            std::copy(rom.begin() + long(i) + 1, rom.begin() + long(i) + 17, r.begin());
            patch[rom[i]] = r;
        }
        for (int c = 255; c >= 0; c--) {
            Glyph g{};
            for (int y = 0; y < 16; y++) {
                const uint8_t r = patch.count(c) ? patch[c][y] : rom[at + 16 * c + y];
                g[y] = uint16_t((r << 1) | ((c >= 0xc0 && c <= 0xdf) ? (r & 1) : 0));
            }
            font_[g] = c;
        }
    }
    bool ok() const { return !font_.empty(); }
    std::vector<std::string> read(const std::vector<std::vector<uint32_t>>& f) const {
        std::vector<std::string> rows;
        if (font_.empty() || f.size() != 400) return rows;
        for (int r = 0; r < 25; r++) {
            std::string text;
            for (int c = 0; c < 80; c++) {
                uint32_t lo = 0xffffffff, hi = 0;
                for (int y = 0; y < 16; y++)
                    for (int x = 0; x < 9; x++) {
                        const uint32_t p = px(f, c * 9 + x, r * 16 + y);
                        lo = std::min(lo, p); hi = std::max(hi, p);
                    }
                Glyph g{};
                bool two = true;
                for (int y = 0; y < 16; y++)
                    for (int x = 0; x < 9; x++) {
                        const uint32_t p = px(f, c * 9 + x, r * 16 + y);
                        if (p != lo && p != hi) two = false;
                        if (p == hi && hi != lo) g[y] |= uint16_t(1 << (8 - x));
                    }
                auto it = font_.find(g);
                const int code = two && it != font_.end() ? it->second : -1;
                text += code >= 0x20 && code < 0x7f ? char(code) : (code == 0 || code == 0xff) ? ' ' : code < 0 ? '?' : '.';
            }
            while (!text.empty() && text.back() == ' ') text.pop_back();
            rows.push_back(text);
        }
        return rows;
    }
private:
    using Glyph = std::array<uint16_t, 16>;
    std::map<Glyph, int> font_;
    static uint32_t px(const std::vector<std::vector<uint32_t>>& f, int x, int y) {
        return size_t(x) < f[y].size() ? f[y][x] : 0;
    }
};

// RGB PNG, zlib level 1.
std::vector<uint8_t> png(const std::vector<std::vector<uint32_t>>& f, unsigned w) {
    const unsigned h = unsigned(f.size());
    std::vector<uint8_t> raw;
    raw.reserve(size_t(h) * (w * 3 + 1));
    for (const auto& line : f) {
        raw.push_back(0);
        for (unsigned x = 0; x < w; x++) {
            const uint32_t v = x < line.size() ? line[x] : 0;
            raw.push_back(uint8_t(v >> 16)); raw.push_back(uint8_t(v >> 8)); raw.push_back(uint8_t(v));
        }
    }
    uLongf len = compressBound(uLong(raw.size()));
    std::vector<uint8_t> z(len);
    if (compress2(z.data(), &len, raw.data(), uLong(raw.size()), 1) != Z_OK) throw std::runtime_error("zlib");
    z.resize(len);
    std::vector<uint8_t> out = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
    auto chunk = [&](const char* tag, const std::vector<uint8_t>& body) {
        const uint32_t n = uint32_t(body.size());
        for (int s = 24; s >= 0; s -= 8) out.push_back(uint8_t(n >> s));
        std::vector<uint8_t> tb(tag, tag + 4);
        tb.insert(tb.end(), body.begin(), body.end());
        out.insert(out.end(), tb.begin(), tb.end());
        const uint32_t crc = uint32_t(crc32(0, tb.data(), uInt(tb.size())));
        for (int s = 24; s >= 0; s -= 8) out.push_back(uint8_t(crc >> s));
    };
    std::vector<uint8_t> ihdr;
    for (uint32_t v : {w, h})
        for (int s = 24; s >= 0; s -= 8) ihdr.push_back(uint8_t(v >> s));
    for (uint8_t b : {8, 2, 0, 0, 0}) ihdr.push_back(b);
    chunk("IHDR", ihdr);
    chunk("IDAT", z);
    chunk("IEND", {});
    return out;
}
}  // namespace

class Machine {
public:
    std::unique_ptr<VerilatedContext> ctx;   // declared before d: destroyed after it
    std::unique_ptr<Dut> d;
    std::vector<uint8_t> rom, ram, ext;
    AtKeyboard kbd;
    ScreenReader screen;
    std::string fst_path;
    // Counters since the last power-on.
    uint64_t cycle = 0, retired = 0, frames = 0, cpu_resets = 0, inta_cycles = 0;
    uint64_t open_reads = 0, open_writes = 0, rom_writes = 0, slot_reads = 0, slot_writes = 0;
    uint64_t chan_writes = 0, port60_reads = 0, halt_clocks = 0, power_ons = 0;
    int last_port60 = -1;
    std::vector<uint8_t> port60_log;   // the last 32 values the processor read from port 60h
    uint16_t cs = 0xf000, ip = 0xfff0;
    std::string stop;               // why the machine stopped (it then stays stopped)
    std::vector<std::vector<uint32_t>> last_frame;
    unsigned frame_width = 0;
    // Waveform capture.
    std::unique_ptr<VerilatedFstC> fst;
    uint64_t fst_time = 0, capture_start = 0, capture_clocks = 0, capture_version = 0;
    // Key events waiting to be applied, spaced kKeyGap clocks apart.
    std::deque<std::pair<uint8_t, bool>> key_queue;
    uint64_t next_key = 0;

    Machine(std::vector<uint8_t> bios, const std::vector<uint8_t>& vga_rom, unsigned ext_kb, std::string fst)
        : rom(std::move(bios)), ext(size_t(ext_kb) * 1024, 0), screen(vga_rom), fst_path(std::move(fst)) {
        if (rom.size() != 65536) throw std::runtime_error("expected a 64 KiB BIOS image");
        if (ext_kb > 14336) throw std::runtime_error("--ext-kb is at most 14336 (to EFFFFFh)");
        power_on();
    }

    // Power-on: a fresh model (as at the start of post_runner), RAM zero
    // (ASSUMPTION AT6), the keyboard's power-on reset. The MC146818 starts
    // again from its battery image (tb/cmos_ega.hex).
    void power_on() {
        close_capture();
        // Each power-on gets its own context: tracing a second model in a
        // shared context crashed (Verilator 5.052).
        d.reset();
        ctx = std::make_unique<VerilatedContext>();
        ctx->traceEverOn(true);
        d = std::make_unique<Dut>(ctx.get());
        ram.assign(kBaseEnd, 0);
        std::fill(ext.begin(), ext.end(), 0);
        kbd.power_on();
        key_queue.clear();
        cycle = retired = frames = cpu_resets = inta_cycles = 0;
        open_reads = open_writes = rom_writes = slot_reads = slot_writes = chan_writes = 0;
        port60_reads = halt_clocks = 0;
        last_port60 = -1;
        port60_log.clear();
        cs = 0xf000; ip = 0xfff0;
        stop.clear();
        lines.assign(1, {});
        last_frame.clear();
        frame_width = 0;
        was_hsync = was_vsync = false;
        timer_acc = 0; timer_level = false; refresh_cycles = 0;
        inta_active = false; was_reset = true;
        ++power_ons;
        d->clk_i = 0; d->clk_2x_i = 0; d->reset_i = 1; d->ready_n_i = 0;
        d->dma_clk_n_i = 0; d->hold_permit_i = 1; d->refresh_ready_i = 0;
        d->timer_clk_i = 0; d->mem_rdata_i = 0; d->vid_clk_i = 0;
        // Board configuration as in post_runner: keyboard unlocked,
        // monochrome display switch, no manufacturing jumper, 2nd 256K on.
        d->kbd_unlocked_i = 1; d->display_mono_i = 1; d->mfg_jumper_i = 0; d->ram_512k_i = 1;
        d->kbd_clk_i = 1; d->kbd_data_i = 1;
        d->chan_irq_i = 0;
        d->eval();
        for (int i = 0; i < 16; i++) { half_clock(true); half_clock(false); }
        d->reset_i = 0;
    }

    bool is_ram(uint32_t a) const { return a < kBaseEnd || (a >= kExtBase && a - kExtBase < ext.size()); }
    static bool is_rom(uint32_t a) { return (a >= 0x0f0000 && a <= 0x0fffff) || a >= 0xff0000; }
    uint8_t& ram_byte(uint32_t a) { return a < kBaseEnd ? ram[a] : ext[a - kExtBase]; }
    uint8_t byte(uint32_t x) { return is_ram(x) ? ram_byte(x) : is_rom(x) ? rom[x & 0xffff] : kOpenBus; }

    // Runs up to n processor clocks; returns the clocks run.
    uint64_t run(uint64_t n) {
        uint64_t i = 0;
        for (; i < n && stop.empty(); i++) clock();
        return i;
    }

    void queue_keys(const std::vector<std::pair<uint8_t, bool>>& ev) {
        if (key_queue.empty() && next_key < cycle) next_key = cycle;
        key_queue.insert(key_queue.end(), ev.begin(), ev.end());
    }

    std::vector<std::string> text() const { return screen.read(last_frame); }

    void capture(uint64_t n) {
        if (n < 1 || n > 1000000) throw std::runtime_error("capture 1..1000000 clocks");
        if (!stop.empty()) throw std::runtime_error("the machine has stopped: " + stop);
        const std::string tmp = fst_path + ".next";
        fst = std::make_unique<VerilatedFstC>();
        d->trace(fst.get(), 1);
        fst->set_time_unit("1ps");
        fst->set_time_resolution("1ps");
        fst->open(tmp.c_str());
        if (!fst->isOpen()) throw std::runtime_error("cannot open " + tmp);
        fst_time = 0;
        capture_start = cycle;
        dump();
        const uint64_t done = run(n);
        fst->close();
        fst.reset();
        std::filesystem::rename(tmp, fst_path);
        capture_clocks = done;
        ++capture_version;
    }

    void write_ppm(const std::string& path) const {
        std::ofstream f(path, std::ios::binary);
        f << "P6\n" << frame_width << ' ' << last_frame.size() << "\n255\n";
        for (const auto& line : last_frame)
            for (unsigned x = 0; x < frame_width; x++) {
                const uint32_t v = x < line.size() ? line[x] : 0;
                f.put(char(v >> 16)); f.put(char(v >> 8)); f.put(char(v));
            }
        if (!f) throw std::runtime_error("cannot write " + path);
    }

    std::vector<uint8_t> frame_png() const { return png(last_frame, frame_width); }

    std::string state_json(double clocks_per_s) const {
        std::ostringstream s;
        s << "{\"clocks\":" << cycle << ",\"instructions\":" << retired << ",\"frames\":" << frames
          << ",\"post\":\"" << hex(d->post_code_o, 2) << "\",\"cs\":\"" << hex(cs, 4) << "\",\"ip\":\""
          << hex(ip, 4) << "\",\"halted\":" << (d->halted_o ? "true" : "false")
          << ",\"interruptsEnabled\":" << ((d->flags_o & 0x200) ? "true" : "false")
          << ",\"stopped\":" << json_string(stop) << ",\"cpuResets\":" << cpu_resets
          << ",\"interruptAcks\":" << inta_cycles << ",\"openReads\":" << open_reads
          << ",\"slotReads\":" << slot_reads << ",\"slotWrites\":" << slot_writes
          << ",\"extKB\":" << ext.size() / 1024 << ",\"powerOns\":" << power_ons
          << ",\"port60Reads\":" << port60_reads << ",\"lastPort60\":" << last_port60
          << ",\"port60Log\":\"" << hexbytes(port60_log) << "\""
          << ",\"frameWidth\":" << frame_width << ",\"frameHeight\":" << last_frame.size()
          << ",\"clocksPerSecond\":" << uint64_t(clocks_per_s)
          << ",\"realTimeFraction\":" << clocks_per_s / kAt19Hz
          << ",\"simSeconds\":" << double(cycle) / kAt19Hz
          << ",\"keyboard\":{\"state\":\"" << kbd.state_name() << "\",\"leds\":" << unsigned(kbd.leds())
          << ",\"scanning\":" << (kbd.scanning() ? "true" : "false")
          << ",\"sent\":" << kbd.bytes_sent() << ",\"received\":" << kbd.bytes_received()
          << ",\"lastSent\":" << kbd.last_sent() << ",\"lastReceived\":" << kbd.last_received()
          << ",\"queued\":" << kbd.queued() << ",\"pendingKeys\":" << key_queue.size()
          << ",\"resets\":" << kbd.resets() << ",\"aborted\":" << kbd.aborted()
          << ",\"typematic\":" << unsigned(kbd.typematic_byte())
          << ",\"receivedLog\":\"" << hexbytes(kbd.received_log()) << "\",\"sentLog\":\""
          << hexbytes(kbd.sent_log()) << "\"}"
          << ",\"kbdFlags\":\"" << hex(ram[0x417], 2) << hex(ram[0x418], 2) << "\",\"kbdHead\":\""
          << hex(ram[0x41a] | (ram[0x41b] << 8), 4) << "\",\"kbdTail\":\"" << hex(ram[0x41c] | (ram[0x41d] << 8), 4)
          << "\",\"kbdBuffer\":\"" << [&] { std::string h; for (unsigned i = 0x41e; i < 0x43e; i++) h += hex(ram[i], 2); return h; }()
          << "\",\"captureStart\":" << capture_start << ",\"captureClocks\":" << capture_clocks
          << ",\"captureVersion\":" << capture_version << "}";
        return s.str();
    }

private:
    std::vector<std::vector<uint32_t>> lines;
    bool was_hsync = false, was_vsync = false;
    uint64_t timer_acc = 0;
    bool timer_level = false;
    unsigned refresh_cycles = 0;
    bool inta_active = false, was_reset = true;

    void close_capture() {
        if (fst) { fst->close(); fst.reset(); }
    }
    void dump() {
        if (fst) { fst->dump(fst_time); fst_time += kQuarterPs; }
    }

    uint32_t pixel() const {
        auto scale = [](unsigned c) { return (c << 2) | (c >> 4); };
        return (scale(d->r_o) << 16) | (scale(d->g_o) << 8) | scale(d->b_o);
    }
    // One rising edge of the video clock has just been evaluated
    // (post_runner's video_sample).
    void video_sample() {
        if (!d->pix_en_o) return;
        if (d->vsync_o && !was_vsync) {
            if (lines.size() > 1) {
                size_t first = 0, last = lines.size();
                while (first < last && lines[first].empty()) ++first;
                while (last > first && lines[last - 1].empty()) --last;
                unsigned w = 0;
                for (size_t y = first; y < last; y++) w = std::max(w, unsigned(lines[y].size()));
                last_frame.assign(lines.begin() + long(first), lines.begin() + long(last));
                frame_width = w;
                ++frames;
            }
            lines.assign(1, {});
        } else if (d->hsync_o && !was_hsync) {
            lines.emplace_back();
        }
        was_hsync = d->hsync_o; was_vsync = d->vsync_o;
        if (d->de_o) lines.back().push_back(pixel());
    }
    // post_runner's half_clock with VID_SECOND = 1 (the VGA build).
    void half_clock(bool rising) {
        d->clk_i = rising; d->clk_2x_i = 1;
        d->vid_clk_i = 1;
        d->eval();
        video_sample();
        dump();
        d->clk_2x_i = 0;
        d->vid_clk_i = 0;
        d->eval();
        dump();
    }

    // One processor clock: the body of post_runner's main loop, with the
    // stop conditions of the regression turned into a stopped state.
    void clock() {
        d->ready_n_i = 0;
        d->dma_clk_n_i = cycle & 1;
        timer_acc += 2 * (kOscHz / 12);
        if (timer_acc >= kVidHz) { timer_acc -= kVidHz; timer_level = !timer_level; }
        d->timer_clk_i = timer_level ? 7 : 0;
        d->eval();
        if (d->refresh_o) d->refresh_ready_i = ++refresh_cycles >= 3;
        else { refresh_cycles = 0; d->refresh_ready_i = 0; }
        d->eval();

        const std::string where = hex(cs, 4) + ":" + hex(ip, 4);
        if (d->protocol_error_o) stop = "protocol-error at=" + where;
        else if (d->fault_o) stop = "fault at=" + where;
        else if (d->kbc_illegal_o) stop = "kbc-illegal-opcode at=" + where;
        if (!stop.empty()) return;

        const uint32_t a = d->address_o;
        const uint32_t base = a & ~1u;
        d->mem_rdata_i = d->io_cycle_o ? uint16_t(kOpenBus | (kOpenBus << 8))
                                       : uint16_t(byte(base) | (byte(base + 1) << 8));
        const uint32_t port = d->io_port_o;
        const bool empty_slot = d->io_unclaimed_o && port >= 0x100;
        // The slots are readable (post_runner's AT_CARD default).
        if (d->io_unclaimed_o && !empty_slot) {
            stop = std::string("io-") + (d->data_oe_o ? "write" : "read") + " port=" + hex(port, 4) + " at=" + where;
            return;
        }
        if (d->io_read_undriven_o) { stop = "io-undriven port=" + hex(port, 4) + " at=" + where; return; }
        const bool chan_driven = d->chan_sel_o && d->chan_driven_o;
        const bool chan_mem = d->chan_sel_o && !d->io_cycle_o;
        if (d->completed_bytes_o && !d->io_cycle_o && d->fetch_cycle_o && !chan_driven) {
            const bool low = !(a & 1), high = (a & 1) || !d->bhe_n_o;
            for (uint32_t b : {base, base + 1})
                if (((b == base && low) || (b == base + 1 && high)) && !is_ram(b) && !is_rom(b))
                    stop = "fetch-unpopulated addr=" + hex(b, 6) + " at=" + where;
            if (!stop.empty()) return;
        }
        d->eval();

        if (d->completed_bytes_o) {
            const bool io = d->io_cycle_o, write = d->data_oe_o, fetch = d->fetch_cycle_o;
            for (unsigned b = 0; b < d->completed_bytes_o; b++) {
                const uint32_t x = a + b;
                const uint16_t bus = write ? d->data_o : d->cpu_data_o;
                const uint8_t value = uint8_t(bus >> ((x & 1) * 8));
                if (write && !io) {
                    if (is_ram(x)) ram_byte(x) = value;
                    else if (is_rom(x)) ++rom_writes;
                    else if (chan_mem) ++chan_writes;
                    else ++open_writes;
                }
                if (!write && !io && !fetch && !is_ram(x) && !is_rom(x) && !d->inta_cycle_o && !chan_driven)
                    ++open_reads;
                if (io && write && empty_slot) ++slot_writes;
                if (io && !write && empty_slot && !chan_driven) ++slot_reads;
                if (io && !write && x == 0x60) {
                    ++port60_reads; last_port60 = value;
                    if (port60_log.size() == 32) port60_log.erase(port60_log.begin());
                    port60_log.push_back(value);
                }
            }
        }
#ifdef AT_DISKETTE
        diskette_service(*this);   // DISKETTE: DMA host interface, once per clock
#endif
        if (d->inta_cycle_o) inta_active = true;
        else if (inta_active) { inta_active = false; ++inta_cycles; }
        if (d->cpu_reset_o && !was_reset) ++cpu_resets;
        halt_clocks = (d->halted_o && !(d->flags_o & 0x200)) ? halt_clocks + 1 : 0;
        was_reset = d->cpu_reset_o;

        d->clk_i = 1; d->clk_2x_i = 1; d->vid_clk_i = 1; d->eval();
        if (d->retire_o) { ++retired; cs = d->cs_o; ip = d->ip_o; }
        video_sample();
        dump();
        d->clk_2x_i = 0;
        d->vid_clk_i = 0;
        d->eval();
        dump();
        half_clock(false);
        ++cycle;

        // Keyboard: sees the lines after this clock, drives them for the next.
        if (!key_queue.empty() && cycle >= next_key) {
            kbd.key(key_queue.front().first, key_queue.front().second);
            key_queue.pop_front();
            next_key = cycle + kKeyGap;
        }
        kbd.tick(d->kbd_clk_o, d->kbd_data_o);
        d->kbd_clk_i = kbd.clk_out();
        d->kbd_data_i = kbd.data_out();
    }
};

// Scripted key input: rules run in order, each armed when the previous
// one has fired.
//   at CLOCK KEYS...        when the machine has run CLOCK processor clocks
//   wait CLOCKS KEYS...     CLOCKS after the previous rule fired
//   when "TEXT" KEYS...     when the screen text contains TEXT
// KEYS as for TYPE; a rule may have no keys (a pure wait). '#' starts a
// comment line.
struct Rule { enum Kind { kAt, kWait, kWhen } kind; uint64_t clock; std::string text, keys; int line; };

std::vector<Rule> read_script(const std::string& path) {
    std::ifstream f(path);
    if (!f) throw std::runtime_error("cannot read script " + path);
    std::vector<Rule> rules;
    std::string line;
    int n = 0;
    while (std::getline(f, line)) {
        ++n;
        std::istringstream in(line);
        std::string word;
        if (!(in >> word) || word[0] == '#') continue;
        Rule r{Rule::kAt, 0, "", "", n};
        if (word == "at" || word == "wait") {
            r.kind = word == "at" ? Rule::kAt : Rule::kWait;
            if (!(in >> r.clock)) throw std::runtime_error("script line " + std::to_string(n) + ": clock count expected");
        } else if (word == "when") {
            r.kind = Rule::kWhen;
            const size_t q1 = line.find('"'), q2 = q1 == std::string::npos ? q1 : line.find('"', q1 + 1);
            if (q2 == std::string::npos) throw std::runtime_error("script line " + std::to_string(n) + ": \"TEXT\" expected");
            r.text = line.substr(q1 + 1, q2 - q1 - 1);
            in.str(line.substr(q2 + 1));
            in.clear();
        } else {
            throw std::runtime_error("script line " + std::to_string(n) + ": at, wait or when expected");
        }
        std::getline(in, r.keys);
        parse_keys(r.keys);   // validate now
        rules.push_back(r);
    }
    return rules;
}

class Script {
public:
    std::vector<Rule> rules;
    size_t next = 0;
    uint64_t armed_at = 0, last_text_frame = ~0ull;
    std::vector<std::string> log;
    // Called between run slices; true when a rule fired.
    bool poll(Machine& m) {
        bool fired = false;
        while (next < rules.size()) {
            const Rule& r = rules[next];
            bool go = false;
            if (r.kind == Rule::kAt) go = m.cycle >= r.clock;
            else if (r.kind == Rule::kWait) go = m.cycle >= armed_at + r.clock;
            else if (m.frames != last_text_frame) {
                last_text_frame = m.frames;
                for (const auto& row : m.text())
                    if (row.find(r.text) != std::string::npos) go = true;
            }
            if (!go) break;
            m.queue_keys(parse_keys(r.keys));
            log.push_back("clock " + std::to_string(m.cycle) + ": line " + std::to_string(r.line) +
                          (r.keys.empty() ? "" : " keys" + r.keys));
            armed_at = m.cycle;
            ++next;
            fired = true;
        }
        return fired;
    }
    // Clocks until the next time-based rule can fire (for slicing).
    uint64_t horizon(const Machine& m) const {
        if (next >= rules.size()) return ~0ull;
        const Rule& r = rules[next];
        const uint64_t t = r.kind == Rule::kAt ? r.clock : r.kind == Rule::kWait ? armed_at + r.clock : 0;
        if (r.kind == Rule::kWhen) return 1000000;   // re-read the screen at least this often
        return t > m.cycle ? t - m.cycle : 1;
    }
};

namespace {
void write_text(const std::filesystem::path& p, const std::string& s) {
    const auto tmp = p.string() + ".next";
    {
        std::ofstream f(tmp, std::ios::binary);
        f << s;
        if (!f) throw std::runtime_error("cannot write " + tmp);
    }
    std::filesystem::rename(tmp, p);
}

std::string screen_json(const std::vector<std::string>& rows) {
    std::string s = "[";
    for (size_t i = 0; i < rows.size(); i++) s += (i ? "," : "") + json_string(rows[i]);
    return s + "]";
}

// Batch run: CLOCKS processor clocks headless. Every save_every clocks it
// writes DIR/status.json, DIR/latest.png and DIR/screen.txt, and adds the
// frame as DIR/frames/<clock>.png when it differs from the last one saved;
// DIR/frames.json lists the saved frames for the replay view.
int batch(Machine& m, Script& script, uint64_t clocks, uint64_t save_every, const std::string& dir,
          bool until_script) {
    namespace fs = std::filesystem;
    fs::create_directories(fs::path(dir) / "frames");
    std::vector<std::pair<uint64_t, std::string>> saved;
    uint64_t saved_hash = 0;
    const auto t0 = std::chrono::steady_clock::now();
    auto save = [&](bool final) {
        const double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        const double rate = secs > 0 ? double(m.cycle) / secs : 0;
        const auto rows = m.text();
        if (m.frame_width) {
            const auto p = m.frame_png();
            uint64_t h = 1469598103934665603ull;
            for (uint8_t b : p) h = (h ^ b) * 1099511628211ull;
            std::ofstream(fs::path(dir) / "latest.png.next", std::ios::binary).write(
                reinterpret_cast<const char*>(p.data()), long(p.size()));
            fs::rename(fs::path(dir) / "latest.png.next", fs::path(dir) / "latest.png");
            if (h != saved_hash) {
                saved_hash = h;
                const std::string name = hex(uint32_t(m.cycle >> 32), 4) + hex(uint32_t(m.cycle), 8) + ".png";
                std::ofstream(fs::path(dir) / "frames" / name, std::ios::binary).write(
                    reinterpret_cast<const char*>(p.data()), long(p.size()));
                saved.push_back({m.cycle, name});
            }
        }
        std::string list = "[";
        for (size_t i = 0; i < saved.size(); i++)
            list += std::string(i ? "," : "") + "{\"clock\":" + std::to_string(saved[i].first) +
                    ",\"file\":\"" + saved[i].second + "\"}";
        write_text(fs::path(dir) / "frames.json", list + "]\n");
        std::string text;
        for (const auto& r : rows) text += r + "\n";
        write_text(fs::path(dir) / "screen.txt", text);
        std::string slog = "[";
        for (size_t i = 0; i < script.log.size(); i++) slog += (i ? "," : "") + json_string(script.log[i]);
        write_text(fs::path(dir) / "status.json",
                   "{\"batch\":true,\"done\":" + std::string(final ? "true" : "false") +
                       ",\"targetClocks\":" + std::to_string(clocks) + ",\"wallSeconds\":" +
                       std::to_string(secs) + ",\"savedFrames\":" + std::to_string(saved.size()) +
                       ",\"scriptLog\":" + slog + "],\"screen\":" + screen_json(rows) +
                       ",\"state\":" + m.state_json(rate) + "}\n");
        std::cerr << "batch: " << m.cycle << " clocks, " << m.retired << " instructions, post "
                  << hex(m.d->post_code_o, 2) << ", " << uint64_t(rate) << " clocks/s"
                  << (m.stop.empty() ? "" : ", stopped: " + m.stop) << '\n';
    };
    uint64_t next_save = save_every;
    while (m.cycle < clocks && m.stop.empty()) {
        if (script.poll(m)) {
            // The screen the rule reacted to, also as PPM for check_frame.py.
            save(false);
            if (m.frame_width)
                m.write_ppm((fs::path(dir) / ("rule" + std::to_string(script.next) + ".ppm")).string());
        }
        if (until_script && script.next >= script.rules.size() && m.key_queue.empty()) break;
        const uint64_t slice = std::min({clocks - m.cycle, next_save > m.cycle ? next_save - m.cycle : 1,
                                         script.horizon(m)});
        m.run(slice);
        if (m.cycle >= next_save) { save(false); next_save += save_every; }
    }
    script.poll(m);
    save(true);
    if (m.frame_width) m.write_ppm((fs::path(dir) / "frame.ppm").string());   // for check_frame.py
    return m.stop.empty() ? 0 : 3;
}
}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    try {
        if (argc < 3) throw std::runtime_error("usage: simulator BIOS_ROM VGA_ROM [options]");
        unsigned ext_kb = 0;
        uint64_t batch_clocks = 0, save_every = 50000000;
        std::string out_dir, script_path, fst = "cpu-waveform.fst";
        bool until_script = false;
        for (int i = 3; i < argc; i++) {
            const std::string o = argv[i];
            auto val = [&](const char* p) { return o.substr(std::string(p).size()); };
            if (o.rfind("--ext-kb=", 0) == 0) ext_kb = unsigned(std::stoul(val("--ext-kb=")));
            else if (o.rfind("--batch=", 0) == 0) batch_clocks = std::stoull(val("--batch="));
            else if (o.rfind("--out=", 0) == 0) out_dir = val("--out=");
            else if (o.rfind("--save-every=", 0) == 0) save_every = std::max<uint64_t>(1, std::stoull(val("--save-every=")));
            else if (o.rfind("--script=", 0) == 0) script_path = val("--script=");
            else if (o.rfind("--fst=", 0) == 0) fst = val("--fst=");
            else if (o == "--until-script") until_script = true;
#ifdef AT_DISKETTE
            else if (diskette_options(o)) {}   // DISKETTE: --fda=/--fdb=
#endif
            else throw std::runtime_error("unknown option " + o);
        }
        Machine m(read_file(argv[1]), read_file(argv[2]), ext_kb, fst);
        if (!m.screen.ok()) throw std::runtime_error("8 x 16 font not found in the VGA ROM");
        Script script;
        if (!script_path.empty()) script.rules = read_script(script_path);
        if (batch_clocks) {
            if (out_dir.empty()) throw std::runtime_error("--batch needs --out=DIR");
            return batch(m, script, batch_clocks, save_every, out_dir, until_script);
        }
        auto t_last = std::chrono::steady_clock::now();
        double rate = 0;
        std::string line;
        while (std::getline(std::cin, line)) {
            std::istringstream in(line);
            std::string cmd;
            in >> cmd;
            try {
                if (cmd == "QUIT") break;
                if (cmd == "RUN") {
                    uint64_t n = 0;
                    in >> n;
                    const auto t0 = std::chrono::steady_clock::now();
                    uint64_t done = 0;
                    while (done < n && m.stop.empty()) {
                        script.poll(m);
                        done += m.run(std::min(n - done, script.horizon(m)));
                    }
                    script.poll(m);
                    const double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
                    if (secs > 0 && done) rate = double(done) / secs;
                    t_last = std::chrono::steady_clock::now();
                } else if (cmd == "RESET") {
                    m.power_on();
                    script.next = 0; script.armed_at = 0;
                } else if (cmd == "KEY") {
                    std::string code; int make = 1;
                    in >> code >> make;
                    m.queue_keys({{uint8_t(std::stoul(code, nullptr, 16)), make != 0}});
                } else if (cmd == "TYPE") {
                    std::string rest;
                    std::getline(in, rest);
                    m.queue_keys(parse_keys(rest));
                } else if (cmd == "FRAME") {
                    std::cout << "{\"frames\":" << m.frames << ",\"width\":" << m.frame_width
                              << ",\"height\":" << m.last_frame.size() << ",\"png\":\""
                              << (m.frame_width ? base64(m.frame_png()) : "") << "\"}" << std::endl;
                    continue;
                } else if (cmd == "TEXT") {
                    std::cout << "{\"frames\":" << m.frames << ",\"screen\":" << screen_json(m.text()) << "}" << std::endl;
                    continue;
                } else if (cmd == "PPM") {
                    std::string path;
                    in >> path;
                    if (!m.frame_width) throw std::runtime_error("no complete frame yet");
                    m.write_ppm(path);
                } else if (cmd == "PEEK") {
                    std::string as; unsigned len = 0;
                    in >> as >> len;
                    const uint32_t addr = uint32_t(std::stoul(as, nullptr, 16));
                    if (len > 4096) throw std::runtime_error("PEEK at most 4096 bytes");
                    std::string h;
                    for (unsigned i = 0; i < len; i++) h += hex(m.byte(addr + i), 2);
                    std::cout << "{\"addr\":\"" << hex(addr, 6) << "\",\"hex\":\"" << h << "\"}" << std::endl;
                    continue;
                } else if (cmd == "CAPTURE") {
                    uint64_t n = 0;
                    in >> n;
                    m.capture(n);
                } else if (cmd != "STATE") {
                    throw std::runtime_error("unknown command " + cmd);
                }
                std::cout << m.state_json(rate) << std::endl;
            } catch (const std::exception& e) {
                std::cout << "{\"error\":" << json_string(e.what()) << "}" << std::endl;
            }
            (void)t_last;
        }
        m.d->final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
