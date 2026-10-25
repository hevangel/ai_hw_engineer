// Original VIC-20 firmware boot on the native 6502, two 6522s and the VIC.
// Every VIC clock is compared with the unchanged MAME display/bus/light-pen/
// sound functions (tb/vic_display_oracle.cpp) fed the same CPU accesses and
// display memory. The boot must reach the exact BASIC start-up screen.
#include "Vvic20_top.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

extern "C" {
void vic_display_init(int, int, const uint8_t *, const uint8_t *);
void vic_display_clock(int, int);
void vic_display_write(int, unsigned, unsigned);
unsigned vic_display_read(int, unsigned);
void vic_display_pots(int, unsigned, unsigned);
unsigned vic_display_fetch_count(int);
unsigned vic_display_fetch_addr(int);
unsigned vic_display_fetch_matrix(int);
unsigned vic_display_pixels(int);
unsigned vic_display_sample(int);
unsigned vic_display_level(int);
}

namespace {
std::vector<uint8_t> load(const std::string &path, size_t size) {
    std::ifstream input(path, std::ios::binary);
    std::vector<uint8_t> data((std::istreambuf_iterator<char>(input)), {});
    if (data.size() != size) throw std::runtime_error("unexpected ROM size: " + path);
    return data;
}

// Minimal PNG (stored deflate blocks) for the visual record of one frame.
uint32_t crc_update(uint32_t crc, const uint8_t *p, size_t n) {
    for (size_t i = 0; i < n; i++) {
        crc ^= p[i];
        for (int k = 0; k < 8; k++) crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1)));
    }
    return crc;
}

void chunk(std::ofstream &out, const char *type, const std::vector<uint8_t> &data) {
    const uint32_t n = uint32_t(data.size());
    const uint8_t len[4] = {uint8_t(n >> 24), uint8_t(n >> 16), uint8_t(n >> 8), uint8_t(n)};
    out.write(reinterpret_cast<const char *>(len), 4);
    out.write(type, 4);
    if (n) out.write(reinterpret_cast<const char *>(data.data()), n);
    uint32_t crc = crc_update(0xffffffffu, reinterpret_cast<const uint8_t *>(type), 4);
    crc = crc_update(crc, data.data(), n) ^ 0xffffffffu;
    const uint8_t c[4] = {uint8_t(crc >> 24), uint8_t(crc >> 16), uint8_t(crc >> 8), uint8_t(crc)};
    out.write(reinterpret_cast<const char *>(c), 4);
}

void write_png(const std::string &path, unsigned w, unsigned h, const std::vector<uint32_t> &rgb) {
    std::vector<uint8_t> raw;
    for (unsigned y = 0; y < h; y++) {
        raw.push_back(0);
        for (unsigned x = 0; x < w; x++) {
            const uint32_t c = rgb[y * w + x];
            raw.push_back(uint8_t(c >> 16));
            raw.push_back(uint8_t(c >> 8));
            raw.push_back(uint8_t(c));
        }
    }
    std::vector<uint8_t> z = {0x78, 0x01};
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < raw.size(); i += 65535) {
        const size_t n = std::min<size_t>(65535, raw.size() - i);
        z.push_back(i + n == raw.size());
        z.push_back(uint8_t(n));
        z.push_back(uint8_t(n >> 8));
        z.push_back(uint8_t(~n));
        z.push_back(uint8_t(~n >> 8));
        z.insert(z.end(), raw.begin() + long(i), raw.begin() + long(i + n));
    }
    for (uint8_t v : raw) {
        a = (a + v) % 65521;
        b = (b + a) % 65521;
    }
    const uint32_t adler = (b << 16) | a;
    for (int s = 24; s >= 0; s -= 8) z.push_back(uint8_t(adler >> s));
    std::ofstream out(path, std::ios::binary);
    const uint8_t sig[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
    out.write(reinterpret_cast<const char *>(sig), 8);
    chunk(out, "IHDR", {uint8_t(w >> 24), uint8_t(w >> 16), uint8_t(w >> 8), uint8_t(w),
                        uint8_t(h >> 24), uint8_t(h >> 16), uint8_t(h >> 8), uint8_t(h),
                        8, 2, 0, 0, 0});
    chunk(out, "IDAT", z);
    chunk(out, "IEND", {});
}

// Visualization only: MAME's sampled palette for each variant. Pixel checks
// compare digital color indices, never these RGB values.
const uint32_t pal_rgb[16] = {
    0x000000, 0xffffff, 0xb61f21, 0x4df0ff, 0xb43fff, 0x44e237, 0x1a34ff, 0xdcd71b,
    0xca5400, 0xe9b072, 0xe79293, 0x9af7fd, 0xe09fff, 0x8fe493, 0x8290ff, 0xe5de85};
const uint32_t ntsc_rgb[16] = {
    0x000000, 0xffffff, 0xf91137, 0x35f9f6, 0xff3cc6, 0x3ceda9, 0x0f57f7, 0xfee963,
    0xfb6244, 0xfbbfde, 0xf3ace5, 0xa8eadd, 0xe6b8f7, 0xabdda4, 0x6ab3e7, 0xf7daa5};

char screen_char(uint8_t code) {
    code &= 0x7f;
    if (code == 0) return '@';
    if (code < 27) return char('A' + code - 1);
    if (code >= 0x20 && code < 0x40) return char(code);
    return '?';
}
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    try {
        if (argc != 6) throw std::runtime_error("usage: pal|ntsc basic kernal chargen frame.png");
        const bool ntsc = std::string(argv[1]) == "ntsc";
        const auto basic = load(argv[2], 8192), kernal = load(argv[3], 8192);
        const auto chargen = load(argv[4], 4096);
        const std::string image = argv[5];
        std::array<uint8_t, 1024> ram0{}, color{};
        std::array<uint8_t, 4096> ram{};
        // The VIC's fourteen-bit view of the board (MAME vic_videoram_map).
        std::array<uint8_t, 16384> view{};
        auto view_value = [&](unsigned v) -> uint8_t {
            if (v < 0x1000) return chargen[v];
            if (v >= 0x1400 && v < 0x1800) return uint8_t(0xf0 | color[v & 0x3ff]);
            if (v >= 0x2000 && v < 0x2400) return ram0[v & 0x3ff];
            if (v >= 0x3000) return ram[v & 0xfff];
            // ASSUMPTION: undriven VIC data reads high in this fixture.
            return 0xff;
        };
        auto refresh_view = [&]() {
            for (unsigned v = 0; v < view.size(); v++) view[v] = view_value(v);
        };
        auto cpu_read = [&](unsigned a) -> uint8_t {
            if (a < 0x0400) return ram0[a];
            if (a >= 0x1000 && a < 0x2000) return ram[a - 0x1000];
            if (a >= 0x8000 && a < 0x9000) return chargen[a - 0x8000];
            if (a >= 0x9400 && a < 0x9800) return uint8_t(((a >> 8) & 0xf0) | color[a & 0x3ff]);
            if (a >= 0xc000 && a < 0xe000) return basic[a - 0xc000];
            if (a >= 0xe000) return kernal[a - 0xe000];
            // ASSUMPTION: unmapped reads return the address high byte (last
            // byte of an absolute operand); MAME returns its VIC bus latch.
            return uint8_t(a >> 8);
        };
        refresh_view();
        vic_display_init(0, ntsc, view.data(), color.data());
        vic_display_pots(0, 0xff, 0xff);

        Vvic20_top dut;
        uint64_t cycles = 0, vic_writes = 0, vic_reads = 0, irqs = 0, matrix = 0, frames = 0;
        unsigned first_fetches = 0;
        const unsigned reset_vector = kernal[0x1ffc] | (kernal[0x1ffd] << 8);
        const unsigned irq_vector = kernal[0x1ffe] | (kernal[0x1fff] << 8);
        const unsigned cpl = ntsc ? 65 : 71;
        const unsigned width = 4 * cpl, max_lines = ntsc ? 263 : 312;
        std::vector<uint32_t> frame(width * max_lines, 0), shown;
        unsigned shown_lines = 0;
        auto fail = [&](const std::string &what) {
            std::fprintf(stderr, "screen page %02x:\n", ram0[0x288]);
            for (unsigned r = 0; r < 23; r++) {
                std::string row;
                for (unsigned c = 0; c < 22; c++) row += screen_char(ram[0xe00 + r * 22 + c]);
                std::fprintf(stderr, "|%s|\n", row.c_str());
            }
            std::fprintf(stderr, "VIC-20 %s cycle=%llu PC=%04x bus=%04x\n",
                         ntsc ? "NTSC" : "PAL", (unsigned long long)cycles, dut.pc_o, dut.bus_addr);
            throw std::runtime_error(what);
        };
        auto settle = [&]() {
            dut.eval();
            const unsigned v = dut.vic_fetch_addr_o;
            dut.vic_fetch_data_i = view[v] | (unsigned(color[v & 0x3ff]) << 8);
            dut.memory_data_i = cpu_read(dut.bus_addr);
            dut.eval();
        };
        dut.rst_n = 0;
        for (int i = 0; i < 4; i++) {
            dut.clk = 1; settle(); dut.clk = 0; settle();
        }
        dut.rst_n = 1;
        bool ready = false;
        uint64_t ready_cycle = 0;
        while (cycles < 20000000) {
            // Phase before the VIC edge: outputs describe the coming cycle.
            settle();
            if (dut.fault_o || dut.jammed_o) fail("CPU fault or jam");
            vic_display_clock(0, dut.lightpen_n_o);
            const unsigned count = vic_display_fetch_count(0);
            const unsigned want_pixels = vic_display_pixels(0);
            if (dut.vic_fetch_o != count ||
                (count && (dut.vic_fetch_addr_o != vic_display_fetch_addr(0) ||
                           dut.vic_matrix_o != vic_display_fetch_matrix(0))) ||
                dut.pixel_o != want_pixels ||
                dut.audio_sample_o != vic_display_sample(0) ||
                (dut.audio_sample_o && dut.audio_level_o != vic_display_level(0)))
                fail("VIC output differs from the MAME reference");
            if (dut.vic_fetch_o && dut.vic_matrix_o) matrix++;
            const unsigned h = dut.scan_h_o, line = dut.scan_line_o;
            for (unsigned i = 0; i < 4; i++)
                frame[line * width + 4 * h + i] =
                    (ntsc ? ntsc_rgb : pal_rgb)[(dut.pixel_o >> (4 * i)) & 15];
            if (dut.frame_end_o) {
                shown = frame;
                shown_lines = line + 1;
                frames++;
            }
            // VIC/VIA edge; CPU bus data settles for the CPU's edge.
            dut.clk = 1;
            settle();
            const unsigned a = dut.bus_addr;
            if (dut.fetch_o) {
                if (first_fetches == 0) {
                    if (a != reset_vector || dut.read_data_o != kernal[reset_vector - 0xe000])
                        fail("first instruction is not the KERNAL reset entry");
                }
                first_fetches++;
                if (a == irq_vector) irqs++;
            }
            if ((a & 0xfff0) == 0x9000) {
                if (dut.bus_we) {
                    vic_display_write(0, a & 15, dut.bus_data_o);
                    vic_writes++;
                } else {
                    if (dut.read_data_o != vic_display_read(0, a & 15))
                        fail("VIC register read differs from the MAME reference");
                    vic_reads++;
                }
            }
            if (dut.bus_we) {
                const unsigned d = dut.bus_data_o;
                if (a < 0x0400) { ram0[a] = uint8_t(d); view[0x2000 | a] = uint8_t(d); }
                else if (a >= 0x1000 && a < 0x2000) { ram[a - 0x1000] = uint8_t(d); view[0x2000 | a] = uint8_t(d); }
                else if (a >= 0x9400 && a < 0x9800) {
                    color[a & 0x3ff] = uint8_t(d & 15);
                    view[0x1400 | (a & 0x3ff)] = uint8_t(0xf0 | (d & 15));
                }
            }
            dut.clk = 0;
            settle();
            cycles++;
            if (!ready && frames > 1) {
                // Screen at $1E00 (22 x 23), as configured by the KERNAL.
                std::string row3;
                for (unsigned c = 0; c < 6; c++) row3 += screen_char(ram[0xe00 + 4 * 22 + c]);
                if (row3 == "READY.") { ready = true; ready_cycle = cycles; }
            }
            if (ready && cycles > ready_cycle + 4 * width / 4 * max_lines) break;
        }
        if (!ready) fail("BASIC READY prompt not reached");
        std::vector<std::string> rows(23);
        for (unsigned r = 0; r < 23; r++)
            for (unsigned c = 0; c < 22; c++) rows[r] += screen_char(ram[0xe00 + r * 22 + c]);
        const std::string blank(22, ' ');
        auto padded = [&](const std::string &s) { return s + std::string(22 - s.size(), ' '); };
        if (rows[0] != padded("**** CBM BASIC V2 ****") || rows[1] != blank ||
            rows[2] != padded("3583 BYTES FREE") || rows[3] != blank ||
            rows[4] != padded("READY.") || rows[5] != blank)
            fail("BASIC start-up screen text differs");
        // Row 5 holds the blinking cursor; reverse video is ignored above.
        for (unsigned r = 6; r < 23; r++) if (rows[r] != blank) fail("unexpected screen text");
        const unsigned vic_base = ram0[0x288];
        if (vic_base != 0x1e) fail("KERNAL screen base is not $1E00");
        if (!irqs || !vic_writes || !vic_reads || !matrix) fail("missing activity");
        write_png(image, width, shown_lines, shown);
        std::printf("VIC-20 %s BOOT PASS: %llu cycles, %llu frames, %llu VIC writes, %llu VIC reads, "
                    "%llu matrix fetches, %llu IRQ entries, READY at cycle %llu; screen: '%s' / '%s' / '%s'\n",
                    ntsc ? "NTSC" : "PAL", (unsigned long long)cycles, (unsigned long long)frames,
                    (unsigned long long)vic_writes, (unsigned long long)vic_reads,
                    (unsigned long long)matrix, (unsigned long long)irqs,
                    (unsigned long long)ready_cycle, rows[0].c_str(), rows[2].c_str(), rows[4].c_str());
    } catch (const std::exception &e) {
        std::fprintf(stderr, "VIC-20 boot FAIL: %s\n", e.what());
        return 1;
    }
}
