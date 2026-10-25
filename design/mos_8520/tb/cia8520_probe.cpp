// Directed probe: per-cycle timer A low-byte reads after a one-shot-start
// high write, printed for mos_8520 and MAME's 8520 side by side.
#include "Vmos_8520.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" {
void cia_init(int);
void cia_clock(void);
unsigned cia_read(unsigned);
void cia_write(unsigned, unsigned);
unsigned cia_ta(void);
unsigned cia_cra(void);
}

static Vmos_8520 dut;

static unsigned cycle(bool access, bool write, unsigned reg, unsigned data, unsigned *mame) {
    dut.cs_n = !access; dut.rw = !write; dut.addr = reg; dut.data_i = data;
    dut.eval();
    dut.pa_i = dut.pa_o | uint8_t(~dut.pa_oe);
    dut.pb_i = dut.pb_o | uint8_t(~dut.pb_oe);
    dut.clk = 1; dut.eval();
    unsigned want = 0;
    if (access) { if (write) cia_write(reg, data); else want = cia_read(reg); }
    cia_clock();
    const unsigned got = dut.data_o;
    dut.clk = 0; dut.eval();
    *mame = want;
    return got;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    const unsigned cra = argc > 1 ? unsigned(std::strtoul(argv[1], nullptr, 16)) : 0x08;
    dut.cs_n = 1; dut.rw = 1; dut.cnt_i = 1; dut.sp_i = 1; dut.flag_n_i = 1; dut.tod_i = 0;
    dut.rst_n = 0;
    for (int i = 0; i < 4; i++) { dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval(); }
    dut.rst_n = 1;
    cia_init(2);
    unsigned m;
    cycle(true, true, 14, cra, &m);
    cycle(true, true, 4, 0x10, &m);
    for (int i = 0; i < 3; i++) cycle(false, false, 0, 0, &m);
    cycle(true, true, 5, 0x00, &m);
    for (int i = 0; i < 24; i++) {
        const unsigned r = cycle(true, false, 4, 0, &m);
        std::printf("+%d rtl %02x mame %02x (mame cra %02x)\n", i + 1, r, m, cia_cra());
    }
}
