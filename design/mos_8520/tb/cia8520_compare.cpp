// Comparison of mos_8520 with MAME's 8520 (unchanged): reads, IRQ and the TOD counter.
// (unchanged) on random register traffic: every read and the IRQ line.
#include "Vmos_8520.h"
#include "verilated.h"
#include "Vmos_8520___024root.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" {
void cia_init(int);
void cia_clock(void);
unsigned cia_read(unsigned);
void cia_write(unsigned, unsigned);
void cia_pins(unsigned, unsigned);
int cia_irq(void);
unsigned cia_ta(void); unsigned cia_tb(void); unsigned cia_icr(void); unsigned cia_imr(void);
unsigned cia_cra(void); unsigned cia_crb(void);
void cia_tod(int); unsigned cia_tod_value(void);
}

static Vmos_8520 dut;
static uint64_t rng = 0x1234567887654321ull, cycles, reads, mism, irq_mism;
static char history[64][64];
static unsigned hist_pos;
static uint32_t next(unsigned b) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return uint32_t(rng % b); }

static FILE *vectors;
static uint64_t records, record_limit;

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc > 3) {
        vectors = std::fopen(argv[2], "w");
        record_limit = std::strtoull(argv[3], nullptr, 10);
        if (!vectors) return 2;
    }
    const int order = argc > 1 ? std::atoi(argv[1]) : 0;
    dut.cs_n = 1; dut.rw = 1; dut.pa_i = 0xff; dut.pb_i = 0xff;
    dut.cnt_i = 1; dut.sp_i = 1; dut.flag_n_i = 1; dut.tod_i = 0;
    dut.rst_n = 0;
    for (int i = 0; i < 4; i++) { dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval(); }
    dut.rst_n = 1;
    cia_init(2);
    cia_pins(0xff, 0xff);
    for (cycles = 0; cycles < 2000000; cycles++) {
        bool access = next(4) == 0, write = access && next(3) == 0;
        unsigned reg = next(16), data = next(256);
        // Optional: avoid the classified stopped-timer reload-latency case.
        static uint64_t quiet_until[2];
        if (std::getenv("AVOID_RELOAD") && access && reg >= 4 && reg <= 7 && cycles < quiet_until[(reg - 4) / 2]) access = false;
        if (access && write && (reg == 5 || reg == 7)) quiet_until[(reg - 4) / 2] = cycles + 3;
        if (write && (reg == 14 || reg == 15)) data &= 0x7f;
        // TOD pin: a square wave with a random period exercises the divider.
        static unsigned tod_left = 0; static int tod_level = 0;
        if (tod_left == 0) { tod_level = !tod_level; tod_left = 1 + next(40); }
        tod_left--;
        dut.tod_i = tod_level;
        dut.cs_n = !access; dut.rw = !write; dut.addr = reg; dut.data_i = data;
        // Board pull-ups resolve undriven pins high.
        dut.eval();
        dut.pa_i = dut.pa_o | uint8_t(~dut.pa_oe);
        dut.pb_i = dut.pb_o | uint8_t(~dut.pb_oe);
        dut.clk = 1; dut.eval();
        const unsigned high_data = dut.data_o;
        if (access && write) std::snprintf(history[hist_pos++ % 64], 64, "%llu W%x=%02x", (unsigned long long)cycles, reg, data);
        else if (access && reg == 13) std::snprintf(history[hist_pos++ % 64], 64, "%llu R%x", (unsigned long long)cycles, reg);
        unsigned want = 0;
        cia_tod(tod_level);
        if (order == 1) cia_clock();
        if (access) { if (write) cia_write(reg, data); else want = cia_read(reg); }
        if (order == 0) cia_clock();
        if (access && !write) {
            reads++;
            if (dut.data_o != want) {
                if (mism == unsigned(std::getenv("SHOW") ? std::atoi(std::getenv("SHOW")) : 0))
                    for (unsigned h = hist_pos > 24 ? hist_pos - 24 : 0; h < hist_pos; h++)
                        std::printf("  %s\n", history[h % 64]);
                if (mism < 20) std::printf("cycle %llu reg %u rtl %02x mame %02x\n",
                    (unsigned long long)cycles, reg, dut.data_o, want);
                mism++;
            }
        }
        dut.clk = 0; dut.eval();
        if (vectors && records < record_limit) {
            std::fprintf(vectors, "%x %x %x %x %x %x %x %x %x\n", unsigned(!dut.cs_n), unsigned(dut.rw),
                         unsigned(dut.addr), unsigned(dut.data_i), unsigned(dut.pa_i), unsigned(dut.pb_i),
                         unsigned(dut.tod_i), high_data, unsigned(dut.irq_n));
            records++;
        }
        if (const char *from = std::getenv("TRACE_FROM")) {
            const uint64_t start = std::strtoull(from, nullptr, 10);
            if (cycles >= start && cycles < start + 60)
                std::printf("T %llu rtl irq %d ta %04x tb %04x / mame ta %04x tb %04x icr %02x imr %02x cra %02x crb %02x irq %d\n",
                            (unsigned long long)cycles, !dut.irq_n, unsigned(dut.rootp->mos_8520__DOT__ta_read_count), unsigned(dut.rootp->mos_8520__DOT__tb_read_count), cia_ta(), cia_tb(), cia_icr(),
                            cia_imr(), cia_cra(), cia_crb(), cia_irq());
        }
        {
            static uint64_t tod_mism;
            const unsigned rtl_tod = dut.rootp->mos_8520__DOT__tod_clock__DOT__time_q;
            if (rtl_tod != cia_tod_value()) {
                if (tod_mism++ < 10)
                    std::printf("cycle %llu tod rtl %06x mame %06x\n", (unsigned long long)cycles,
                                rtl_tod, cia_tod_value());
                mism++;
            }
        }
        if (!dut.irq_n != cia_irq()) {
            irq_mism++;
            if (mism == 0)
                for (unsigned h = hist_pos > 24 ? hist_pos - 24 : 0; h < hist_pos; h++)
                    std::printf("  %s\n", history[h % 64]);
            if (mism < 20)
                std::printf("cycle %llu irq rtl %d mame %d\n", (unsigned long long)cycles, !dut.irq_n, cia_irq());
            mism++;
        }
    }
    if (vectors) std::fclose(vectors);
    std::printf("MOS 8520 COMPARISON: order %d, %llu cycles, %llu reads, %llu mismatches "
                "(%llu IRQ cycles), %llu replay records\n", order, (unsigned long long)cycles,
                (unsigned long long)reads, (unsigned long long)mism, (unsigned long long)irq_mism,
                (unsigned long long)records);
}
