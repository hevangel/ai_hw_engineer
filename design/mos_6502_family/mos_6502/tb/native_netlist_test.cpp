#include "Vmos_6502_native.h"
#include "Vmos_6502_native___024root.h"
#include "verilated.h"
#include <array>
#include <iostream>
#include <stdexcept>
#include <algorithm>
extern "C" {
void *initAndResetChip(void);
void destroyChip(void *);
void oracle_cycle(void *);
void oracle_pins(void *, int, int, int);
int oracle_sync(void *);
unsigned short readAddressBus(void *);
unsigned char readDataBus(void *);
unsigned int readRW(void *);
unsigned char readA(void *), readX(void *), readY(void *), readSP(void *), readP(void *);
extern unsigned char memory[65536];
}

static void scenario(unsigned mode, unsigned edge, bool crossing) {
    const unsigned start=crossing ? 0x80f0 : 0x8100;
    std::fill(memory, memory+65536, 0xea);
    memory[0xfffc]=0; memory[0xfffd]=0x80;
    memory[0xfffe]=0; memory[0xffff]=0x90;
    memory[0xfffa]=0; memory[0xfffb]=0xa0;
    // Bootstrap establishes defined registers without manipulating the netlist.
    const unsigned char boot[]={0xa2,0xfd,0x9a,0xa9,0x35,0xa0,0x11,0x18,0xd8,0x58,0x4c,0,0x81};
    std::copy(std::begin(boot),std::end(boot),memory+0x8000);
    memory[0x800b]=start&255; memory[0x800c]=start>>8;
    // NOP, indexed crossing, RMW, stack, branch and CLI/SEI polling boundaries.
    const unsigned char program[]={0xea,0xa2,1,0xbd,0xff,0x20,0xe6,0x40,0x48,0x68,
        0xa9,2,0x38,0xe9,1,0xd0,0xfb,0x78,0xea,0x58,0xea,0x4c,0,0x81};
    std::copy(std::begin(program),std::end(program),memory+start);
    memory[start+22]=start&255; memory[start+23]=start>>8;
    if (mode==6) memory[start]=0; // NMI arrival across BRK stack/vector cycles.
    memory[0x9000]=0x40; memory[0xa000]=0x40;
    auto *chip=initAndResetChip();
    unsigned boot_cycles=0;
    do { oracle_cycle(chip); if (++boot_cycles>100) throw std::runtime_error("netlist bootstrap"); }
    while (!oracle_sync(chip) || readAddressBus(chip)!=start);
    std::array<unsigned char,65536> ram;
    std::copy(memory,memory+65536,ram.begin());
    Vmos_6502_native dut;
    dut.clk=0; dut.rst_n=0; dut.rdy_i=1; dut.irq_n=1; dut.nmi_n=1; dut.so_n=1;
    dut.eval(); dut.clk=1; dut.eval(); dut.clk=0; dut.rst_n=1;
    auto *root=dut.rootp;
    root->mos_6502_native__DOT__state=0;
    root->mos_6502_native__DOT__pc=start;
    root->mos_6502_native__DOT__a=readA(chip);
    root->mos_6502_native__DOT__x=readX(chip);
    root->mos_6502_native__DOT__y=readY(chip);
    root->mos_6502_native__DOT__s=readSP(chip);
    root->mos_6502_native__DOT__p=(readP(chip)|0x20)&0xef;
    for (unsigned cycle=0;cycle<90;++cycle) {
        const int ready=!((mode==1 || mode==4 || mode==5) && cycle>=edge && cycle<edge+3);
        const int irq_high=!((mode==2 || mode==5) && cycle>=edge && cycle<edge+8);
        const int nmi_high=!((mode==3 || mode==4 || mode==6) && cycle>=edge && cycle<edge+2);
        // Current transistor bus was settled on the preceding rising edge.
        // Apply inputs to both before completing this transaction.
        oracle_pins(chip,ready,irq_high,nmi_high);
        dut.rdy_i=ready; dut.irq_n=irq_high; dut.nmi_n=nmi_high;
        dut.eval(); dut.bus_data_i=ram[dut.bus_addr]; dut.eval();
        const auto address=readAddressBus(chip);
        const bool write=!readRW(chip);
        if (dut.bus_addr!=address || bool(dut.bus_we)!=write ||
            (write && dut.bus_data_o!=readDataBus(chip))) {
            std::cerr<<"netlist mismatch mode="<<mode<<" edge="<<edge<<" cycle="<<cycle
                <<" RTL="<<std::hex<<dut.bus_addr<<"/"<<unsigned(dut.bus_we)<<"/"<<unsigned(dut.bus_data_o)
                <<" silicon="<<address<<"/"<<write<<"/"<<unsigned(readDataBus(chip))<<std::dec<<'\n';
            throw std::runtime_error("independent transistor bus");
        }
        if (write) ram[dut.bus_addr]=dut.bus_data_o;
        dut.clk=1; dut.eval(); dut.clk=0; dut.eval();
        oracle_cycle(chip);
    }
    destroyChip(chip);
}
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        for (bool crossing : {false,true}) {
            scenario(0,0,crossing);
            for (unsigned mode=1;mode<=6;++mode)
                for (unsigned edge=0;edge<64;++edge) scenario(mode,edge,crossing);
        }
        std::cout<<"NATIVE NETLIST PASS: 770 scenarios, 69300 bus cycles\n";
    } catch(const std::exception &e) { std::cerr<<e.what()<<'\n'; return 1; }
}
