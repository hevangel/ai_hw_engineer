#include "Vmos_6502.h"
#include "Vmos_6502___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

static Vmos_6502 cpu;
static std::array<uint8_t,65536> memory;
static unsigned test_index, opcode;
static void require(bool good,const char* message) {
    if(!good) { std::fprintf(stderr,"FAIL op=%02x case=%u PC=%04x A=%02x X=%02x Y=%02x S=%02x P=%02x: %s\n",
        opcode,test_index,cpu.pc_o,cpu.a_o,cpu.x_o,cpu.y_o,cpu.sp_o,cpu.status_o,message); std::exit(1); }
}
static void prepare() {
    cpu.clk=0; cpu.eval(); cpu.bus_data_i=memory[cpu.bus_addr]; cpu.eval();
}
static void tick() {
    prepare();
    if(cpu.rst_n && cpu.bus_we) memory[cpu.bus_addr]=cpu.bus_data_o;
    cpu.clk=1; cpu.eval();
}
static void initialize() {
    cpu.res_n=cpu.irq_n=cpu.nmi_n=cpu.so_n=cpu.rdy=1;
    cpu.rst_n=0; tick(); cpu.rst_n=1;
}
static uint8_t byte(FILE* f) { int v=std::fgetc(f); require(v>=0,"truncated vector data"); return v; }
static uint16_t word(FILE* f) { unsigned lo=byte(f); return lo|(unsigned(byte(f))<<8); }
struct Registers { uint16_t pc; uint8_t a,x,y,s,p; };
static Registers registers(FILE* f) { Registers r; r.pc=word(f); r.a=byte(f); r.x=byte(f); r.y=byte(f); r.s=byte(f); r.p=byte(f); return r; }
static std::vector<std::pair<uint16_t,uint8_t>> ram(FILE* f) {
    unsigned count=word(f); std::vector<std::pair<uint16_t,uint8_t>> result;
    for(unsigned i=0;i<count;i++) { uint16_t address=word(f); uint8_t value=byte(f); result.emplace_back(address,value); }
    return result;
}
static void vectors() {
    FILE* f=std::fopen("work/vectors.bin","rb"); require(f,"vector file missing");
    unsigned count=word(f); count|=unsigned(word(f))<<16;
    for(test_index=0;test_index<count;test_index++) {
        opcode=byte(f); auto initial=registers(f), final=registers(f);
        auto before=ram(f), after=ram(f); unsigned cycles=byte(f);
        memory.fill(0x02); for(auto pair:before) memory[pair.first]=pair.second;
        initialize();
        // Verification-only starting-state injection. Expectations and every
        // bus transaction are external; production RTL has no test load port.
        auto* r=cpu.rootp;
        r->mos_6502__DOT__state=0; r->mos_6502__DOT__pc=initial.pc;
        r->mos_6502__DOT__a=initial.a; r->mos_6502__DOT__x=initial.x;
        r->mos_6502__DOT__y=initial.y; r->mos_6502__DOT__sp=initial.s; r->mos_6502__DOT__p=initial.p;
        for(unsigned cycle=0;cycle<cycles;cycle++) {
            uint16_t address=word(f); uint8_t value=byte(f), write=byte(f);
            prepare();
            if(cpu.bus_addr!=address || cpu.bus_we!=write ||
               (write ? cpu.bus_data_o : memory[cpu.bus_addr])!=value) {
                std::fprintf(stderr,"cycle %u expected %04x %02x %c got %04x %02x %c state=%u\n",
                    cycle,address,value,write?'W':'R',cpu.bus_addr,
                    cpu.bus_we ? cpu.bus_data_o : memory[cpu.bus_addr],cpu.bus_we?'W':'R',r->mos_6502__DOT__state);
                require(false,"external cycle mismatch");
            }
            require(!cpu.fault_o,"fault on documented instruction"); tick();
        }
        prepare();
        require(cpu.fetch_o && cpu.pc_o==final.pc && cpu.bus_addr==final.pc,"exact next opcode fetch PC");
        require(cpu.a_o==final.a && cpu.x_o==final.x && cpu.y_o==final.y &&
                cpu.sp_o==final.s && cpu.status_o==final.p,"external final register mismatch");
        for(auto pair:after) require(memory[pair.first]==pair.second,"external final memory mismatch");
        // Execute a single exact target instruction, with no landing padding.
        memory[final.pc]=0xa2; memory[uint16_t(final.pc+1)]=0x5a;
        tick(); tick(); prepare();
        require(cpu.fetch_o && cpu.pc_o==uint16_t(final.pc+2) && cpu.x_o==0x5a,
                "next-executed target instruction");
    }
    require(std::fgetc(f)==EOF,"extra vector data"); std::fclose(f);
    std::printf("PASS %u independent NMOS cases: all 151 documented opcodes, exact cycles, registers, memory and next instruction\n",count);
}
static void unsupported() {
    const unsigned documented[]={0x00,0x01,0x05,0x06,0x08,0x09,0x0a,0x0d,0x0e,0x10,0x11,0x15,0x16,0x18,0x19,0x1d,0x1e,0x20,0x21,0x24,0x25,0x26,0x28,0x29,0x2a,0x2c,0x2d,0x2e,0x30,0x31,0x35,0x36,0x38,0x39,0x3d,0x3e,0x40,0x41,0x45,0x46,0x48,0x49,0x4a,0x4c,0x4d,0x4e,0x50,0x51,0x55,0x56,0x58,0x59,0x5d,0x5e,0x60,0x61,0x65,0x66,0x68,0x69,0x6a,0x6c,0x6d,0x6e,0x70,0x71,0x75,0x76,0x78,0x79,0x7d,0x7e,0x81,0x84,0x85,0x86,0x88,0x8a,0x8c,0x8d,0x8e,0x90,0x91,0x94,0x95,0x96,0x98,0x99,0x9a,0x9d,0xa0,0xa1,0xa2,0xa4,0xa5,0xa6,0xa8,0xa9,0xaa,0xac,0xad,0xae,0xb0,0xb1,0xb4,0xb5,0xb6,0xb8,0xb9,0xba,0xbc,0xbd,0xbe,0xc0,0xc1,0xc4,0xc5,0xc6,0xc8,0xc9,0xca,0xcc,0xcd,0xce,0xd0,0xd1,0xd5,0xd6,0xd8,0xd9,0xdd,0xde,0xe0,0xe1,0xe4,0xe5,0xe6,0xe8,0xe9,0xea,0xec,0xed,0xee,0xf0,0xf1,0xf5,0xf6,0xf8,0xf9,0xfd,0xfe};
    unsigned count=0;
    for(opcode=0;opcode<256;opcode++) {
        bool legal=false; for(unsigned op:documented) if(op==opcode) legal=true;
        if(legal) continue;
        memory.fill(0x02); initialize();
        cpu.rootp->mos_6502__DOT__state=0; cpu.rootp->mos_6502__DOT__pc=0x8000;
        memory[0x8000]=opcode; tick(); prepare();
        require(cpu.fault_o && !cpu.fetch_o && !cpu.bus_we && cpu.pc_o==0x8001,"unsupported opcode trap");
        for(unsigned i=0;i<4;i++) { tick(); require(cpu.fault_o && !cpu.bus_we && cpu.pc_o==0x8001,"fault hold"); }
        ++count;
    }
    std::printf("PASS %u unsupported opcode traps and fault holds\n",count);
}
static void arithmetic() {
    FILE* f=std::fopen("work/arithmetic.bin","rb"); require(f,"arithmetic oracle missing");
    unsigned count=word(f); count|=unsigned(word(f))<<16;
    memory.fill(0x02);
    for(test_index=0;test_index<count;test_index++) {
        opcode=byte(f); unsigned a=byte(f),value=byte(f),p=byte(f),expected_a=byte(f),expected_p=byte(f);
        initialize(); auto* r=cpu.rootp;
        r->mos_6502__DOT__state=0; r->mos_6502__DOT__pc=0x8000;
        r->mos_6502__DOT__a=a; r->mos_6502__DOT__p=p;
        memory[0x8000]=opcode; memory[0x8001]=value;
        tick(); tick(); prepare();
        require(cpu.fetch_o && cpu.pc_o==0x8002 && cpu.a_o==expected_a && cpu.status_o==expected_p,
                "exhaustive external ADC/SBC oracle");
    }
    require(std::fgetc(f)==EOF,"extra arithmetic data"); std::fclose(f);
    std::printf("PASS %u exhaustive py65 ADC/SBC cases, binary/decimal, both carries, including invalid BCD\n",count);
}
static void klaus() {
    FILE* f=std::fopen("work/external/6502_functional_test.bin","rb"); require(f,"Klaus binary missing");
    require(std::fread(memory.data(),1,memory.size(),f)==memory.size(),"Klaus binary size"); std::fclose(f);
    memory[0xfffc]=0; memory[0xfffd]=4; initialize();
    uint16_t previous=0xffff; unsigned repeats=0; uint64_t cycles=0,instructions=0;
    while(cycles++<200000000) {
        prepare(); require(!cpu.fault_o,"Klaus unsupported opcode");
        if(cpu.fetch_o) {
            ++instructions;
            if(cpu.pc_o==previous) ++repeats; else repeats=0;
            previous=cpu.pc_o;
            if(repeats==3) {
                require(cpu.pc_o==0x3469,"Klaus trapped before success");
                std::printf("PASS Klaus functional test: success PC=3469 instructions=%llu cycles=%llu\n",
                    (unsigned long long)instructions,(unsigned long long)cycles); return;
            }
        }
        tick();
    }
    require(false,"Klaus timeout");
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv); vectors(); unsupported(); arithmetic(); klaus(); return 0;
}
