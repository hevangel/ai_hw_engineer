// Replays independent SingleStepTests nes6502 records through the complete
// ricoh_2a03 (core + DMA/APU bus wrapper): every bus cycle and the exact
// final PC/registers/RAM must match. Expected values are never edited.
#include "Vricoh_2a03.h"
#include "Vricoh_2a03___024root.h"
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
    if (!input || state.pc > 65535 || state.a > 255 || state.x > 255 || state.y > 255 ||
        state.s > 255 || state.p > 255) throw std::runtime_error("invalid external state");
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
    if (argc != 2) { std::cerr << "usage: cpu_vector_test vectors.txt\n"; return 2; }
    Verilated::commandArgs(argc, argv);
    std::ifstream input(argv[1]);
    unsigned cases;
    input >> cases;
    if (!input || cases == 0) throw std::runtime_error("empty/missing external vectors");
    Vricoh_2a03 dut;
    std::uint64_t bus_checks = 0;
    std::array<unsigned, 256> per_opcode{};
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
            std::cerr << std::hex << "2A03 mismatch op=" << opcode << " case=" << std::dec << index
                      << " cycle=" << cycle << " " << why << std::hex << " addr=" << dut.addr_o
                      << " PC=" << dut.pc_o << " A=" << unsigned(dut.a_o) << " X=" << unsigned(dut.x_o)
                      << " Y=" << unsigned(dut.y_o) << " S=" << unsigned(dut.s_o) << " P=" << unsigned(dut.p_o)
                      << " expected PC=" << expected.pc << " A=" << expected.a << " X=" << expected.x
                      << " Y=" << expected.y << " S=" << expected.s << " P=" << expected.p << std::dec << "\n";
        };
        dut.irq_n = 1; dut.nmi_n = 1;
        dut.clk = 0; dut.rst_n = 0; dut.eval();
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.rst_n = 1;
        // Verification-only state injection through Verilator public-flat access.
        auto* root = dut.rootp;
        root->ricoh_2a03__DOT__core__DOT__state = 0; // S_FETCH
        root->ricoh_2a03__DOT__core__DOT__pc = initial.pc;
        root->ricoh_2a03__DOT__core__DOT__a = initial.a;
        root->ricoh_2a03__DOT__core__DOT__x = initial.x;
        root->ricoh_2a03__DOT__core__DOT__y = initial.y;
        root->ricoh_2a03__DOT__core__DOT__s = initial.s;
        root->ricoh_2a03__DOT__core__DOT__p = initial.p;
        dut.eval();
        for (unsigned i = 0; i < cycle_count; ++i) {
            dut.data_i = ram[dut.addr_o]; dut.eval();
            const auto& want = cycles[i];
            const unsigned value = dut.we_o ? dut.data_o : dut.data_i;
            if (dut.dma_o || !allowed[dut.addr_o] || dut.addr_o != want.address ||
                unsigned(dut.we_o) != want.write || value != want.value) {
                fail("bus transaction differs; expected address=" + std::to_string(want.address) +
                     " value=" + std::to_string(want.value) + " write=" + std::to_string(want.write), i);
                return 1;
            }
            if ((i == 0) != bool(dut.fetch_o)) { fail("unexpected instruction boundary", i); return 1; }
            if (dut.we_o) ram[dut.addr_o] = dut.data_o;
            dut.clk = 1; dut.eval(); dut.clk = 0; dut.eval();
            ++bus_checks;
        }
        const bool jam = (opcode & 15) == 2 && (opcode >> 4) != 8 && (opcode >> 4) != 10 &&
                         (opcode >> 4) != 12 && (opcode >> 4) != 14;
        const bool boundary_ok = jam ? (dut.jammed_o && !dut.fetch_o) : (dut.fetch_o && !dut.jammed_o);
        if (!boundary_ok || dut.fault_o || dut.pc_o != expected.pc || dut.a_o != expected.a ||
            dut.x_o != expected.x || dut.y_o != expected.y || dut.s_o != expected.s || dut.p_o != expected.p) {
            fail("exact final architectural state", cycle_count); return 1;
        }
        for (const auto& [address, value] : expected_memory)
            if (ram[address] != value) { fail("final memory", cycle_count); return 1; }
        ++per_opcode[opcode];
    }
    std::string extra;
    if (input >> extra) throw std::runtime_error("trailing external vector data");
    unsigned covered = 0;
    for (unsigned n : per_opcode) covered += n != 0;
    std::cout << "RICOH 2A03 CPU VECTOR PASS: cases=" << cases << " opcodes=" << covered
              << " bus_cycles=" << bus_checks << "\n";
    dut.final();
}
