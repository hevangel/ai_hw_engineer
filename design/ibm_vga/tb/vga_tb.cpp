// Lockstep trace bench for ibm_vga (slot and display pins), the partner of
// scripts/vga_model.py; copied from design/ibm_ega/tb/ega_tb.cpp.
//
// usage: vga_tb SCRIPT TRACE_OUT
//
// Runs SCRIPT on the RTL and writes a trace in the same format as the
// model; run_sim.sh compares the two traces line by line. Expectations in
// the script (OR/MR values, X... commands) are checked by the model; the
// bench records the RTL's observed values at the same points.
//
// SCRIPT lines (hex unless noted; '#' starts a comment):
//   OW aaaa dd      I/O write cycle            OWN: the same with AEN high
//   OR aaaa [ee|Z]  I/O read cycle             ORN: the same with AEN high
//   MW aaaaa dd     memory write cycle
//   MR aaaaa [ee|Z] memory read cycle
//   T n             n master pulses (decimal): by default n clocks with both
//                   oscillator enables pulsing; with VGA_CLK_MHZ set, clk
//                   runs at that rate and each oscillator enable comes from
//                   a phase accumulator (25.175 / 28.322 MHz), so enables
//                   are irregular and never more than one per clock; the T
//                   command then runs until the selected oscillator (Misc
//                   Output bits 3-2, read through the debug port) has
//                   pulsed n times
//   RST l           RESET DRV level            DACK l: -DACK0 level
//   LOAD v          monitor load load_i (3 bits)
//   DUMPR           all debug registers        DUMPM p aaaa n: plane bytes
//   DUMPDAC         all 256 DAC entries
//   XREG aa ee / XMEM p aaaa ee / XDAC aa eeeee  record "Q ..." lines (the
//                   model checks ee); XDOTS/XPIX/XIRQ: model-only
//
// Trace: "T n dots" + run-length "V count value" lines per T (value = r |
// g<<6 | b<<12 | hsync<<18 | vsync<<19 | blank<<20 | de<<21, one per
// pix_en_o pulse); "R addr vv|Z" per read; "I irq oe" when IRQ 2 changes;
// "D", "M", "C" lines for dumps.
//
// Bus cycle (one line per clk, oscillators idle): address/data/AEN set and
// strobe low for 3 clocks (read data sampled after the third), strobe high,
// 2 idle clocks.
#include "Vibm_vga.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static Vibm_vga *top;
static FILE *out;
static std::vector<std::pair<long, unsigned>> runs;
static long dots = 0;
static double clk_mhz = 0.0, acc25 = 0.0, acc28 = 0.0;

static void record() {
    if (!top->pix_en_o) return;
    unsigned v = top->r_o | (top->g_o << 6) | (top->b_o << 12) | (top->hsync_o << 18) |
                 (top->vsync_o << 19) | (top->blank_o << 20) | (top->de_o << 21);
    dots++;
    if (!runs.empty() && runs.back().second == v) runs.back().first++;
    else runs.push_back({1, v});
}

static void clk() {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
    record();
}

static void idle() {
    top->ior_n_i = 1; top->iow_n_i = 1; top->memr_n_i = 1; top->memw_n_i = 1;
    top->aen_i = 0;
    top->osc25_ce_i = 0; top->osc28_ce_i = 0; top->ext_osc_ce_i = 0;
}

static void write_cycle(unsigned a, unsigned d, bool io, bool aen) {
    top->a_i = a; top->d_i = d; top->aen_i = aen;
    if (io) top->iow_n_i = 0; else top->memw_n_i = 0;
    clk(); clk(); clk();
    top->iow_n_i = 1; top->memw_n_i = 1;
    clk(); clk();
    top->aen_i = 0;
    clk();
}

static int read_cycle(unsigned a, bool io, bool aen) {
    top->a_i = a; top->aen_i = aen;
    if (io) top->ior_n_i = 0; else top->memr_n_i = 0;
    clk(); clk(); clk();
    top->eval();
    int v = top->d_oe_o ? (int)top->d_o : -1;
    top->ior_n_i = 1; top->memr_n_i = 1;
    clk(); clk();
    top->aen_i = 0;
    clk();
    return v;
}

// must equal scripts/vga_model.py DBG_REGS
static std::vector<int> dbg_list() {
    std::vector<int> v;
    for (int a = 0x00; a < 0x06; a++) v.push_back(a);
    for (int a = 0x10; a < 0x2A; a++) v.push_back(a);
    for (int a = 0x30; a < 0x3A; a++) v.push_back(a);
    for (int a = 0x40; a < 0x57; a++) v.push_back(a);
    for (int a = 0x60; a < 0x66; a++) v.push_back(a);
    v.push_back(0x67); v.push_back(0x68); v.push_back(0x69); v.push_back(0x6A);
    for (int a = 0x70; a < 0x77; a++) v.push_back(a);
    return v;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 3) {
        fprintf(stderr, "usage: vga_tb SCRIPT TRACE\n");
        return 2;
    }
    top = new Vibm_vga;
    out = fopen(argv[2], "w");
    std::ifstream in(argv[1]);
    const std::vector<int> DBG = dbg_list();
    const char *cm = getenv("VGA_CLK_MHZ");
    clk_mhz = cm ? atof(cm) : 0.0;
    if (clk_mhz > 0 && clk_mhz < 28.322) {
        fprintf(stderr, "VGA_CLK_MHZ %.3f is below the fastest oscillator (28.322 MHz)
", clk_mhz);
        return 2;
    }
    idle();
    top->reset_drv_i = 0; top->dack0_n_i = 1; top->load_i = 7;
    top->dbg_reg_addr_i = 0; top->dbg_plane_i = 0; top->dbg_mem_addr_i = 0; top->dbg_dac_i = 0;
    top->rst_n = 0;
    for (int i = 0; i < 4; i++) clk();
    top->rst_n = 1;
    clk(); clk();
    dots = 0; runs.clear();

    int last_irq = -1, last_oe = -1;
    std::string line;
    while (std::getline(in, line)) {
        size_t h = line.find('#');
        if (h != std::string::npos) line = line.substr(0, h);
        std::istringstream ss(line);
        std::string op;
        if (!(ss >> op)) continue;
        std::vector<std::string> t;
        std::string w;
        while (ss >> w) t.push_back(w);
        auto hx = [&](size_t i) { return (unsigned)strtoul(t.at(i).c_str(), nullptr, 16); };
        if (op == "T") {
            long n = strtol(t.at(0).c_str(), nullptr, 10);
            dots = 0; runs.clear();
            if (clk_mhz > 0) {
                top->dbg_reg_addr_i = 0x60;
                top->eval();
                int cs = (top->dbg_reg_data_o >> 2) & 3;
                long got = 0;
                while (got < n) {
                    acc25 += 25.175; acc28 += 28.322;
                    bool e25 = acc25 >= clk_mhz, e28 = acc28 >= clk_mhz;
                    if (e25) acc25 -= clk_mhz;
                    if (e28) acc28 -= clk_mhz;
                    top->osc25_ce_i = e25; top->osc28_ce_i = e28;
                    clk();
                    if (cs == 0 ? e25 : cs == 1 ? e28 : true) got++;
                }
            } else {
                for (long i = 0; i < n; i++) {
                    top->osc25_ce_i = 1; top->osc28_ce_i = 1;
                    clk();
                }
            }
            top->osc25_ce_i = 0; top->osc28_ce_i = 0;
            for (int i = 0; i < 6; i++) clk();
            fprintf(out, "T %ld %ld\n", n, dots);
            for (auto &r : runs) fprintf(out, "V %ld %06x\n", r.first, r.second);
            runs.clear();
        } else if (op == "OW" || op == "OWN") {
            write_cycle(hx(0), hx(1), true, op == "OWN");
        } else if (op == "MW") {
            write_cycle(hx(0), hx(1), false, false);
        } else if (op == "OR" || op == "ORN" || op == "MR") {
            bool io = op != "MR";
            int v = read_cycle(hx(0), io, op == "ORN");
            if (v < 0) fprintf(out, io ? "R %04x Z\n" : "R %05x Z\n", hx(0));
            else fprintf(out, io ? "R %04x %02x\n" : "R %05x %02x\n", hx(0), v);
        } else if (op == "RST") {
            top->reset_drv_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "DACK") {
            top->dack0_n_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "LOAD") {
            top->load_i = hx(0) & 7; clk(); clk(); clk();
        } else if (op == "DUMPR") {
            fprintf(out, "D");
            for (int a : DBG) {
                top->dbg_reg_addr_i = a;
                top->eval();
                fprintf(out, " %02x", top->dbg_reg_data_o);
            }
            fprintf(out, "\n");
        } else if (op == "DUMPM") {
            unsigned p = hx(0), a0 = hx(1), n = hx(2);
            fprintf(out, "M %u %04x ", p, a0);
            top->dbg_plane_i = p;
            for (unsigned i = 0; i < n; i++) {
                top->dbg_mem_addr_i = (a0 + i) & 0xFFFF;
                top->eval();
                fprintf(out, "%02x", top->dbg_mem_data_o);
            }
            fprintf(out, "\n");
        } else if (op == "DUMPDAC") {
            fprintf(out, "C");
            for (int a = 0; a < 256; a++) {
                top->dbg_dac_i = a;
                top->eval();
                fprintf(out, " %05x", top->dbg_dac_o);
            }
            fprintf(out, "\n");
        } else if (op == "XREG") {
            top->dbg_reg_addr_i = hx(0);
            top->eval();
            fprintf(out, "Q R %02x %02x\n", hx(0), top->dbg_reg_data_o);
        } else if (op == "XMEM") {
            top->dbg_plane_i = hx(0);
            top->dbg_mem_addr_i = hx(1);
            top->eval();
            fprintf(out, "Q M %u %04x %02x\n", hx(0), hx(1), top->dbg_mem_data_o);
        } else if (op == "XDAC") {
            top->dbg_dac_i = hx(0);
            top->eval();
            fprintf(out, "Q C %02x %05x\n", hx(0), top->dbg_dac_o);
        } else if (op[0] == 'X') {
            // model-only expectation (the dot stream and I lines carry it)
        } else {
            fprintf(stderr, "unknown command %s\n", op.c_str());
            return 2;
        }
        if (top->irq2_o != last_irq || top->irq2_oe_o != last_oe) {
            last_irq = top->irq2_o;
            last_oe = top->irq2_oe_o;
            fprintf(out, "I %d %d\n", last_irq, last_oe);
        }
    }
    fclose(out);
    top->final();
    delete top;
    return 0;
}
