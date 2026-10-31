#include "Vmos_6502_native.h"
#include "Vmos_6502_native___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

struct Rig {
    Vmos_6502_native dut;
    std::array<std::uint8_t, 65536> ram{};
    std::uint64_t cycles = 0;
    void settle() { dut.eval(); dut.bus_data_i = ram[dut.bus_addr]; dut.eval(); }
    void tick() {
        settle();
        if (dut.bus_we) ram[dut.bus_addr] = dut.bus_data_o;
        dut.clk = 1; dut.eval(); dut.clk = 0; settle(); ++cycles;
    }
    void seed(unsigned pc = 0x8000, unsigned p = 0x24, unsigned s = 0xfd) {
        dut.rdy_i = 1; dut.irq_n = 1; dut.nmi_n = 1; dut.so_n = 1;
        dut.clk = 0; dut.rst_n = 0; dut.eval(); dut.clk = 1; dut.eval();
        dut.clk = 0; dut.rst_n = 1;
        auto* root = dut.rootp;
        root->mos_6502_native__DOT__state = 0;
        root->mos_6502_native__DOT__pc = pc;
        root->mos_6502_native__DOT__p = p;
        root->mos_6502_native__DOT__s = s;
        root->mos_6502_native__DOT__a = 0x35;
        root->mos_6502_native__DOT__x = 0x80;
        root->mos_6502_native__DOT__y = 0x11;
        settle();
    }
    void require(bool ok, const char* what) {
        if (!ok) {
            std::cerr << what << " cycle=" << cycles << " PC=" << std::hex << dut.pc_o
                      << " addr=" << dut.bus_addr << " P=" << unsigned(dut.status_o) << std::dec << '\n';
            throw std::runtime_error(what);
        }
    }
    void transfer(unsigned address, bool write = false, unsigned value = 0) {
        settle();
        require(dut.bus_addr == address && bool(dut.bus_we) == write, "exact control bus transaction");
        if (write) require(dut.bus_data_o == value, "exact control write data");
        tick();
    }
};

static void controls() {
    Rig rig;
    rig.seed(0x4567, 0xe9, 0x20);
    rig.ram[0xfffc] = 0; rig.ram[0xfffd] = 0x80;
    rig.dut.rst_n = 0; rig.tick(); rig.dut.rst_n = 1;
    // MOS hardware reset: two PC reads, three stack reads, vector reads.
    for (unsigned address : {0x4567, 0x4567, 0x0120, 0x011f, 0x011e, 0xfffc, 0xfffd})
        rig.transfer(address);
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8000 && rig.dut.s_o == 0x1d, "reset PC/SP");
    rig.require(rig.dut.a_o == 0x35 && rig.dut.x_o == 0x80 && rig.dut.y_o == 0x11 &&
                rig.dut.status_o == 0xed, "warm reset preserves registers and non-I flags");

    rig.seed();
    rig.ram[0x8000] = 0xa9; rig.ram[0x8001] = 0x55; // LDA #55
    rig.ram[0x8002] = 0x8d; rig.ram[0x8003] = 0; rig.ram[0x8004] = 0x20; // STA 2000
    rig.ram[0x8005] = 0xe6; rig.ram[0x8006] = 0x20; rig.ram[0x20] = 0xff; // INC 20
    rig.dut.rdy_i = 0;
    for (unsigned i = 0; i < 3; ++i) rig.transfer(0x8000);
    rig.require(rig.dut.pc_o == 0x8000 && rig.dut.a_o == 0x35, "RDY holds opcode read");
    rig.dut.rdy_i = 1; rig.transfer(0x8000);
    rig.dut.rdy_i = 0;
    for (unsigned i = 0; i < 3; ++i) rig.transfer(0x8001);
    rig.require(rig.dut.pc_o == 0x8001 && rig.dut.a_o == 0x35, "RDY holds operand read");
    rig.dut.rdy_i = 1; rig.transfer(0x8001);
    rig.require(rig.dut.pc_o == 0x8002 && rig.dut.a_o == 0x55, "exact next instruction after stalled LDA");
    rig.transfer(0x8002); rig.transfer(0x8003); rig.transfer(0x8004);
    rig.dut.rdy_i = 0; rig.transfer(0x2000, true, 0x55);
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8005 && rig.ram[0x2000] == 0x55,
                "RDY cannot stall a write");
    rig.dut.rdy_i = 1; rig.transfer(0x8005); rig.transfer(0x8006); rig.transfer(0x20);
    rig.dut.rdy_i = 0; rig.transfer(0x20, true, 0xff); rig.transfer(0x20, true, 0);
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8007 && rig.ram[0x20] == 0,
                "NMOS old/new RMW writes advance despite RDY");

    rig.seed();
    rig.ram[0x8000] = 0x58; rig.ram[0x8001] = 0xea; rig.ram[0x8002] = 0xea;
    rig.ram[0xfffe] = 0; rig.ram[0xffff] = 0x90; rig.dut.irq_n = 0;
    rig.transfer(0x8000); rig.transfer(0x8001); // CLI completes using old I for polling.
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8001, "CLI next PC");
    rig.transfer(0x8001); rig.transfer(0x8002); // One following NOP must execute.
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8002, "CLI IRQ polling latency");
    rig.transfer(0x8002); rig.transfer(0x8002); // Discarded fetch/padding.
    rig.transfer(0x01fd, true, 0x80); rig.transfer(0x01fc, true, 0x02);
    rig.transfer(0x01fb, true, 0x20); rig.transfer(0xfffe); rig.transfer(0xffff);
    rig.require(rig.dut.pc_o == 0x9000 && rig.dut.s_o == 0xfa && rig.dut.fetch_o, "IRQ vector and exact stacked PC");

    rig.seed(); rig.ram[0x8000] = 0xea; rig.ram[0x8001] = 0xea;
    rig.ram[0xfffa] = 0; rig.ram[0xfffb] = 0xa0;
    rig.dut.rdy_i = 0; rig.dut.nmi_n = 0; rig.transfer(0x8000);
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0x8000, "NMI captured during RDY stall");
    // A pending NMI is polled by the resumed NOP, not by its opcode fetch.
    // Pin timing is independently covered by the die-derived netlist sweep.
    rig.dut.rdy_i = 1; rig.transfer(0x8000); rig.transfer(0x8001);
    rig.transfer(0x8001); rig.transfer(0x8001);
    rig.transfer(0x01fd, true, 0x80); rig.transfer(0x01fc, true, 1);
    rig.transfer(0x01fb, true, 0x24); rig.transfer(0xfffa); rig.transfer(0xfffb);
    rig.require(rig.dut.fetch_o && rig.dut.pc_o == 0xa000, "NMI vector wins despite I mask");

    rig.seed(); rig.dut.rdy_i = 0; rig.dut.so_n = 0; rig.transfer(0x8000);
    rig.require(rig.dut.pc_o == 0x8000 && (rig.dut.status_o & 0x40), "SO sets V while RDY holds the CPU");
    rig.seed(); rig.ram[0x8000] = 0x02;
    rig.transfer(0x8000); rig.transfer(0x8001); rig.transfer(0xffff);
    rig.transfer(0xfffe); rig.transfer(0xfffe);
    rig.require(rig.dut.jammed_o && !rig.dut.fetch_o && rig.dut.pc_o == 0x8001, "KIL locks rather than fetching another instruction");
    rig.dut.irq_n = 0; rig.dut.nmi_n = 0;
    for (unsigned i = 0; i < 5; ++i) rig.transfer(0xffff);
    rig.require(rig.dut.jammed_o && rig.dut.pc_o == 0x8001, "interrupts cannot release KIL");
    rig.ram[0xfffc] = 0; rig.ram[0xfffd] = 0x90;
    rig.dut.rst_n = 0; rig.tick(); rig.dut.rst_n = 1;
    rig.transfer(0x8001); rig.transfer(0x8001); rig.transfer(0x01fd);
    rig.transfer(0x01fc); rig.transfer(0x01fb); rig.transfer(0xfffc); rig.transfer(0xfffd);
    rig.require(!rig.dut.jammed_o && rig.dut.fetch_o && rig.dut.pc_o == 0x9000, "reset releases KIL into the exact vector");
    std::cout << "NATIVE NMOS CONTROL PASS: reset/RDY/RMW/IRQ/NMI/SO/KIL\n";
}

static void klaus(const char* image) {
    Rig rig;
    std::ifstream input(image);
    unsigned value, size = 0;
    while (input >> std::hex >> value) {
        if (size >= 65536 || value > 255) throw std::runtime_error("invalid Klaus hex image");
        rig.ram[size++] = value;
    }
    if (size != 65536) throw std::runtime_error("Klaus image must contain exactly 64 KiB");
    rig.seed(0, 0x24, 0);
    rig.ram[0xfffc] = 0; rig.ram[0xfffd] = 4;
    rig.dut.rst_n = 0; rig.tick(); rig.dut.rst_n = 1;
    unsigned last_pc = 0x10000, repeated = 0;
    for (unsigned cycle = 0; cycle < 200000000; ++cycle) {
        rig.settle();
        rig.require(!rig.dut.fault_o, "fault during authentic Klaus test");
        if (rig.dut.fetch_o) {
            if (rig.dut.pc_o == 0x3469) {
                rig.require(rig.ram[0x3469] == 0x4c && rig.ram[0x346a] == 0x69 && rig.ram[0x346b] == 0x34,
                            "exact Klaus success instruction");
                std::cout << "NATIVE NMOS KLAUS PASS: PC=3469 cycles=" << cycle << "\n";
                return;
            }
            repeated = last_pc == rig.dut.pc_o ? repeated+1 : 0;
            last_pc = rig.dut.pc_o;
            rig.require(repeated < 8, "Klaus failure trap (exact PC)");
        }
        rig.tick();
    }
    throw std::runtime_error("Klaus watchdog");
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    controls();
    if (argc == 2) klaus(argv[1]);
    else if (argc != 1) return 2;
}
