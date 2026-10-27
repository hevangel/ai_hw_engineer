// Replays independent SingleStepTests spc700 records through sony_spc700:
// every cycle's kind (read / write / internal), address and data, and the
// exact final registers and memory must match. Reads recorded without a
// value (dummy reads) compare the address only. Expected values are never
// edited.
#include "Vsony_spc700.h"
#include "Vsony_spc700___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

struct State { unsigned pc, a, x, y, sp, psw; };
struct Cycle { int address, value; unsigned kind; };
using Memory = std::vector<std::pair<unsigned, unsigned>>;

static State state_from(std::istream& in) {
    State s{};
    in >> s.pc >> s.a >> s.x >> s.y >> s.sp >> s.psw;
    if (!in) throw std::runtime_error("invalid external state");
    return s;
}
static Memory memory_from(std::istream& in) {
    unsigned n;
    in >> n;
    Memory m;
    for (unsigned i = 0; i < n; ++i) {
        unsigned a, v;
        in >> a >> v;
        if (!in || a > 0xffff || v > 255) throw std::runtime_error("invalid external memory");
        m.emplace_back(a, v);
    }
    return m;
}

int main(int argc, char** argv) {
    if (argc < 2) { std::cerr << "usage: cpu_vector_test vectors.txt [max_failures]\n"; return 2; }
    Verilated::commandArgs(argc, argv);
    const unsigned max_fail = argc > 2 ? std::atoi(argv[2]) : 1;
    std::ifstream in(argv[1]);
    unsigned cases;
    in >> cases;
    if (!in || cases == 0) throw std::runtime_error("empty/missing external vectors");
    Vsony_spc700 dut;
    auto* r = dut.rootp;
    std::array<std::uint8_t, 65536> ram{};
    std::uint64_t checks = 0;
    std::map<unsigned, unsigned> fails;
    unsigned failures = 0;
    std::array<unsigned, 256> per{};
    for (unsigned t = 0; t < cases; ++t) {
        unsigned opcode, index, n;
        in >> opcode >> index;
        const State ini = state_from(in);
        const Memory ini_mem = memory_from(in);
        const State fin = state_from(in);
        const Memory fin_mem = memory_from(in);
        in >> n;
        std::vector<Cycle> cyc(n);
        for (auto& c : cyc) in >> c.address >> c.value >> c.kind;
        if (!in) throw std::runtime_error("truncated external vectors");
        ram.fill(0);
        for (auto& [a, v] : ini_mem) ram[a] = v;
        dut.ce = 1;
        dut.clk = 0; dut.rst_n = 0; dut.eval();
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.rst_n = 1; dut.eval();
        // Verification-only state injection through public-flat access.
        r->sony_spc700__DOT__resetting = 0;
        r->sony_spc700__DOT__step = 0;
        r->sony_spc700__DOT__pc = ini.pc;
        r->sony_spc700__DOT__a = ini.a;
        r->sony_spc700__DOT__x = ini.x;
        r->sony_spc700__DOT__y = ini.y;
        r->sony_spc700__DOT__sp = ini.sp;
        r->sony_spc700__DOT__psw = ini.psw;
        dut.eval();
        std::string why;
        for (unsigned i = 0; i < n && why.empty(); ++i) {
            dut.data_i = ram[dut.addr_o];
            dut.eval();
            const auto& w = cyc[i];
            const unsigned kind = dut.we_o ? 1 : (dut.rd_o ? 0 : 2);
            const unsigned value = dut.we_o ? dut.data_o : dut.data_i;
            bool ok = kind == w.kind;
            if (ok && kind != 2) ok = int(dut.addr_o) == w.address && (w.value < 0 || unsigned(w.value) == value);
            if (!ok) {
                char buf[160];
                std::snprintf(buf, sizeof buf, "cycle %u: got kind %u %04x %02x, want kind %u %04x %d",
                              i, kind, unsigned(dut.addr_o), value, w.kind, w.address, w.value);
                why = buf;
            }
            if (dut.we_o) ram[dut.addr_o] = dut.data_o;
            dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval();
            ++checks;
        }
        const bool halt = opcode == 0xef || opcode == 0xff;
        if (why.empty()) {
            if (dut.pc_o != fin.pc || dut.a_o != fin.a || dut.x_o != fin.x || dut.y_o != fin.y ||
                dut.sp_o != fin.sp || dut.psw_o != fin.psw || (halt ? !dut.halted_o : !dut.fetch_o)) {
                char buf[200];
                std::snprintf(buf, sizeof buf,
                    "final: got pc=%04x a=%02x x=%02x y=%02x sp=%02x psw=%02x; want pc=%04x a=%02x x=%02x y=%02x sp=%02x psw=%02x",
                    dut.pc_o, dut.a_o, dut.x_o, dut.y_o, dut.sp_o, dut.psw_o, fin.pc, fin.a, fin.x, fin.y, fin.sp, fin.psw);
                why = buf;
            }
            for (auto& [a, v] : fin_mem)
                if (why.empty() && ram[a] != v) {
                    char buf[80];
                    std::snprintf(buf, sizeof buf, "final memory %04x = %02x, want %02x", a, ram[a], v);
                    why = buf;
                }
        }
        if (!why.empty()) {
            if (fails[opcode]++ == 0 && fails.size() <= max_fail)
                std::fprintf(stderr, "MISMATCH %02x case %u %s\n", opcode, index, why.c_str());
            ++failures;
        } else {
            per[opcode]++;
        }
    }
    if (failures) {
        std::cerr << "failing opcodes:";
        for (auto& [o, c] : fails) { char b[16]; std::snprintf(b, sizeof b, " %02x(%u)", o, c); std::cerr << b; }
        std::cerr << "\nSONY SPC700 CPU VECTOR FAIL: " << failures << " of " << cases << " cases\n";
        return 1;
    }
    unsigned covered = 0;
    for (unsigned c : per) covered += c != 0;
    std::cout << "SONY SPC700 CPU VECTOR PASS: cases=" << cases << " opcodes=" << covered
              << " bus_cycles=" << checks << "\n";
}
