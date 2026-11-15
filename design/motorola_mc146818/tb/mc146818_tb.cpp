// Lockstep trace bench for motorola_mc146818 (pin level).
//
// usage: mc146818_tb SCRIPT TRACE_OUT
//
// Runs SCRIPT on the RTL and writes a trace in the same format as
// scripts/mc146818_model.py; run_sim.sh compares the two traces line by
// line. Expectations in the script (R/RD/I71 expected values, Q, M) are
// checked by the model against the data sheet; the bench only records.
//
// SCRIPT lines (hex unless noted; '#' starts a comment):
//   W aa dd      bus write cycle: AS with AD=aa, then DS with R/W low and AD=dd
//   WN aa dd     the same cycle with CE high (must have no effect)
//   R aa [ee]    bus read cycle: AS with AD=aa, then DS with R/W high
//   RN aa        read cycle with CE high (bus must stay undriven)
//   A aa         address strobe only;  O70 vv: board port 70h write (AD = vv & 3Fh)
//   RD [ee]      data-strobe read at the latched address;  I71 [ee]: port 71h read
//   WD dd        data-strobe write at the latched address; O71 dd: port 71h write
//   POLL aa mask val maxreads ticks   read aa until (v & mask) == val
//   T n          n oscillator ticks (decimal)
//   RST l        RESET pin level (0/1);  PS l: PS pin level
//   Q irq [sqw]  expected IRQ pin (0 = low) and SQW (model check only)
//   M aa ee      expected location value (model check only)
//   DUMP         record all 64 locations through the debug port
//
// Trace: "R aa vv|Z" per read, "C tick irq sqw" whenever IRQ/SQW change
// during ticks, "S tick irq sqw" after every command, "M ..." per DUMP.
//
// Bus cycle (Motorola mode, one line per clk; tick_i = 0 throughout):
//   CE low, AS high, AD = address | AS low (address latched) |
//   DS high, R/W, AD = data (x2, read data sampled) | DS low (write or read
//   side effect) | idle with CE high.
#include "Vmotorola_mc146818.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static Vmotorola_mc146818 *top;
static FILE *out;
static long ticks = 0;
static int last_irq = -1, last_sqw = -1;

static void clk() {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
}

static void idle_pins() {
    top->ce_n_i = 1;
    top->as_i = 0;
    top->ds_i = 0;
    top->rw_i = 1;
    top->ad_i = 0;
    top->tick_i = 0;
}

static void addr_strobe(unsigned a, bool ce) {
    top->ce_n_i = ce ? 0 : 1;
    top->as_i = 1;
    top->ad_i = a;
    clk();
    top->as_i = 0;
    clk();
}

// Returns -1 when the bus is not driven.
static int data_read(bool ce) {
    top->ce_n_i = ce ? 0 : 1;
    top->rw_i = 1;
    top->ad_i = 0xFF;
    top->ds_i = 1;
    clk();
    top->eval();
    int v = top->ad_oe_o ? (int)top->ad_o : -1;
    clk();
    top->eval();
    if ((top->ad_oe_o ? (int)top->ad_o : -1) != v) {
        fprintf(stderr, "read data changed while DS high\n");
        exit(2);
    }
    top->ds_i = 0;
    clk();
    idle_pins();
    clk();
    return v;
}

static void data_write(unsigned d, bool ce) {
    top->ce_n_i = ce ? 0 : 1;
    top->rw_i = 0;
    top->ad_i = d;
    top->ds_i = 1;
    clk();
    clk();
    top->ds_i = 0;
    clk();
    idle_pins();
    clk();
}

static void rec_read(unsigned a, int v) {
    if (v < 0) fprintf(out, "R %02X Z\n", a);
    else fprintf(out, "R %02X %02X\n", a, v);
}

static void state(char kind) {
    top->eval();
    int irq = top->irq_n_o, sqw = top->sqw_o;
    if (kind == 'C') {
        if (irq != last_irq || sqw != last_sqw)
            fprintf(out, "C %ld %d %d\n", ticks, irq, sqw);
    } else {
        fprintf(out, "S %ld %d %d\n", ticks, irq, sqw);
    }
    last_irq = irq;
    last_sqw = sqw;
}

static void tick() {
    top->tick_i = 1;
    clk();
    top->tick_i = 0;
    ticks++;
    state('C');
}

static unsigned latched = 0;   // for trace of RD/I71 (address last strobed)

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 3) {
        fprintf(stderr, "usage: %s SCRIPT TRACE\n", argv[0]);
        return 2;
    }
    std::ifstream in(argv[1]);
    if (!in) { fprintf(stderr, "cannot open %s\n", argv[1]); return 2; }
    out = fopen(argv[2], "w");
    top = new Vmotorola_mc146818;
    idle_pins();
    top->reset_n_i = 1;
    top->ps_i = 1;
    top->dbg_addr_i = 0;
    top->rst_n = 0;
    clk();
    clk();
    top->rst_n = 1;
    clk();

    std::string line;
    while (std::getline(in, line)) {
        size_t h = line.find('#');
        if (h != std::string::npos) line.resize(h);
        std::istringstream ss(line);
        std::string op;
        if (!(ss >> op)) continue;
        for (auto &c : op) c = toupper(c);
        std::vector<std::string> a;
        std::string t;
        while (ss >> t) a.push_back(t);
        auto hx = [&](size_t i) { return (unsigned)strtoul(a.at(i).c_str(), nullptr, 16); };
        if (op == "W" || op == "WN") {
            bool ce = op == "W";
            addr_strobe(hx(0), ce);
            if (ce && top->reset_n_i) latched = hx(0) & 0x3F;
            data_write(hx(1), ce);
        } else if (op == "R" || op == "RN") {
            bool ce = op == "R";
            addr_strobe(hx(0), ce);
            if (ce && top->reset_n_i) latched = hx(0) & 0x3F;
            rec_read(hx(0), data_read(ce));
        } else if (op == "A" || op == "O70") {
            unsigned v = hx(0);
            if (op == "O70") v &= 0x3F;   // bit 7 = NMI mask, bit 6 unused on the AT board
            addr_strobe(v, true);
            if (top->reset_n_i) latched = v & 0x3F;
        } else if (op == "RD" || op == "I71") {
            rec_read(latched, data_read(true));
        } else if (op == "WD" || op == "O71") {
            data_write(hx(0), true);
        } else if (op == "POLL") {
            unsigned ad = hx(0), mask = hx(1), val = hx(2);
            int mx = atoi(a.at(3).c_str()), tb = atoi(a.at(4).c_str());
            for (int i = 0; i < mx; i++) {
                addr_strobe(ad, true);
                latched = ad & 0x3F;
                int v = data_read(true);
                rec_read(ad, v);
                if (v >= 0 && ((unsigned)v & mask) == val) break;
                for (int k = 0; k < tb; k++) tick();
            }
        } else if (op == "T") {
            long n = atol(a.at(0).c_str());
            for (long i = 0; i < n; i++) tick();
        } else if (op == "RST") {
            top->reset_n_i = atoi(a.at(0).c_str()) ? 1 : 0;
            clk();
        } else if (op == "PS") {
            top->ps_i = atoi(a.at(0).c_str()) ? 1 : 0;
            clk();
        } else if (op == "Q" || op == "M") {
            // checked by the model
        } else if (op == "DUMP") {
            fprintf(out, "M");
            for (unsigned i = 0; i < 64; i++) {
                top->dbg_addr_i = i;
                top->eval();
                fprintf(out, " %02X", top->dbg_data_o);
            }
            fprintf(out, "\n");
        } else {
            fprintf(stderr, "unknown op %s\n", op.c_str());
            return 2;
        }
        state('S');
    }
    fclose(out);
    top->final();
    delete top;
    return 0;
}
