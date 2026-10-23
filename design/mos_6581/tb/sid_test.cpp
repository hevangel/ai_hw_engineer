// Cycle-by-cycle comparison of mos_6581 with the unchanged reSIDfp digital
// engine (tb/sid_oracle.cpp): all three 12-bit waveform outputs and 8-bit
// envelope counters every clock, and every register read (POT, OSC3, ENV3,
// decaying bus latch). Pull-down lookups are answered from reSIDfp's own
// combined-waveform table for the selected model.
#include "Vmos_6581.h"
#include "verilated.h"
#include "Vmos_6581___024root.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

extern "C" {
void sid_init(int);
void sid_clock(void);
unsigned sid_read(unsigned);
void sid_write(unsigned, unsigned);
void sid_paddle(unsigned, unsigned);
unsigned sid_wave(int);
unsigned sid_env(int);
unsigned sid_acc(int);
unsigned sid_bus(void);
unsigned sid_pulldown(int, unsigned);
unsigned sid_sr(int);
unsigned sid_latch(int);
unsigned sid_pipe(int);
unsigned sid_noise(int);
}

namespace {
Vmos_6581 dut;
int model;
uint64_t rng = 0x9b97f4a7c15e3779ull;
uint64_t cycles, reads, writes, combined_cycles, noise_cycles, sync_cycles, attack_steps;
uint64_t test_cycles, envelope_moves, attack_peaks, release_floors;
unsigned last_env[3];

uint32_t next(unsigned bound) {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return uint32_t(rng % bound);
}

// Bit field of a Verilator wide (multi-word) signal.
template <typename W> unsigned field(const W &w, int lsb, int width) {
    unsigned value = 0;
    for (int b = 0; b < width; b++)
        value |= ((w[(lsb + b) / 32] >> ((lsb + b) % 32)) & 1u) << b;
    return value;
}

[[noreturn]] void fail(const std::string &what) {
    for (int v = 0; v < 3; v++)
        std::fprintf(stderr, "voice %d ref sr %06x latch %06x pipe %u noise %03x | rtl sr %06x latch %06x pipe %u noise %03x\n", v,
            sid_sr(v), sid_latch(v), sid_pipe(v), sid_noise(v),
            field(dut.rootp->mos_6581__DOT__sr_q, 23 * v, 23),
            field(dut.rootp->mos_6581__DOT__latch_q, 23 * v, 23),
            unsigned(dut.rootp->mos_6581__DOT__pipe_q >> (2 * v)) & 3,
            unsigned(dut.rootp->mos_6581__DOT__noise_q >> (12 * v)) & 0xfff);
    std::fprintf(stderr, "SID model %d mismatch at cycle %llu: %s\n", model,
                 (unsigned long long)cycles, what.c_str());
    std::exit(1);
}

void settle() {
    // Voice outputs chain through the previous voice's accumulator, so the
    // external table is answered in voice order.
    for (int pass = 0; pass < 4; pass++) {
        dut.eval();
        for (int v = 0; v < 3; v++) {
            const unsigned sel = (dut.pd_sel_o >> (3 * v)) & 7;
            const unsigned index = unsigned((dut.pd_index_o >> (12 * v)) & 0xfff);
            const unsigned value = sel ? sid_pulldown(int(sel) - 1, index) : 0;
            dut.pd_value_i = (dut.pd_value_i & ~(uint64_t(0xfff) << (12 * v))) |
                             (uint64_t(value) << (12 * v));
        }
        const unsigned sel3 = (dut.pd_sel_o >> 6) & 7;
        dut.osc3_pd_value_i = sel3 ? sid_pulldown(int(sel3) - 1, dut.osc3_pd_index_o) : 0;
    }
    dut.eval();
}

struct cpu_access {
    bool valid = false, read = true;
    unsigned reg = 0, data = 0;
};

// Oracle-checked pre-edge record for the SV replay bench: inputs including
// the settled pull-down answers, then the observable outputs.
FILE *vectors;
uint64_t records, record_limit;

void record() {
    if (!vectors || records >= record_limit) return;
    const uint64_t pd = uint64_t(dut.pd_value_i);
    const uint64_t index = uint64_t(dut.pd_index_o);
    std::fprintf(vectors, "%x %x %x %x %x %x %x %x %llx %x %x %x %llx %llx %x %x\n",
                 unsigned(dut.rst_n), unsigned(dut.ce_i), unsigned(dut.cs_i), unsigned(dut.rw_i),
                 unsigned(dut.addr_i), unsigned(dut.data_i), unsigned(dut.pot_x_i),
                 unsigned(dut.pot_y_i), (unsigned long long)pd, unsigned(dut.osc3_pd_value_i),
                 unsigned(dut.data_o), unsigned(dut.env_o), (unsigned long long)uint64_t(dut.wave_o),
                 (unsigned long long)index, unsigned(dut.pd_sel_o), unsigned(dut.osc3_pd_index_o));
    records++;
}

void step(const cpu_access &a, unsigned pot_x, unsigned pot_y) {
    dut.clk = 0;
    dut.ce_i = 1;
    dut.cs_i = a.valid;
    dut.rw_i = a.read;
    dut.addr_i = a.reg & 31;
    dut.data_i = a.data & 255;
    dut.pot_x_i = pot_x;
    dut.pot_y_i = pot_y;
    sid_paddle(pot_x, pot_y);
    settle();
    record();
    if (a.valid) {
        if (a.read) {
            const unsigned want = sid_read(a.reg & 31);
            if (dut.data_o != want)
                fail("read $" + std::to_string(a.reg & 31) + " rtl " + std::to_string(dut.data_o) +
                     " ref " + std::to_string(want));
            reads++;
        } else {
            sid_write(a.reg & 31, a.data & 255);
            writes++;
        }
    }
    sid_clock();
    dut.clk = 1;
    settle();
    dut.clk = 0;
    settle();
    for (int v = 0; v < 3; v++) {
        const unsigned w = unsigned((dut.wave_o >> (12 * v)) & 0xfff);
        const unsigned e = (dut.env_o >> (8 * v)) & 0xff;
        if (w != sid_wave(v))
            fail("voice " + std::to_string(v) + " wave rtl " + std::to_string(w) + " ref " +
                 std::to_string(sid_wave(v)) + " acc " + std::to_string(sid_acc(v)));
        if (e != sid_env(v))
            fail("voice " + std::to_string(v) + " envelope rtl " + std::to_string(e) +
                 " ref " + std::to_string(sid_env(v)));
        if (std::getenv("SID_SR_CHECK") && field(dut.rootp->mos_6581__DOT__sr_q, 23 * v, 23) != sid_sr(v))
            fail("voice " + std::to_string(v) + " shift register");
        if (e != last_env[v]) envelope_moves++;
        last_env[v] = e;
    }
    cycles++;
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

void reset() {
    dut.rst_n = 0;
    dut.cs_i = 0;
    dut.ce_i = 0;
    for (int i = 0; i < 2; i++) {
        dut.clk = 0;
        settle();
        record();
        dut.clk = 1;
        settle();
    }
    dut.clk = 0;
    dut.rst_n = 1;
    settle();
    sid_init(model);
    for (int v = 0; v < 3; v++) last_env[v] = sid_env(v);
}

// A voice program: frequency, pulse width, ADSR and a control byte.
void program_voice(unsigned v, unsigned control, bool short_env) {
    const unsigned base = 7 * v;
    step(write(base + 0, next(256)), 0x80, 0x40);
    step(write(base + 1, next(4) ? next(64) : next(256)), 0x80, 0x40);
    step(write(base + 2, next(256)), 0x80, 0x40);
    step(write(base + 3, next(16)), 0x80, 0x40);
    step(write(base + 5, short_env ? next(0x34) : next(256)), 0x80, 0x40);
    step(write(base + 6, short_env ? (next(16) << 4) | next(4) : next(256)), 0x80, 0x40);
    step(write(base + 4, control), 0x80, 0x40);
}

void run(unsigned count, unsigned traffic) {
    unsigned px = next(256), py = next(256);
    for (unsigned c = 0; c < count; c++) {
        cpu_access a;
        if (traffic && next(traffic) == 0) {
            const unsigned k = next(16);
            if (k < 5) a = read(next(32));
            else if (k < 7) a = read(0x1b + next(2));
            else if (k < 11) a = write(7 * next(3) + 4, next(256));
            else if (k < 13) a = write(7 * next(3) + next(7), next(256));
            else a = write(0x15 + next(11), next(256));
        }
        if (next(65536) == 0) {
            px = next(256);
            py = next(256);
        }
        step(a, px, py);
    }
}
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) return 2;
    model = std::atoi(argv[1]);
    const unsigned scale = argc > 2 ? unsigned(std::atoi(argv[2])) : 1;
    if (argc > 4) {
        vectors = std::fopen(argv[3], "w");
        record_limit = std::strtoull(argv[4], nullptr, 10);
        if (!vectors) return 2;
    }
    dut.pd_value_i = 0;
    reset();
    // Every waveform combination with gate, ring and sync, on all voices.
    for (unsigned w = 0; w < 16; w++) {
        for (unsigned v = 0; v < 3; v++)
            program_voice(v, (w << 4) | (next(2) << 2) | (next(2) << 1) | 1, true);
        run(20000 * scale, 0);
        for (unsigned v = 0; v < 3; v++) step(write(7 * v + 4, w << 4), 0x80, 0x40);
        run(5000 * scale, 0);
        if (w >= 9 || w == 3 || w >= 5) combined_cycles += 25000 * scale;
        if (w & 8) noise_cycles += 25000 * scale;
    }
    // Random programs with dense register traffic.
    for (unsigned p = 0; p < 40 * scale; p++) {
        if (next(10) == 0) reset();
        for (unsigned v = 0; v < 3; v++) program_voice(v, next(256), next(2));
        run(5000 + next(40000), 1 + next(64));
    }
    // Test bit held long enough for the shift-register reset/fade, and
    // waveform 0 long enough for the floating-output fade.
    reset();
    // Noise runs first so the shift register holds sparse bits when the
    // test bit starts the reset/fade timers.
    for (unsigned v = 0; v < 3; v++) program_voice(v, 0x81, true);
    run(20000, 0);
    for (unsigned v = 0; v < 3; v++) step(write(7 * v + 4, 0x08), 0x80, 0x40);
    run(model ? 1400000 : 120000, 0);
    test_cycles += model ? 1400000 : 120000;
    for (unsigned v = 0; v < 3; v++) step(write(7 * v + 4, 0x80), 0x80, 0x40);
    run(2000, 0);
    for (unsigned v = 0; v < 3; v++) step(write(7 * v + 4, 0x00), 0x80, 0x40);
    run(model ? 1000000 : 80000, 0);
    // Hard sync and ring modulation chains at many frequency ratios.
    for (unsigned r = 0; r < 64 * scale; r++) {
        for (unsigned v = 0; v < 3; v++) program_voice(v, 0x10 << next(3) | 0x07, true);
        run(8000, 0);
        sync_cycles += 8000;
    }
    // Every attack/decay/release rate and sustain level: each voice runs a
    // different rate; attacks must reach $FF and releases must reach $00 for
    // the fast rates.
    for (unsigned r = 0; r < 16; r += 3) {
        reset();
        for (unsigned v = 0; v < 3 && r + v < 16; v++) {
            const unsigned rate = r + v;
            step(write(7 * v + 1, 0x08), 0x80, 0x40);
            step(write(7 * v + 5, (rate << 4) | rate), 0x80, 0x40);
            step(write(7 * v + 6, ((15 - rate) << 4) | rate), 0x80, 0x40);
            step(write(7 * v + 4, 0x21), 0x80, 0x40);
        }
        bool peak[3] = {false, false, false}, floor[3] = {false, false, false};
        for (unsigned c = 0; c < 300000; c++) {
            step(cpu_access{}, 0x80, 0x40);
            for (int v = 0; v < 3; v++) if (sid_env(v) == 0xff) peak[v] = true;
        }
        for (unsigned v = 0; v < 3 && r + v < 16; v++) step(write(7 * v + 4, 0x20), 0x80, 0x40);
        for (unsigned c = 0; c < 300000; c++) {
            step(cpu_access{}, 0x80, 0x40);
            for (int v = 0; v < 3; v++) if (sid_env(v) == 0) floor[v] = true;
        }
        for (unsigned v = 0; v < 3 && r + v < 16; v++) {
            if (peak[v]) attack_peaks++;
            if (floor[v]) release_floors++;
        }
    }
    if (attack_peaks < 9 || release_floors < 6) {
        std::fprintf(stderr, "envelope coverage hole: %llu peaks, %llu floors\n",
                     (unsigned long long)attack_peaks, (unsigned long long)release_floors);
        return 1;
    }
    // Hard-sync exception: a sync source whose own MSB rises in the cycle it
    // is synchronized must not sync its destination. High random
    // frequencies with sync on every voice make MSB rises coincide.
    uint64_t sync_exceptions = 0;
    for (unsigned r = 0; r < 400 && sync_exceptions < 50; r++) {
        for (unsigned v = 0; v < 3; v++) {
            step(write(7 * v + 0, next(256)), 0x80, 0x40);
            step(write(7 * v + 1, 0x80 + next(128)), 0x80, 0x40);
            step(write(7 * v + 4, 0x22 | (next(2) << 2)), 0x80, 0x40);
        }
        for (unsigned c = 0; c < 20000; c++) {
            step(cpu_access{}, 0x80, 0x40);
            const unsigned msb = dut.rootp->mos_6581__DOT__msb_q;
            const unsigned sync = dut.rootp->mos_6581__DOT__sync_q;
            for (int i = 0; i < 3; i++) {
                const int prev = (i + 2) % 3, nextv = (i + 1) % 3;
                if ((msb >> i & 1) && (msb >> prev & 1) && (sync >> i & 1) && (sync >> nextv & 1))
                    sync_exceptions++;
            }
        }
    }
    if (sync_exceptions == 0) {
        std::fprintf(stderr, "coverage hole: no coincident sync exception\n");
        return 1;
    }
    // Gate toggles at every phase of the envelope pipelines.
    for (unsigned g = 0; g < 4000 * scale; g++) {
        step(write(7 * next(3) + 4, 0x10 | next(2)), 0x80, 0x40);
        for (unsigned d = next(40); d; d--) step(cpu_access{}, 0x80, 0x40);
        attack_steps++;
    }
    if (!envelope_moves || !reads || !writes) return 1;
    if (vectors) std::fclose(vectors);
    std::printf("MOS 6581 SID ORACLE PASS: model %s, %llu cycles, %llu reads, %llu writes, "
                "%llu envelope changes, %llu attack peaks, %llu release floors, "
                "%llu sync-program cycles, %llu test-hold cycles, %llu replay records\n",
                model ? "8580" : "6581", (unsigned long long)cycles, (unsigned long long)reads,
                (unsigned long long)writes, (unsigned long long)envelope_moves,
                (unsigned long long)attack_peaks, (unsigned long long)release_floors,
                (unsigned long long)sync_cycles, (unsigned long long)test_cycles,
                (unsigned long long)records);
}
