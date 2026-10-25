// Dot-by-dot comparison of mos_6567 with the unchanged MAME VIC-II
// (tb/vicii_oracle.cpp). Per system clock: phase-one/phase-two fetch
// addresses and their order, BA, AEC and IRQ after the cycle logic, CPU
// register reads, and the complete pixel stream (row, column, color).
#include "Vmos_6567.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <string>

extern "C" {
void vicii_init(int, int, const uint8_t *, const uint8_t *, int);
void vicii_set_rom_window(int, int);
void vicii_clock(int, int);
unsigned vicii_read(int, unsigned);
void vicii_write(int, unsigned, unsigned);
unsigned vicii_fetch_count(int);
unsigned vicii_fetch(int, unsigned);
int vicii_irq(int);
int vicii_ba(int);
int vicii_aec(int);
int vicii_cycle(int);
int vicii_rasterline(int);
unsigned vicii_pixel_count(int);
int vicii_pixel_pop(int, int *, int *);
}

namespace {
Vmos_6567 dut;
uint8_t video[1 << 14], color_ram[1 << 10];
uint64_t rng = 0x2545f4914f6cdd1dull;
uint64_t cycles, pixels, fetches, reads, writes, irq_cycles, ba_cycles;
uint64_t sprite_cycles, collision_reads, phi2_fetches, pen_captures, mode_cycles[8];
int variant, rom_window;
struct pixel {
    int row, col, color;
};
std::deque<pixel> rtl_pixels;
// Oracle-checked dot records for the SV replay bench (first N dots).
FILE *vectors;
uint64_t records, record_limit;

uint32_t next(unsigned bound) {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return uint32_t(rng % bound);
}

[[noreturn]] void fail(const std::string &what) {
    std::fprintf(stderr, "VIC-II variant %d mismatch at cycle %llu (ref cycle %d line %d): %s\n",
                 variant, (unsigned long long)cycles, vicii_cycle(0), vicii_rasterline(0), what.c_str());
    std::exit(1);
}

void settle() {
    dut.eval();
    dut.phi1_data_i = video[dut.phi1_addr_o];
    dut.eval();
    dut.phi2_data_i = video[dut.phi2_addr_o];
    dut.color_data_i = color_ram[dut.color_addr_o] & 15;
    dut.eval();
}

void edge() {
    settle();
    if (dut.pixel_valid_o) rtl_pixels.push_back({dut.pixel_row_o, dut.pixel_col_o, dut.pixel_o});
    if (vectors && records < record_limit) {
        const uint64_t a = (uint64_t(dut.pixel_valid_o) << 34) | (uint64_t(dut.pixel_o) << 30) |
                           (uint64_t(dut.pixel_row_o) << 21) | (uint64_t(dut.pixel_col_o) << 11) |
                           (uint64_t(dut.data_o) << 3) | (uint64_t(dut.irq_n_o) << 2) |
                           (uint64_t(dut.ba_o) << 1) | uint64_t(dut.aec_o);
        const uint64_t b = (uint64_t(dut.cycle_edge_o) << 40) | (uint64_t(dut.phi1_addr_o) << 26) |
                           (uint64_t(dut.phi2_fetch_o) << 25) | (uint64_t(dut.phi2_addr_o) << 11) |
                           (uint64_t(dut.color_fetch_o) << 10) | uint64_t(dut.color_addr_o);
        std::fprintf(vectors, "%x %x %x %x %x %x %x %x %x %x %llx %llx\n", unsigned(dut.rst_n),
                     unsigned(dut.cs_i), unsigned(dut.rw_i), unsigned(dut.addr_i),
                     unsigned(dut.data_i), unsigned(dut.lp_n_i), unsigned(dut.rom_window_i),
                     unsigned(dut.phi1_data_i), unsigned(dut.phi2_data_i),
                     unsigned(dut.color_data_i), (unsigned long long)a, (unsigned long long)b);
        records++;
    }
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

void compare_pixels() {
    while (!rtl_pixels.empty() && vicii_pixel_count(0)) {
        int row, col;
        const int c = vicii_pixel_pop(0, &row, &col);
        const pixel p = rtl_pixels.front();
        rtl_pixels.pop_front();
        if (p.row != row || p.col != col || p.color != c) {
            char text[160];
            std::snprintf(text, sizeof text, "pixel rtl (%d,%d)=%d ref (%d,%d)=%d", p.row, p.col,
                          p.color, row, col, c);
            fail(text);
        }
        pixels++;
    }
}

struct cpu_access {
    bool valid = false, read = true;
    unsigned reg = 0, data = 0;
};

// One system clock: cycle-logic edge (with fetches), then the CPU cpu_access
// across the cycle's remaining dots.
void cycle(const cpu_access &a, bool pen_n) {
    dut.lp_n_i = pen_n;
    dut.cs_i = 0;
    settle();
    if (!dut.cycle_edge_o) fail("RTL not at a cycle edge");
    vicii_clock(0, pen_n);
    const unsigned count = vicii_fetch_count(0);
    const unsigned rtl_count = 1 + dut.phi2_fetch_o;
    if (count != rtl_count) fail("fetch count " + std::to_string(rtl_count) + " vs " + std::to_string(count));
    if (dut.phi1_addr_o != vicii_fetch(0, 0))
        fail("phase-one address " + std::to_string(dut.phi1_addr_o) + " vs " + std::to_string(vicii_fetch(0, 0)));
    if (dut.phi2_fetch_o && dut.phi2_addr_o != vicii_fetch(0, 1)) fail("phase-two address");
    fetches += count;
    phi2_fetches += dut.phi2_fetch_o;
    edge();
    if (dut.ba_o != vicii_ba(0) || dut.aec_o != vicii_aec(0)) fail("BA/AEC");
    if (dut.irq_n_o != !vicii_irq(0)) fail("IRQ");
    if (!dut.irq_n_o) irq_cycles++;
    if (!dut.ba_o) ba_cycles++;
    dut.cs_i = a.valid;
    dut.rw_i = a.read;
    dut.addr_i = a.reg & 63;
    dut.data_i = a.data & 255;
    unsigned expected = 0;
    if (a.valid) {
        if (a.read) {
            expected = vicii_read(0, a.reg & 63);
            reads++;
            if ((a.reg & 63) == 0x1e || (a.reg & 63) == 0x1f) collision_reads++;
        } else {
            vicii_write(0, a.reg & 63, a.data & 255);
            writes++;
        }
    }
    for (int d = 0; d < 7; d++) edge();
    if (a.valid && a.read && dut.data_o != expected)
        fail("read $" + std::to_string(a.reg & 63) + " rtl " + std::to_string(dut.data_o) +
             " ref " + std::to_string(expected));
    compare_pixels();
    cycles++;
}

void reset() {
    dut.rst_n = 0;
    dut.cs_i = 0;
    dut.lp_n_i = 1;
    dut.rom_window_i = rom_window;
    for (int i = 0; i < 3; i++) edge();
    dut.rst_n = 1;
    rtl_pixels.clear();
    vicii_init(0, variant, video, color_ram, rom_window);
}

cpu_access write(unsigned reg, unsigned data) {
    cpu_access a;
    a.valid = true;
    a.read = false;
    a.reg = reg;
    a.data = data;
    return a;
}

cpu_access read(unsigned reg) {
    cpu_access a;
    a.valid = true;
    a.reg = reg;
    return a;
}

void fill(unsigned style) {
    for (unsigned i = 0; i < sizeof video; i++)
        video[i] = style == 0 ? uint8_t(next(256)) : uint8_t((i * 13 + style * 7) ^ (i >> 7));
    for (unsigned i = 0; i < sizeof color_ram; i++) color_ram[i] = uint8_t(next(16));
    // Sprite pointers at the default and random screens point to dense data.
    for (unsigned s = 0; s < 8; s++) video[0x07f8 + s] = uint8_t(0x80 + s);
}

void program(const uint8_t *regs, unsigned count) {
    for (unsigned r = 0; r < count; r++) cycle(write(r, regs[r]), true);
}

// Run with sparse random CPU traffic, optional pen pulses and mode flips.
void run(unsigned count, unsigned traffic, bool pen, bool chaos) {
    bool pen_n = true;
    unsigned pen_left = 0;
    for (unsigned c = 0; c < count; c++) {
        cpu_access a;
        if (traffic && next(traffic) == 0) {
            const unsigned k = next(10);
            if (k < 3) a = read(next(64));
            else if (k < 4) a = read(0x19 + next(2) * 5 + (next(2) ? 1 : 0));
            else if (k < 6) a = write(0x19, next(16));
            else if (chaos) a = write(next(0x30), next(256));
            else a = write(0x20 + next(15), next(256));
        }
        if (pen) {
            if (pen_left == 0) {
                pen_n = !pen_n;
                pen_left = pen_n ? 1 + next(30000) : 1 + next(200);
            }
            pen_left--;
        }
        cycle(a, pen_n);
    }
}

const uint8_t kernal_like[0x2f] = {
    // sprite X/Y pairs
    0x18, 0x32, 0x40, 0x3a, 0x60, 0x50, 0x90, 0x70, 0xc8, 0x90, 0x10, 0xa0, 0x30, 0x60, 0xff, 0xe0,
    0x81, 0x1b, 0x30, 0x00, 0x00, 0xff, 0xc8, 0x05, 0x14, 0x00, 0x0f, 0x22, 0x55, 0x09, 0x00, 0x00,
    0x0e, 0x06, 0x01, 0x02, 0x03, 0x04, 0x05, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0f};
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) return 2;
    variant = std::atoi(argv[1]);
    const unsigned scale = argc > 2 ? unsigned(std::atoi(argv[2])) : 1;
    if (argc > 4) {
        vectors = std::fopen(argv[3], "w");
        record_limit = std::strtoull(argv[4], nullptr, 10);
        if (!vectors) return 2;
    }
    const unsigned cpl = (variant == 1 || variant == 4) ? 65 : variant == 2 ? 64 : 63;
    const unsigned lines = (variant == 1 || variant == 4) ? 263 : variant == 2 ? 262 : 312;
    const unsigned frame = cpl * lines;
    dut.clk = 0;
    rom_window = 1;
    fill(0);
    reset();
    // KERNAL-like text screen with all eight sprites, IRQs enabled.
    program(kernal_like, sizeof kernal_like);
    run(frame * 2, 0, false, false);
    cycle(write(0x1a, 0x0f), true);
    run(frame * 2 * scale, 40, true, false);
    // Every graphics mode, scroll and border setting, with sprite traffic.
    for (unsigned m = 0; m < 8; m++) {
        cycle(write(0x11, 0x1b | ((m & 4) << 4) | ((m & 2) << 4) | (m & 1 ? 0 : 0x08)), true);
        cycle(write(0x16, 0xc8 | ((m & 1) << 4) | next(8) | (m & 2 ? 0 : 0x08)), true);
        cycle(write(0x18, uint8_t(next(256))), true);
        run(frame * scale, 60, m & 1, false);
        mode_cycles[m] += frame * scale;
    }
    // Random register programs over both character-ROM windows.
    for (unsigned p = 0; p < 24 * scale; p++) {
        if (p % 6 == 0) {
            fill(p);
            rom_window = int(next(2));
            dut.rom_window_i = rom_window;
            vicii_set_rom_window(0, rom_window);
        }
        if (next(5) == 0) reset();
        uint8_t regs[0x2f];
        for (unsigned r = 0; r < 0x2f; r++) regs[r] = uint8_t(next(256));
        regs[0x11] = uint8_t((regs[0x11] & 0x7f) | 0x10);
        regs[0x1a] = uint8_t(next(16));
        program(regs, 0x2f);
        run(frame / 2 + next(frame), 1 + next(30), next(2), next(2));
    }
    // Per-line register changes: force bad lines, open borders, crunch sprites.
    reset();
    program(kernal_like, sizeof kernal_like);
    for (unsigned l = 0; l < lines * 2 * scale; l++) {
        for (unsigned c = 0; c < cpl; c++) {
            cpu_access a;
            const unsigned k = next(cpl * 2);
            if (k == 0) a = write(0x11, 0x18 | (next(8)) | (next(4) == 0 ? 0x60 : 0));
            else if (k == 1) a = write(0x16, 0xc0 | next(32));
            else if (k == 2) a = write(0x17, next(256));
            else if (k == 3) a = write(0x1d, next(256));
            else if (k == 4) a = write(0x1c, next(256));
            else if (k == 5) a = read(0x1e + next(2));
            else if (k == 6) a = write(0x15, next(256));
            cycle(a, true);
        }
    }
    // Continuous sprite-sprite and sprite-background collisions with IRQs:
    // acknowledge, then read $1E/$1F at varied phases (collision hold).
    reset();
    for (unsigned i = 0x2000; i < 0x2000 + 0x200; i++) video[i] = 0xff;
    for (unsigned s = 0; s < 8; s++) video[0x07f8 + s] = 0x80;
    program(kernal_like, sizeof kernal_like);
    for (unsigned s = 0; s < 8; s++) {
        cycle(write(2 * s, 0x60 + 2 * s), true);
        cycle(write(2 * s + 1, 0x70 + s), true);
    }
    cycle(write(0x10, 0x00), true);
    cycle(write(0x1a, 0x06), true);
    for (unsigned n = 0; n < 4000 * scale; n++) {
        cycle(write(0x19, 0x0f), true);
        for (unsigned g = next(24); g; g--) cycle(cpu_access{}, true);
        cycle(read(0x1e + next(2)), true);
        for (unsigned g = next(24); g; g--) cycle(cpu_access{}, true);
        cycle(read(0x19), true);
    }
    // Sprite crunching: Y-expansion writes in cycles 14..16 of each line.
    reset();
    program(kernal_like, sizeof kernal_like);
    cycle(write(0x17, 0xff), true);
    for (unsigned l = 0; l < lines * 3 * scale; l++) {
        for (unsigned c = 0; c < cpl; c++) {
            cpu_access a;
            const int next_cycle = vicii_cycle(0);
            if (next_cycle >= 14 && next_cycle <= 16 && next(3) == 0) a = write(0x17, next(256));
            cycle(a, true);
        }
    }
    sprite_cycles = 0;    if (!irq_cycles || !ba_cycles || !phi2_fetches || !collision_reads || !writes) {
        std::fprintf(stderr, "coverage hole: irq %llu ba %llu phi2 %llu coll %llu writes %llu\n",
                     (unsigned long long)irq_cycles, (unsigned long long)ba_cycles,
                     (unsigned long long)phi2_fetches, (unsigned long long)collision_reads,
                     (unsigned long long)writes);
        return 1;
    }
    if (vectors) std::fclose(vectors);
    std::printf("MOS 6567 VIC-II ORACLE PASS: variant %d, %llu cycles, %llu pixels, %llu fetches "
                "(%llu phase two), %llu reads (%llu collision), %llu writes, %llu IRQ cycles, "
                "%llu BA cycles, %llu replay records\n",
                variant, (unsigned long long)cycles, (unsigned long long)pixels,
                (unsigned long long)fetches, (unsigned long long)phi2_fetches,
                (unsigned long long)reads, (unsigned long long)collision_reads,
                (unsigned long long)writes, (unsigned long long)irq_cycles,
                (unsigned long long)ba_cycles, (unsigned long long)records);
}
