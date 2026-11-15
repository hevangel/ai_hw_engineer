// Lockstep trace bench for ibm_ega (slot and monitor pins).
//
// usage: ega_tb SCRIPT TRACE_OUT
//
// Runs SCRIPT on the RTL and writes a trace in the same format as
// scripts/ega_model.py; run_sim.sh compares the two traces line by line.
// Expectations in the script (OR/MR values, X... commands) are checked by
// the model against the hand-derived values; the bench only records.
//
// SCRIPT lines (hex unless noted; '#' starts a comment):
//   OW aaaa dd      I/O write cycle            OWN: the same with AEN high
//   OR aaaa [ee|Z]  I/O read cycle             ORN: the same with AEN high
//   MW aaaaa dd     memory write cycle
//   MR aaaaa [ee|Z] memory read cycle
//   T n             n clocks with both oscillator enables pulsing (decimal)
//   RST l           RESET DRV level            SW v: switches (sw_i)
//   P1 l / P3 l     jumpers                    FEAT v: feature inputs
//   LP l / LPSW l   -LPEN IN / -LPEN SW pins   DACK l: -DACK0 level
//   DUMPR           all debug registers        DUMPM p aaaa n: plane bytes
//   XREG/XMEM/XDOTS/XPIX/XIRQ  model-only expectations (ignored here)
//
// Trace: "T n dots" + run-length "V count value" lines per T (value =
// video | hsync<<6 | vsync<<7 | blank<<8 | de<<9 | video_oe<<10, one per
// pix_en_o pulse); "R addr vv|Z" per read; "I irq oe" when IRQ 2 changes;
// "D ..." / "M ..." for dumps.
//
// Bus cycle (one line per clk, oscillators idle): address/data/AEN set
// and strobe low for 3 clocks (read data sampled after the third), strobe
// high, 2 idle clocks.
#include "Vibm_ega.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static Vibm_ega *top;
static FILE *out;
static std::vector<std::pair<long, unsigned>> runs;
static long dots = 0;

static void record() {
    if (!top->pix_en_o) return;
    unsigned v = top->video_o | (top->hsync_o << 6) | (top->vsync_o << 7) |
                 (top->blank_o << 8) | (top->de_o << 9) | (top->video_oe_o << 10);
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
    top->osc14_ce_i = 0; top->osc16_ce_i = 0; top->ext_osc_ce_i = 0;
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

static const int DBG[] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b,
    0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
    0x28, 0x29, 0x2a, 0x2b,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b,
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b,
    0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 3) {
        fprintf(stderr, "usage: ega_tb SCRIPT TRACE\n");
        return 2;
    }
    top = new Vibm_ega;
    out = fopen(argv[2], "w");
    std::ifstream in(argv[1]);
    idle();
    top->reset_drv_i = 0; top->dack0_n_i = 1;
    top->sw_i = 0xF; top->p1_i = 1; top->p3_i = 1; top->feat_i = 0;
    top->lpen_n_i = 1; top->lpen_sw_n_i = 1;
    top->dbg_reg_addr_i = 0; top->dbg_plane_i = 0; top->dbg_mem_addr_i = 0;
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
            for (long i = 0; i < n; i++) {
                top->osc14_ce_i = 1; top->osc16_ce_i = 1;
                clk();
            }
            top->osc14_ce_i = 0; top->osc16_ce_i = 0;
            for (int i = 0; i < 6; i++) clk();
            fprintf(out, "T %ld %ld\n", n, dots);
            for (auto &r : runs) fprintf(out, "V %ld %03x\n", r.first, r.second);
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
        } else if (op == "SW") {
            top->sw_i = hx(0) & 15; clk(); clk(); clk();
        } else if (op == "P1") {
            top->p1_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "P3") {
            top->p3_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "FEAT") {
            top->feat_i = hx(0) & 3; clk(); clk(); clk();
        } else if (op == "LP") {
            top->lpen_n_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "LPSW") {
            top->lpen_sw_n_i = hx(0) & 1; clk(); clk(); clk();
        } else if (op == "DACK") {
            top->dack0_n_i = hx(0) & 1; clk(); clk(); clk();
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
        } else if (op[0] == 'X') {
            // model-only expectation
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
