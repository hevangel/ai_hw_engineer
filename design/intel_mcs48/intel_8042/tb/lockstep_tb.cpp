// Lockstep trace bench for upi42_core.
//
// usage: lockstep_tb ROM.bin SCRIPT TRACE_OUT
//
// SCRIPT lines (shared with scripts/upi42_trace.py):
//   run N                     stop after N retires
//   autoread                  at every boundary, read DBBOUT if OBF=1
//   kbdloop                   no keyboard: T0 = NOT P26 and T1 = P27 (the
//                             open-collector CLK/DATA lines read back the
//                             8042's own drive), ANDed with the pins levels
//   N write A0 DATA           host write at the first boundary >= N with IBF=0
//   N fwrite A0 DATA          host write at index N even if IBF=1
//   N read A0                 host read before retire index N executes
//   N pins P1EXT P2EXT T0 T1  external pin levels from index N on
// All values hex except N, A0, T0, T1. Commands at index N are applied when
// N instructions have retired, in file order.
//
// TRACE_OUT: one line per retire and per host read, see emit().
#include "Vupi42_core.h"
#include "Vupi42_core___024root.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

struct Cmd {
    long at;
    std::string op;
    unsigned v[4];
};

static Vupi42_core *top;
static unsigned char rom[2048];
static unsigned p1_ext = 0xFF, p2_ext = 0xFF;
static FILE *out;

static void settle() {
    top->eval();
    top->rom_data_i = rom[top->rom_addr_o & 0x7FF];
    top->p1_i = top->p1_o & p1_ext;
    top->p2_i = top->p2_o & p2_ext;
    top->eval();
}

static void tick_clk() {
    top->clk = 0;
    settle();
    top->clk = 1;
    settle();
}

static void host_write(unsigned a0, unsigned d) {
    top->ce_i = 0;
    top->cs_n_i = 0; top->wr_n_i = 0; top->a0_i = a0; top->d_i = d;
    tick_clk();
    top->cs_n_i = 1; top->wr_n_i = 1;
    tick_clk();
}

static unsigned host_read(unsigned a0) {
    top->ce_i = 0;
    top->cs_n_i = 0; top->rd_n_i = 0; top->a0_i = a0;
    settle();
    unsigned d = top->d_o;
    tick_clk();
    top->cs_n_i = 1; top->rd_n_i = 1;
    tick_clk();
    return d;
}

static void emit(long idx, unsigned cycles) {
    auto *r = top->rootp;
    fprintf(out, "R %ld k%u pc%03X op%02X c%u npc%03X a%02X psw%02X sts%02X t%02X "
                 "dbi%02X dbo%02X p1%02X p2%02X m%04X ill%u ram",
            idx, top->retire_kind_o, top->retire_pc_o, top->retire_op_o, cycles,
            top->pc_o, top->a_o, top->psw_o, top->sts_o, top->t_o,
            top->dbbin_o, top->dbbout_o, top->p1_o, top->p2_o, top->misc_o,
            top->illegal_o);
    for (int i = 0; i < 128; i++)
        fprintf(out, "%02X", r->upi42_core__DOT__ram[i]);
    fputc('\n', out);
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s ROM SCRIPT TRACE\n", argv[0]);
        return 2;
    }
    Verilated::commandArgs(argc, argv);
    FILE *rf = fopen(argv[1], "rb");
    if (!rf || fread(rom, 1, 2048, rf) != 2048) {
        fprintf(stderr, "cannot read 2048-byte ROM %s\n", argv[1]);
        return 2;
    }
    fclose(rf);
    std::vector<Cmd> cmds;
    long limit = 0;
    bool autoread = false;
    bool kbdloop = false;
    unsigned t0_ext = 1, t1_ext = 1;
    std::ifstream sf(argv[2]);
    std::string line;
    while (std::getline(sf, line)) {
        if (line.empty() || line[0] == '#') continue;
        std::istringstream is(line);
        std::string first;
        is >> first;
        if (first == "run") { is >> limit; continue; }
        if (first == "autoread") { autoread = true; continue; }
        if (first == "kbdloop") { kbdloop = true; continue; }
        Cmd c{};
        c.at = std::stol(first);
        is >> c.op;
        for (int i = 0; i < 4; i++) {
            std::string tok;
            if (is >> tok) c.v[i] = (unsigned)std::stoul(tok, nullptr, 16);
        }
        cmds.push_back(c);
    }
    out = fopen(argv[3], "w");
    if (!out) return 2;

    top = new Vupi42_core;
    top->cs_n_i = 1; top->rd_n_i = 1; top->wr_n_i = 1;
    top->t0_i = 1; top->t1_i = 1;
    top->rst_n = 0; top->ce_i = 1;
    for (int i = 0; i < 4; i++) tick_clk();
    top->rst_n = 1;

    size_t ci = 0;
    long retired = 0;
    unsigned cycles = 0;
    long guard = 0;
    while (retired < limit) {
        // Instruction boundary: apply commands for this index.
        while (ci < cmds.size() && cmds[ci].at <= retired) {
            // A host write waits until the input buffer is empty, as the
            // BIOS does before every 8042 write.
            if (cmds[ci].op == "write" && (top->sts_o & 2)) break;
            const Cmd &c = cmds[ci++];
            if (c.op == "write" || c.op == "fwrite") host_write(c.v[0], c.v[1]);
            else if (c.op == "read")
                fprintf(out, "H %ld a%u d%02X\n", retired, c.v[0], host_read(c.v[0]));
            else if (c.op == "pins") {
                p1_ext = c.v[0]; p2_ext = c.v[1];
                t0_ext = c.v[2] & 1; t1_ext = c.v[3] & 1;
            }
        }
        if (kbdloop) {
            top->t0_i = t0_ext & (~top->p2_o >> 6) & 1;
            top->t1_i = t1_ext & (top->p2_o >> 7) & 1;
        } else {
            top->t0_i = t0_ext;
            top->t1_i = t1_ext;
        }
        if (autoread && (top->sts_o & 1))
            fprintf(out, "H %ld a0 d%02X\n", retired, host_read(0));
        // Run machine cycles until the next retire.
        top->ce_i = 1;
        cycles = 0;
        do {
            tick_clk();
            cycles++;
            if (++guard > 100000000L) { fprintf(stderr, "no retire\n"); return 1; }
        } while (!top->retire_o);
        emit(retired, cycles);
        retired++;
    }
    fclose(out);
    delete top;
    return 0;
}
