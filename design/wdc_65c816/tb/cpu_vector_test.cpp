// Replays independent SingleStepTests 65816 records through wdc_65c816:
// every bus cycle (address, direction, data, VDA/VPA/VPB/ML/E/M/X) and the
// exact final registers and memory must match. Expected values are never
// edited; reads recorded as null (no VDA/VPA/VPB) compare the address only.
#include "Vwdc_65c816.h"
#include "Vwdc_65c816___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

struct State { unsigned pc, s, p, a, x, y, dbr, d, pbr, e; };
struct Cycle { int address; int value; unsigned bits; };
using Memory = std::vector<std::pair<unsigned, unsigned>>;

static State state_from(std::istream& in) {
    State st{};
    in >> st.pc >> st.s >> st.p >> st.a >> st.x >> st.y >> st.dbr >> st.d >> st.pbr >> st.e;
    if (!in) throw std::runtime_error("invalid external state");
    return st;
}
static Memory memory_from(std::istream& in) {
    unsigned count;
    in >> count;
    Memory m;
    for (unsigned i = 0; i < count; ++i) {
        unsigned a, v;
        in >> a >> v;
        if (!in || a > 0xffffff || v > 255) throw std::runtime_error("invalid external memory");
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
    Vwdc_65c816 dut;
    auto* r = dut.rootp;
    std::vector<std::uint8_t> ram(1u << 24, 0);
    std::uint64_t bus_checks = 0;
    std::map<std::string, unsigned> fails;
    unsigned failures = 0, passed = 0;
    std::array<unsigned, 512> per{};
    for (unsigned t = 0; t < cases; ++t) {
        unsigned opcode, emu, index, ncyc;
        in >> opcode >> emu >> index;
        const State ini = state_from(in);
        const Memory ini_mem = memory_from(in);
        const State fin = state_from(in);
        const Memory fin_mem = memory_from(in);
        in >> ncyc;
        std::vector<Cycle> cyc(ncyc);
        for (auto& c : cyc) in >> c.address >> c.value >> c.bits;
        if (!in) throw std::runtime_error("truncated external vectors");
        for (auto& [a, v] : ini_mem) ram[a] = v;

        dut.irq_n = 1; dut.nmi_n = 1; dut.ce = 1;
        dut.clk = 0; dut.rst_n = 0; dut.eval();
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.rst_n = 1; dut.eval();
        // Verification-only state injection through public-flat access.
        r->wdc_65c816__DOT__state = 0; // S_FETCH
        r->wdc_65c816__DOT__int_q = 0;
        r->wdc_65c816__DOT__pc = ini.pc;
        r->wdc_65c816__DOT__s = ini.e ? (0x100 | (ini.s & 0xff)) : ini.s;
        r->wdc_65c816__DOT__p = ini.e ? (ini.p | 0x30) : ini.p;
        r->wdc_65c816__DOT__a = ini.a;
        r->wdc_65c816__DOT__x = ini.x;
        r->wdc_65c816__DOT__y = ini.y;
        r->wdc_65c816__DOT__dbr = ini.dbr;
        r->wdc_65c816__DOT__d = ini.d;
        r->wdc_65c816__DOT__pbr = ini.pbr;
        r->wdc_65c816__DOT__e = ini.e;
        dut.eval();
        std::string why;
        unsigned at = 0;
        for (unsigned i = 0; i < ncyc && why.empty(); ++i) {
            dut.data_i = ram[dut.addr_o];
            dut.eval();
            const auto& w = cyc[i];
            const unsigned bits = dut.vda_o | dut.vpa_o << 1 | dut.vpb_o << 2 | (!dut.we_o) << 3 |
                                  dut.e_o << 4 | dut.m_o << 5 | dut.x_o << 6 | dut.ml_o << 7;
            const unsigned value = dut.we_o ? dut.data_o : dut.data_i;
            if (w.address < 0) {          // WAI/STP asleep: no bus cycle
                if (!dut.waiting_o && !dut.stopped_o) { why = "expected WAI/STP halt"; at = i; }
                dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval();
                continue;
            }
            if (int(dut.addr_o) != w.address || bits != w.bits || (w.value >= 0 && unsigned(w.value) != value)) {
                char buf[200];
                std::snprintf(buf, sizeof buf, "cycle %u: got %06x %02x bits %02x, want %06x %d bits %02x",
                              i, unsigned(dut.addr_o), value, bits, w.address, w.value, w.bits);
                why = buf; at = i;
            }
            if (dut.we_o) ram[dut.addr_o] = dut.data_o;
            dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval();
            ++bus_checks;
        }
        if (why.empty()) {
            char buf[300];
            const unsigned got_s = r->wdc_65c816__DOT__s;
            if (dut.pc_o != fin.pc || got_s != fin.s || dut.p_o != fin.p || dut.a_o != fin.a ||
                dut.x_reg_o != fin.x || dut.y_reg_o != fin.y || dut.dbr_o != fin.dbr || dut.d_o != fin.d ||
                dut.pbr_o != fin.pbr || dut.e_o != fin.e ||
                (opcode == 0xcb || opcode == 0xdb ? dut.fetch_o : !dut.fetch_o)) {
                std::snprintf(buf, sizeof buf,
                    "final: got pc=%04x s=%04x p=%02x a=%04x x=%04x y=%04x dbr=%02x d=%04x pbr=%02x e=%u fetch=%u;"
                    " want pc=%04x s=%04x p=%02x a=%04x x=%04x y=%04x dbr=%02x d=%04x pbr=%02x e=%u",
                    dut.pc_o, got_s, dut.p_o, dut.a_o, dut.x_reg_o, dut.y_reg_o, dut.dbr_o, dut.d_o,
                    dut.pbr_o, dut.e_o, dut.fetch_o, fin.pc, fin.s, fin.p, fin.a, fin.x, fin.y, fin.dbr,
                    fin.d, fin.pbr, fin.e);
                why = buf;
            }
            for (auto& [a, v] : fin_mem)
                if (why.empty() && ram[a] != v) {
                    std::snprintf(buf, sizeof buf, "final memory %06x = %02x, want %02x", a, ram[a], v);
                    why = buf;
                }
        }
        for (auto& [a, v] : ini_mem) ram[a] = 0;
        for (auto& [a, v] : fin_mem) ram[a] = 0;
        for (auto& c : cyc) if (c.address >= 0) ram[c.address] = 0;
        char name[16];
        std::snprintf(name, sizeof name, "%02x.%c", opcode, emu ? 'e' : 'n');
        if (!why.empty()) {
            if (fails[name]++ == 0 && failures < max_fail)
                std::cerr << "MISMATCH " << name << " case " << index << " " << why << "\n";
            ++failures;
        } else {
            ++passed;
            per[opcode * 2 + emu]++;
        }
    }
    if (failures) {
        std::cerr << "failing files:";
        for (auto& [n, c] : fails) std::cerr << " " << n << "(" << c << ")";
        std::cerr << "\nWDC 65C816 CPU VECTOR FAIL: " << failures << " of " << cases << " cases\n";
        return 1;
    }
    unsigned covered = 0;
    for (unsigned n : per) covered += n != 0;
    std::cout << "WDC 65C816 CPU VECTOR PASS: cases=" << cases << " opcode_modes=" << covered
              << " bus_cycles=" << bus_checks << "\n";
}
