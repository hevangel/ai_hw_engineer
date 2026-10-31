// Clock-by-clock comparison of both VIC profiles with the unchanged MAME
// display, bus, light-pen and sound functions (tb/vic_display_oracle.cpp).
// Every enabled clock checks the display fetch strobe/kind/address, all four
// pixel colors, CPU register reads and half-rate sound samples.
#include "Vvic_pair.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" {
void vic_display_init(int, int, const uint8_t *, const uint8_t *);
void vic_display_clock(int, int);
void vic_display_lightpen(int, int);
void vic_display_write(int, unsigned, unsigned);
unsigned vic_display_read(int, unsigned);
void vic_display_pots(int, unsigned, unsigned);
unsigned vic_display_fetch_count(int);
unsigned vic_display_fetch_addr(int);
unsigned vic_display_fetch_matrix(int);
unsigned vic_display_pixels(int);
unsigned vic_display_sample(int);
unsigned vic_display_level(int);
int vic_display_h(int);
int vic_display_line(int);
int vic_display_frame_lines(int);
int vic_display_lightpen_x(int);
int vic_display_area(int);
int vic_display_lightpen_extra(int);
}

namespace {
Vvic_pair dut;
uint8_t video[1 << 14], color[1 << 10];
uint64_t rng = 0x9e3779b97f4a7c15ull;
uint64_t clocks, comparisons, records, record_limit;
FILE *vectors;
// Coverage of behavior that must be exercised, not merely compiled.
uint64_t matrix_fetches[2], char_fetches[2], captures[2], loud[2];
uint64_t interlace_frames, reads_checked, color_writes_in_display[2];
int last_lp_x[2];
uint64_t extra_cleared[2];

uint32_t next(unsigned bound) {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return uint32_t(rng % bound);
}

struct bus {
    bool phi2 = true, rw = true;
    unsigned addr = 0x2000, data = 0;
};

bool selected(const bus &b) { return (b.addr & 0x3f00) == 0x1000; }

unsigned memory(unsigned addr) {
    return video[addr & 0x3fff] | (unsigned(color[addr & 0x3ff] & 15) << 8);
}

uint64_t expected(int which, bool reset, bool enable, const bus &b, bool pen_n) {
    if (reset) return 0;
    uint64_t oe = 0, data = 0;
    if (b.phi2 && b.rw && selected(b)) {
        oe = 1;
        data = vic_display_read(which, b.addr & 15);
        reads_checked++;
    }
    uint64_t fetch = 0, matrix = 0, addr = 0, pixels = 0, sample = 0, level = 0;
    if (enable) {
        vic_display_clock(which, pen_n);
        const unsigned count = vic_display_fetch_count(which);
        if (count > 1) std::abort();
        fetch = count;
        if (count) {
            matrix = vic_display_fetch_matrix(which);
            addr = vic_display_fetch_addr(which);
            (matrix ? matrix_fetches : char_fetches)[which]++;
        }
        pixels = vic_display_pixels(which);
        sample = vic_display_sample(which);
        if (sample) {
            level = vic_display_level(which);
            // Above the volume-only floor at least one voice is high.
            if (level > 15) loud[which]++;
        }
        if (vic_display_lightpen_x(which) != last_lp_x[which]) {
            captures[which]++;
            last_lp_x[which] = vic_display_lightpen_x(which);
        }
    } else {
        vic_display_lightpen(which, pen_n);
    }
    if (b.phi2 && !b.rw && selected(b)) {
        vic_display_write(which, b.addr & 15, b.data);
        if ((b.addr & 14) == 14 && vic_display_area(which) == 2)
            color_writes_in_display[which]++;
    }
    return fetch | (matrix << 1) | (addr << 2) | (pixels << 16) | (oe << 32) |
           (data << 33) | (sample << 41) | (level << 42);
}

void step(bool reset, bool enable, const bus &b, bool pen_n, unsigned pot_x, unsigned pot_y) {
    dut.clk = 0;
    dut.rst_n = !reset;
    dut.ce_i = enable;
    dut.phi2_i = b.phi2;
    dut.rw_i = b.rw;
    dut.addr_i = b.addr & 0x3fff;
    dut.data_i = b.data & 255;
    dut.lightpen_n_i = pen_n;
    dut.pot_x_i = pot_x;
    dut.pot_y_i = pot_y;
    dut.eval();
    // Display memory answers the fetch address within the same cycle.
    dut.pal_fetch_data_i = memory(dut.pal_fetch_addr_o);
    dut.ntsc_fetch_data_i = memory(dut.ntsc_fetch_addr_o);
    dut.eval();
    if (!reset) {
        vic_display_pots(0, pot_x, pot_y);
        vic_display_pots(1, pot_x, pot_y);
    }
    const uint64_t pal = expected(0, reset, enable, b, pen_n);
    const uint64_t ntsc = expected(1, reset, enable, b, pen_n);
    if (dut.pal_state_o != pal || dut.ntsc_state_o != ntsc) {
        std::fprintf(stderr,
            "VIC mismatch clock=%llu reset=%d ce=%d pal=%llx/%llx ntsc=%llx/%llx "
            "pal h/line=%d/%d ntsc h/line=%d/%d\n",
            (unsigned long long)clocks, reset, enable,
            (unsigned long long)dut.pal_state_o, (unsigned long long)pal,
            (unsigned long long)dut.ntsc_state_o, (unsigned long long)ntsc,
            vic_display_h(0), vic_display_line(0), vic_display_h(1), vic_display_line(1));
        std::exit(1);
    }
    comparisons += 2;
    if (records < record_limit) {
        std::fprintf(vectors, "%x %x %x %x %x %x %x %x %x %x %x %llx %llx\n",
            unsigned(dut.rst_n), unsigned(dut.ce_i), unsigned(dut.phi2_i),
            unsigned(dut.rw_i), unsigned(dut.addr_i), unsigned(dut.data_i),
            unsigned(dut.lightpen_n_i), unsigned(dut.pot_x_i), unsigned(dut.pot_y_i),
            unsigned(dut.pal_fetch_data_i), unsigned(dut.ntsc_fetch_data_i),
            (unsigned long long)pal, (unsigned long long)ntsc);
        records++;
    }
    dut.clk = 1;
    dut.eval();
    if (reset) {
        vic_display_init(0, 0, video, color);
        vic_display_init(1, 1, video, color);
        last_lp_x[0] = last_lp_x[1] = 0;
    }
    if (vic_display_frame_lines(1) == 263) interlace_frames++;
    for (int w = 0; w < 2; w++)
        if (!vic_display_lightpen_extra(w)) extra_cleared[w]++;
    clocks++;
}

bus idle() { return bus{}; }

bus write(unsigned reg, unsigned data) {
    bus b;
    b.rw = false;
    b.addr = 0x1000 | (next(16) << 4) | (reg & 15);
    b.data = data & 255;
    return b;
}

bus read(unsigned reg) {
    bus b;
    b.addr = 0x1000 | (next(16) << 4) | (reg & 15);
    return b;
}

void reset() { step(true, false, idle(), true, 0, 0); }

void fill_memory(unsigned style) {
    for (unsigned i = 0; i < sizeof(video); i++)
        video[i] = style == 0 ? uint8_t(next(256)) : uint8_t((i * 37 + style) ^ (i >> 5));
    for (unsigned i = 0; i < sizeof(color); i++)
        color[i] = uint8_t(next(16));
}

// A screen program loads registers, then runs clocks with sparse CPU traffic.
struct screen {
    unsigned regs[16];
};

void load(const screen &s) {
    for (unsigned r = 0; r < 16; r++)
        if (r != 4 && (r < 6 || r > 9)) step(false, true, write(r, s.regs[r]), true, 0x40, 0xc0);
}

void run(unsigned count, unsigned traffic, bool pen, bool holds) {
    bool pen_n = true;
    unsigned pen_left = 0, pot_x = next(256), pot_y = next(256);
    for (unsigned c = 0; c < count; c++) {
        bus b = idle();
        const unsigned roll = traffic ? next(traffic) : 1;
        if (roll == 0) {
            const unsigned kind = next(8);
            if (kind < 3) b = read(next(16));
            else if (kind < 5) b = write(14 + next(2), next(256));
            else b = write(10 + next(4), next(256));
        }
        if (pen) {
            if (pen_left == 0) {
                pen_n = !pen_n;
                pen_left = pen_n ? 1 + next(40000) : 1 + next(300);
            }
            pen_left--;
        }
        if (next(4096) == 0) {
            pot_x = next(256);
            pot_y = next(256);
        }
        const bool enable = !holds || next(97) != 0;
        if (!b.rw && !enable && next(2)) b = idle();
        step(false, enable, b, pen_n, pot_x, pot_y);
    }
}

screen standard(bool ntsc_like) {
    screen s{};
    s.regs[0] = ntsc_like ? 0x05 : 0x0c;
    s.regs[1] = ntsc_like ? 0x19 : 0x26;
    s.regs[2] = 0x96;
    s.regs[3] = 0x2e;
    s.regs[5] = 0xf0;
    s.regs[14] = 0x00;
    s.regs[15] = 0x1b;
    return s;
}

// Directed light-pen edges at every clock across the frame boundary of one
// profile, including the final-line extra-bit rule and capture relock. The
// captured coordinates are read back through registers 6 and 7.
void pen_sweep(int which) {
    reset();
    load(standard(which == 1));
    const unsigned span = 3 * (which ? 65 : 71) + 4;
    for (unsigned p = 0; p < span; p++) {
        while (!(vic_display_line(which) == vic_display_frame_lines(which) - 2 &&
                 vic_display_h(which) == 0))
            step(false, true, idle(), true, 0, 0);
        for (unsigned c = 0; c < p; c++) step(false, true, idle(), true, 0, 0);
        const unsigned hold = 1 + p % 7;
        for (unsigned c = 0; c < hold; c++) step(false, p % 11 != 3, idle(), false, 0, 0);
        step(false, true, read(6), true, 0, 0);
        step(false, true, read(7), true, 0, 0);
    }
}

screen random_screen() {
    screen s{};
    for (unsigned r = 0; r < 16; r++) s.regs[r] = next(256);
    // Keep most programs within the visible frame while still exercising
    // out-of-range origins, column/row counts and both character heights.
    if (next(4)) {
        s.regs[0] = next(20) | (next(8) == 0 ? 0x80 : 0);
        s.regs[1] = next(60);
        s.regs[2] = (s.regs[2] & 0x80) | next(34);
        s.regs[3] = (next(30) << 1) | next(2);
    }
    return s;
}
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 3 || !(vectors = std::fopen(argv[1], "w"))) return 2;
    record_limit = std::strtoull(argv[2], nullptr, 10);
    // Initialize before comparing uninitialized DUT state.
    dut.rst_n = 0; dut.clk = 0; dut.eval(); dut.clk = 1; dut.eval();
    fill_memory(0);
    reset();
    const unsigned frame = 71 * 312;
    // Standard 22x23 screens, quiet bus, then with color/sound/read traffic.
    load(standard(false));
    run(frame * 2, 0, false, false);
    run(frame * 2, 61, true, true);
    reset();
    load(standard(true));
    screen tall = standard(true);
    tall.regs[3] |= 1;
    tall.regs[15] = 0x08;
    load(tall);
    run(frame * 2, 37, true, false);
    // Random screen programs with traffic, pen pulses, holds and resets.
    for (unsigned program = 0; program < 160; program++) {
        if (program % 16 == 0) fill_memory(program / 16);
        if (next(8) == 0) reset();
        load(random_screen());
        run(frame / 2 + next(frame * 2), next(2) ? 0 : 1 + next(200), next(2), next(3) == 0);
    }
    // Fully random CPU traffic each clock to every register and mirror.
    reset();
    for (unsigned c = 0; c < frame * 4; c++) {
        bus b = next(3) ? idle() : (next(2) ? write(next(16), next(256)) : read(next(16)));
        step(next(50000) == 0, next(31) != 0, b, next(500) != 0, next(256), next(256));
    }
    pen_sweep(0);
    pen_sweep(1);
    // Interlace: register 0 bit 7 over many frames (NTSC alternates fields).
    reset();
    screen lace = standard(true);
    lace.regs[0] |= 0x80;
    load(lace);
    run(65 * 263 * 8, 101, true, false);
    std::fclose(vectors);
    for (int w = 0; w < 2; w++) {
        if (!matrix_fetches[w] || !char_fetches[w] || !captures[w] || !loud[w] ||
            !color_writes_in_display[w] || !extra_cleared[w]) {
            std::fprintf(stderr, "coverage hole profile %d: %llu %llu %llu %llu %llu\n", w,
                (unsigned long long)matrix_fetches[w], (unsigned long long)char_fetches[w],
                (unsigned long long)captures[w], (unsigned long long)loud[w],
                (unsigned long long)color_writes_in_display[w]);
            return 1;
        }
    }
    if (!interlace_frames || !reads_checked) return 1;
    std::printf("MOS 6560 VIC ORACLE PASS: %llu clocks, %llu profile comparisons, %llu replay records\n",
        (unsigned long long)clocks, (unsigned long long)comparisons, (unsigned long long)records);
    std::printf("coverage: matrix %llu/%llu, character %llu/%llu, light-pen captures %llu/%llu, "
        "sounding samples %llu/%llu, display color writes %llu/%llu, extra-bit clears %llu/%llu, interlace clocks %llu, reads %llu\n",
        (unsigned long long)matrix_fetches[0], (unsigned long long)matrix_fetches[1],
        (unsigned long long)char_fetches[0], (unsigned long long)char_fetches[1],
        (unsigned long long)captures[0], (unsigned long long)captures[1],
        (unsigned long long)loud[0], (unsigned long long)loud[1],
        (unsigned long long)color_writes_in_display[0], (unsigned long long)color_writes_in_display[1],
        (unsigned long long)extra_cleared[0], (unsigned long long)extra_cleared[1],
        (unsigned long long)interlace_frames, (unsigned long long)reads_checked);
}
