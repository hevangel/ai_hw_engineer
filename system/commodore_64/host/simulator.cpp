// Host harness for the C64 board. Private line protocol used by
// host/server.py and scripts/test_software.py. All machine state comes from
// RTL; the host drives the reset line, keyboard matrix and joysticks, and
// observes pixels, SID voice outputs and memory read-only.
#include "Vc64_board.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

#ifndef C64_VARIANT
#define C64_VARIANT 0
#endif
constexpr double SYSTEM_HZ = C64_VARIANT ? 1022727.0 : 985248.0;
constexpr int ROWS = 312;
constexpr int COLS = 520;

Vc64_board board;
std::vector<uint8_t> drawing(ROWS * COLS), shown(ROWS * COLS);
uint64_t frames_shown = 0, dots = 0;
int capture_version = 0;
std::unique_ptr<VerilatedFstC> waveform;
uint64_t waveform_time = 0;
std::vector<int16_t> audio;          // 44.1 kHz-ish mono samples since last read
double audio_phase = 0.0;
unsigned last_row = 0;

int16_t sid_sample() {
    // Digital mix of the three voices: (wave - 2048) * envelope, scaled by
    // the master volume. No filter or analog stage (see spec).
    int32_t sum = 0;
    for (int v = 0; v < 3; ++v) {
        int32_t wave = static_cast<int32_t>((board.sid_wave >> (12 * v)) & 0xfff) - 2048;
        int32_t env = static_cast<int32_t>((board.sid_env >> (8 * v)) & 0xff);
        sum += wave * env / 256;
    }
    sum = sum * static_cast<int32_t>(board.sid_mode_vol & 0x0f) / 15;
    return static_cast<int16_t>(std::clamp(sum * 4, -32767, 32767));
}

void tick() {
    board.clk = 1;
    board.eval();
    if (waveform) waveform->dump(++waveform_time);
    board.clk = 0;
    board.eval();
    if (waveform) waveform->dump(++waveform_time);
    ++dots;
    if (board.pixel_valid) {
        unsigned row = board.pixel_row, col = board.pixel_col;
        if (row < static_cast<unsigned>(ROWS) && col < static_cast<unsigned>(COLS))
            drawing[row * COLS + col] = board.pixel & 0x0f;
        if (row < last_row) {
            shown = drawing;
            ++frames_shown;
        }
        last_row = row;
    }
    if (board.sid_ce) {
        // System clock (PAL 985 248 Hz, NTSC 1 022 727 Hz) decimated to
        // ~44.1 kHz.
        audio_phase += 44100.0 / SYSTEM_HZ;
        if (audio_phase >= 1.0) {
            audio_phase -= 1.0;
            if (audio.size() < 88200) audio.push_back(sid_sample());
        }
    }
}

void run_frames(uint64_t count) {
    uint64_t target = frames_shown + count;
    uint64_t limit = dots + count * 200000ull + 200000ull;
    while (frames_shown < target && dots < limit) {
        tick();
        if (board.cpu_jammed) break;
    }
}

// Run until the CPU presents an opcode fetch at pc (the instruction has not
// executed; every earlier write has completed). skip earlier matches.
bool run_until_pc(uint16_t pc, unsigned skip, uint64_t max_cycles) {
    uint64_t limit = dots + max_cycles * 8;
    bool was_phi2 = board.phi2;
    while (dots < limit) {
        tick();
        bool falling = was_phi2 && !board.phi2;
        was_phi2 = board.phi2;
        if (falling && board.cpu_fetch && board.cpu_addr == pc && board.ba) {
            if (skip == 0) return true;
            --skip;
        }
    }
    return false;
}

uint8_t peek(uint16_t addr) {
    board.host_addr = addr;
    board.eval();
    return board.host_ram_q;
}

std::string hex_bytes(const std::vector<uint8_t> &data) {
    static const char *digits = "0123456789abcdef";
    std::string out;
    out.reserve(data.size() * 2);
    for (uint8_t v : data) {
        out.push_back(digits[v >> 4]);
        out.push_back(digits[v & 15]);
    }
    return out;
}

std::string state(bool with_frame) {
    std::ostringstream out;
    unsigned screen = peek(0x0288) << 8;  // KERNAL HIBASE: text screen page
    std::vector<uint8_t> text(1000), color(1000);
    for (int i = 0; i < 1000; ++i) {
        text[i] = peek(static_cast<uint16_t>(screen + i));
        board.host_addr = static_cast<uint16_t>(i);
        board.eval();
        color[i] = board.host_color_q & 0x0f;
    }
    out << "{\"pc\":" << board.cpu_pc << ",\"a\":" << unsigned(board.cpu_a)
        << ",\"x\":" << unsigned(board.cpu_x) << ",\"y\":" << unsigned(board.cpu_y)
        << ",\"s\":" << unsigned(board.cpu_s) << ",\"p\":" << unsigned(board.cpu_p)
        << ",\"cycles\":" << board.cycle_count << ",\"frames\":" << frames_shown
        << ",\"jammed\":" << (board.cpu_jammed ? "true" : "false")
        << ",\"captureVersion\":" << capture_version
        << ",\"screenBase\":" << screen
        << ",\"text\":\"" << hex_bytes(text) << "\",\"color\":\"" << hex_bytes(color) << "\"";
    if (with_frame) {
        out << ",\"rows\":" << ROWS << ",\"cols\":" << COLS << ",\"frame\":\"";
        static const char *digits = "0123456789abcdef";
        std::string pixels(shown.size(), '0');
        for (size_t i = 0; i < shown.size(); ++i) pixels[i] = digits[shown[i] & 15];
        out << pixels << "\"";
        out << ",\"audio\":[";
        for (size_t i = 0; i < audio.size(); ++i) out << (i ? "," : "") << audio[i];
        out << "]";
        audio.clear();
    }
    out << "}";
    return out.str();
}

void capture(uint64_t cycles) {
    const char *configured = std::getenv("C64_FST_PATH");
    std::string path = configured ? configured : "c64-waveform.fst";
    std::string temporary = path + ".tmp";
    waveform = std::make_unique<VerilatedFstC>();
    board.trace(waveform.get(), 1);
    waveform->open(temporary.c_str());
    if (!waveform->isOpen()) throw std::runtime_error("cannot open waveform capture");
    waveform_time = 0;
    waveform->dump(0);
    for (uint64_t i = 0; i < cycles * 8; ++i) tick();
    waveform->close();
    waveform.reset();
    if (std::rename(temporary.c_str(), path.c_str()))
        throw std::runtime_error("cannot publish waveform capture");
    ++capture_version;
}

void reset() {
    board.rst_n = 0;
    for (int i = 0; i < 64; ++i) tick();
    board.rst_n = 1;
    tick();
}

uint64_t parse_hex64(const std::string &text) {
    if (text.empty() || text.size() > 16) throw std::runtime_error("bad key matrix");
    return std::stoull(text, nullptr, 16);
}

} // namespace

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    board.clk = 0;
    board.keys = 0;
    board.restore_n = 1;
    board.joy1_n = 0x1f;
    board.joy2_n = 0x1f;
    board.exrom_n = 1;
    board.game_n = 1;
    board.host_addr = 0;
    reset();

    std::string line;
    while (std::getline(std::cin, line)) {
        try {
            std::istringstream in(line);
            std::string command, arg;
            in >> command >> arg;
            bool frame = false;
            if (command == "QUIT") break;
            if (command == "STATE") {
            } else if (command == "FRAME") {
                frame = true;
            } else if (command == "RUN") {
                run_frames(std::clamp<uint64_t>(arg.empty() ? 1 : std::stoull(arg), 1, 1000));
            } else if (command == "RUNF") {
                run_frames(std::clamp<uint64_t>(arg.empty() ? 1 : std::stoull(arg), 1, 50));
                frame = true;
            } else if (command == "KEYS") {
                board.keys = parse_hex64(arg);
            } else if (command == "RESTORE") {
                board.restore_n = arg == "1" ? 0 : 1;
            } else if (command == "JOY1" || command == "JOY2") {
                unsigned value = std::stoul(arg) & 0x1f;
                (command == "JOY1" ? board.joy1_n : board.joy2_n) = value;
            } else if (command == "RESET") {
                reset();
            } else if (command == "PEEK") {
                unsigned addr = std::stoul(arg, nullptr, 0);
                if (addr > 0xffff) throw std::runtime_error("address out of range");
                std::cout << "{\"addr\":" << addr << ",\"value\":" << unsigned(peek(addr))
                          << "}" << std::endl;
                continue;
            } else if (command == "UNTILPC") {
                unsigned pc = std::stoul(arg, nullptr, 16), skip = 0;
                in >> skip;
                if (!run_until_pc(static_cast<uint16_t>(pc), skip, 50000000ull))
                    throw std::runtime_error("PC not reached");
            } else if (command == "TRACE") {
                // TRACE cycles path [verbose]: one line per executed opcode
                // fetch, stamped with the cycle in which the fetch completed
                // (a fetch held by RDY completes when BA returns), carrying
                // the registers presented with it: cycle pc a x y s p line cycle.
                uint64_t count = std::stoull(arg);
                std::string path;
                int verbose = 0;
                in >> path >> verbose;
                FILE *log = std::fopen(path.c_str(), "w");
                if (!log) throw std::runtime_error("cannot open trace");
                bool was_phi2 = board.phi2, pending = false;
                unsigned pc = 0, a = 0, x = 0, y = 0, s = 0, p = 0;
                uint64_t end = board.cycle_count + count;
                while (board.cycle_count < end) {
                    bool we = board.cpu_we, fetch = board.cpu_fetch;
                    tick();
                    bool falling = was_phi2 && !board.phi2;
                    was_phi2 = board.phi2;
                    if (!falling) continue;
                    // BA here still belongs to the access that just ended.
                    bool completed = board.ba || we;
                    if (pending && fetch && completed) {
                        std::fprintf(log, "%u %04x %02x %02x %02x %02x %02x %u %u\n",
                                     board.cycle_count - 1, pc, a, x, y, s, p,
                                     board.raster_line, board.raster_cycle);
                        pending = false;
                    }
                    if (verbose)
                        std::fprintf(log, "  c%u %04x %c d=%02x ba=%d aec=%d fetch=%d raster=%u/%u\n",
                                     board.cycle_count, board.cpu_addr, board.cpu_we ? 'W' : 'R',
                                     board.cpu_we ? board.cpu_data_out : board.cpu_data_in,
                                     board.ba, board.aec, board.cpu_fetch, board.raster_line,
                                     board.raster_cycle);
                    if (board.cpu_fetch && !pending) {
                        pending = true;
                        pc = board.cpu_addr; a = board.cpu_a; x = board.cpu_x;
                        y = board.cpu_y; s = board.cpu_s; p = board.cpu_p;
                    }
                }
                std::fclose(log);
            } else if (command == "CHECKPOINT") {
                std::vector<uint8_t> ram(65536);
                for (unsigned a = 0; a < 65536; ++a) ram[a] = peek(static_cast<uint16_t>(a));
                std::cout << "{\"pc\":" << board.cpu_pc << ",\"a\":" << unsigned(board.cpu_a)
                          << ",\"x\":" << unsigned(board.cpu_x) << ",\"y\":" << unsigned(board.cpu_y)
                          << ",\"s\":" << unsigned(board.cpu_s) << ",\"p\":" << unsigned(board.cpu_p)
                          << ",\"cycles\":" << board.cycle_count << ",\"ram\":\"" << hex_bytes(ram)
                          << "\"}" << std::endl;
                continue;
            } else if (command == "CAPTURE") {
                capture(std::clamp<uint64_t>(arg.empty() ? 2000 : std::stoull(arg), 1, 20000));
            } else {
                throw std::runtime_error("unknown command: " + command);
            }
            std::cout << state(frame) << std::endl;
        } catch (const std::exception &error) {
            std::cout << "{\"error\":\"" << error.what() << "\"}" << std::endl;
        }
    }
    board.final();
    return 0;
}
