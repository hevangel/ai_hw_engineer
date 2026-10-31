// Independent SingleStepTests records supply all expected state and bus traffic.
#include "Vmos_6502_native.h"
#include "Vmos_6502_native___024root.h"
#include "verilated.h"
#include <array>
#include <bitset>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

struct State { unsigned pc, a, x, y, s, p; };
struct Cycle { unsigned address, value, write; };
using Memory = std::vector<std::pair<unsigned, unsigned>>;

static State state_from(std::istream& input) {
    State state{};
    input >> state.pc >> state.a >> state.x >> state.y >> state.s >> state.p;
    if (!input || state.pc > 65535 || state.a > 255 || state.x > 255 ||
        state.y > 255 || state.s > 255 || state.p > 255) throw std::runtime_error("invalid external state");
    return state;
}
static Memory memory_from(std::istream& input) {
    unsigned count;
    input >> count;
    if (!input || count > 65536) throw std::runtime_error("invalid memory count");
    Memory memory;
    for (unsigned i = 0; i < count; ++i) {
        unsigned address, value;
        input >> address >> value;
        if (!input || address > 65535 || value > 255) throw std::runtime_error("invalid external memory");
        memory.emplace_back(address, value);
    }
    return memory;
}
int main(int argc, char** argv) {
    if (argc != 2) { std::cerr << "usage: native_bus_test vectors.txt\n"; return 2; }
    Verilated::commandArgs(argc, argv);
    std::ifstream input(argv[1]);
    unsigned cases;
    input >> cases;
    if (!input || cases == 0) throw std::runtime_error("empty/missing external vectors");
    Vmos_6502_native dut;
    std::uint64_t bus_checks = 0;
    for (unsigned test = 0; test < cases; ++test) {
        unsigned opcode, index, cycle_count;
        input >> opcode >> index;
        const State initial = state_from(input);
        const Memory initial_memory = memory_from(input);
        const State expected = state_from(input);
        const Memory expected_memory = memory_from(input);
        input >> cycle_count;
        if (!input || cycle_count == 0 || cycle_count > 16) throw std::runtime_error("invalid cycle count");
        std::vector<Cycle> cycles;
        for (unsigned i = 0; i < cycle_count; ++i) {
            Cycle cycle{};
            input >> cycle.address >> cycle.value >> cycle.write;
            if (!input || cycle.address > 65535 || cycle.value > 255 || cycle.write > 1)
                throw std::runtime_error("invalid external cycle");
            cycles.push_back(cycle);
        }
        std::array<std::uint8_t, 65536> ram{};
        std::bitset<65536> allowed;
        for (const auto& [address, value] : initial_memory) { ram[address] = value; allowed.set(address); }
        for (const auto& [address, value] : expected_memory) { (void)value; allowed.set(address); }
        auto fail = [&](const std::string& why, unsigned cycle) {
            std::cerr << std::hex << "Native mismatch op=" << opcode << " case=" << index
                      << " cycle=" << cycle << " " << why << " addr=" << dut.bus_addr
                      << " PC=" << dut.pc_o << " A=" << unsigned(dut.a_o)
                      << " X=" << unsigned(dut.x_o) << " Y=" << unsigned(dut.y_o)
                      << " S=" << unsigned(dut.s_o) << " P=" << unsigned(dut.status_o)
                      << " expected PC=" << expected.pc << " A=" << expected.a
                      << " X=" << expected.x << " Y=" << expected.y
                      << " S=" << expected.s << " P=" << expected.p << std::dec << "\n";
        };
        dut.rdy_i = 1; dut.irq_n = 1; dut.nmi_n = 1; dut.so_n = 1;
        dut.clk = 0; dut.rst_n = 0; dut.eval();
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.rst_n = 1;
        // Verification-only state injection through Verilator public-flat access.
        // No production debug ports or modified external expected values.
        auto* root = dut.rootp;
        root->mos_6502_native__DOT__state = 0; // S_FETCH
        root->mos_6502_native__DOT__pc = initial.pc;
        root->mos_6502_native__DOT__a = initial.a;
        root->mos_6502_native__DOT__x = initial.x;
        root->mos_6502_native__DOT__y = initial.y;
        root->mos_6502_native__DOT__s = initial.s;
        root->mos_6502_native__DOT__p = initial.p;
        dut.eval();
        for (unsigned i = 0; i < cycle_count; ++i) {
            dut.bus_data_i = ram[dut.bus_addr]; dut.eval();
            const auto& expected_cycle = cycles[i];
            const unsigned value = dut.bus_we ? dut.bus_data_o : dut.bus_data_i;
            if (!allowed[dut.bus_addr] || dut.bus_addr != expected_cycle.address ||
                unsigned(dut.bus_we) != expected_cycle.write || value != expected_cycle.value) {
                fail("bus transaction differs; expected address=" + std::to_string(expected_cycle.address) +
                     " value=" + std::to_string(expected_cycle.value) + " write=" + std::to_string(expected_cycle.write), i);
                return 1;
            }
            if ((i == 0) != bool(dut.fetch_o)) { fail("unexpected instruction boundary", i); return 1; }
            if (dut.bus_we) ram[dut.bus_addr] = dut.bus_data_o;
            dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval();
            ++bus_checks;
        }
        const bool jam = (opcode & 15) == 2 && (opcode >> 4) != 8 &&
                         (opcode >> 4) != 10 && (opcode >> 4) != 12 && (opcode >> 4) != 14;
        // KIL records are a finite prefix of an intentionally nonterminating
        // read sequence. They must end locked, never at a new opcode fetch.
        const bool boundary_ok = jam ? (dut.jammed_o && !dut.fetch_o) : (dut.fetch_o && !dut.jammed_o);
        if (!boundary_ok || dut.fault_o || dut.pc_o != expected.pc || dut.a_o != expected.a ||
            dut.x_o != expected.x || dut.y_o != expected.y || dut.s_o != expected.s || dut.status_o != expected.p) {
            fail("exact final architectural state", cycle_count); return 1;
        }
        for (const auto& [address, value] : expected_memory)
            if (ram[address] != value) { fail("final memory", cycle_count); return 1; }
    }
    std::string extra;
    if (input >> extra) throw std::runtime_error("trailing external vector data");
    std::cout << "NATIVE NMOS BUS PASS: cases=" << cases << " bus_cycles=" << bus_checks << "\n";
    dut.final();
}
