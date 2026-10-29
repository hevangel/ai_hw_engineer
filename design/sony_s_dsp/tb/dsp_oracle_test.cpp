// Lock-step comparison of sony_s_dsp against blargg's cycle-accurate SPC_DSP
// (pinned in work/oracle by scripts/fetch_oracle.py). Both models start from
// the same random audio RAM and receive the same register writes at the same
// phase; after every phase all 128 registers must match, every output sample
// must match, and the audio RAM (echo writes) must match at the end.
#include "Vsony_s_dsp.h"
#include "Vsony_s_dsp___024root.h"
#include "verilated.h"
#include "snes9x.h"
#include "SPC_DSP.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>

S9xSettingsShim Settings;

struct Rtl {
    Vsony_s_dsp m;
    std::vector<uint8_t> ram = std::vector<uint8_t>(65536);
    std::vector<short> samples;
    void clock() {
        m.clk = 0;
        m.eval();
        uint16_t a = m.ram_addr;
        uint8_t next = ram[a];
        if (m.ram_we) ram[a] = m.ram_wdata;
        m.clk = 1;
        m.eval();
        m.ram_rdata = next;
        m.eval();
        if (m.sample_valid) {
            samples.push_back((short)m.sample_l);
            samples.push_back((short)m.sample_r);
        }
    }
    uint8_t reg(int i) { return m.rootp->sony_s_dsp__DOT__regs[i]; }
};

static int value_for(std::mt19937& rng, int addr) {
    int v = rng() & 0xff;
    switch (addr) {
    case 0x6c: // FLG: soft reset and mute only now and then
        v &= 0x3f;
        if ((rng() & 15) == 0) v |= 0x80;
        if ((rng() & 7) == 0) v |= 0x40;
        break;
    case 0x7d: v &= (rng() & 3) ? 0x03 : 0x0f; break; // EDL
    case 0x4c: if (rng() & 1) v &= v >> 1; break;      // KON, sparser
    case 0x5c: if (rng() & 1) v = 0; break;            // KOFF
    }
    return v;
}

static int run_seed(unsigned seed, int samples, int write_rate) {
    std::mt19937 rng(seed);
    Rtl rtl;
    std::vector<uint8_t> ref_ram(65536);
    for (auto& b : ref_ram) b = rng() & 0xff;
    rtl.ram = ref_ram;

    SPC_DSP dsp;
    Resampler out;
    dsp.init(ref_ram.data());
    uint8_t zeros[128] = {};
    dsp.load(zeros);
    for (int i = 0; i < 128; ++i) dsp.write(i, i == 0x6c ? 0xe0 : 0);
    dsp.set_output(&out);

    rtl.m.rst_n = 0;
    rtl.m.tick = 0;
    rtl.m.reg_wr = 0;
    rtl.m.smp_wr = 0;
    rtl.m.smp_addr = 0;
    for (int i = 0; i < 4; ++i) rtl.clock();
    rtl.m.rst_n = 1;

    long ticks = (long)samples * 32;
    for (long t = 0; t < ticks; ++t) {
        int addr = -1, data = 0;
        if ((int)(rng() % write_rate) == 0 || t == 64) {
            addr = t == 64 ? 0x4c : (int)(rng() & 0x7f);  // early key-on of all voices
            data = t == 64 ? 0xff : value_for(rng, addr);
        }
        if (addr >= 0) dsp.write(addr, data);
        dsp.run(1);
        rtl.m.tick = 1;
        rtl.m.reg_wr = addr >= 0;
        rtl.m.reg_addr = addr & 0x7f;
        rtl.m.reg_wdata = data;
        rtl.clock();
        rtl.m.tick = 0;
        rtl.m.reg_wr = 0;
        for (int c = 0; c < 20; ++c) rtl.clock();
        if (rtl.m.overrun_o) { printf("seed %u: micro-op overrun\n", seed); return 1; }
        for (int i = 0; i < 128; ++i) {
            if (rtl.reg(i) != dsp.read(i)) {
                printf("seed %u tick %ld (phase %ld, sample %ld): reg $%02x rtl=%02x ref=%02x (last write %d=%02x)\n",
                       seed, t, t % 32, t / 32, i, rtl.reg(i), dsp.read(i), addr, data);
                return 1;
            }
        }
        size_t n = rtl.samples.size() < out.samples.size() ? rtl.samples.size() : out.samples.size();
        for (size_t i = 0; i < n; ++i) {
            if (rtl.samples[i] != out.samples[i]) {
                printf("seed %u tick %ld: sample %zu.%s rtl=%d ref=%d\n", seed, t, i / 2,
                       i & 1 ? "R" : "L", rtl.samples[i], out.samples[i]);
                return 1;
            }
        }
        if (rtl.samples.size() != out.samples.size() && t % 32 == 31) {
            printf("seed %u tick %ld: sample count rtl=%zu ref=%zu\n", seed, t,
                   rtl.samples.size(), out.samples.size());
            return 1;
        }
        rtl.samples.erase(rtl.samples.begin(), rtl.samples.begin() + n);
        out.samples.erase(out.samples.begin(), out.samples.begin() + n);
    }
    for (int a = 0; a < 65536; ++a) {
        if (rtl.ram[a] != ref_ram[a]) {
            printf("seed %u: audio RAM $%04x rtl=%02x ref=%02x\n", seed, a, rtl.ram[a], ref_ram[a]);
            return 1;
        }
    }
    return 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    int seeds = argc > 1 ? atoi(argv[1]) : 20;
    int samples = argc > 2 ? atoi(argv[2]) : 2000;
    int fails = 0;
    for (int s = 1; s <= seeds; ++s) {
        int rate = s % 3 == 0 ? 8 : s % 3 == 1 ? 64 : 512;
        fails += run_seed(s, samples, rate);
        if (fails >= 3) break;
    }
    if (fails) { printf("FAIL: %d seed(s)\n", fails); return 1; }
    printf("S-DSP ORACLE PASS: seeds=%d samples_per_seed=%d phases=%ld\n", seeds, samples,
           (long)seeds * samples * 32);
    return 0;
}
