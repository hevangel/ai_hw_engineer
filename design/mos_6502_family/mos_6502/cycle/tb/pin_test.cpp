#include "Vmos_6502_cycle.h"
#include "verilated.h"
#include <array>
#include <cstdio>
#include <cstdlib>
extern "C" {
void oracle_init(uint8_t*); void oracle_cycle(); void oracle_pins(int,int,int,int,int);
void oracle_settle_registers();
unsigned oracle_address(),oracle_data(),oracle_rw(),oracle_sync();
unsigned oracle_a(),oracle_x(),oracle_y(),oracle_sp(),oracle_p();
}
static Vmos_6502_cycle cpu;
static std::array<uint8_t,65536> memory,golden;
static unsigned test,cycle,compared;
static void require(bool ok,const char* why) {
    if(!ok) {
        std::fprintf(stderr,"pin case=%u cycle=%u rtl PC=%04x addr=%04x P=%02x oracle addr=%04x P=%02x: %s\n",
            test,cycle,cpu.pc_o,cpu.bus_addr,cpu.status_o,oracle_address(),oracle_p(),why);
        std::fprintf(stderr,"RTL A/X/Y/S=%02x/%02x/%02x/%02x oracle=%02x/%02x/%02x/%02x\n",
            cpu.a_o,cpu.x_o,cpu.y_o,cpu.sp_o,oracle_a(),oracle_x(),oracle_y(),oracle_sp());
        std::exit(1);
    }
}
static void prepare() { cpu.clk=0; cpu.eval(); cpu.bus_data_i=memory[cpu.bus_addr]; cpu.eval(); }
static void tick() {
    prepare(); if(cpu.rst_n && cpu.bus_we) memory[cpu.bus_addr]=cpu.bus_data_o;
    cpu.clk=1; cpu.eval();
}
static void load() {
    memory.fill(0x02);
    // Canonicalize real software state without injecting oracle registers.
    const uint8_t setup[]={0x78,0xd8,0xa2,0xff,0x9a,0xa9,0,0xa0,0,0x18,0xb8,0x4c,0x00,0x81};
    for(unsigned i=0;i<sizeof(setup);i++) memory[0x8000+i]=setup[i];
    // IRQ and NMI handlers preserve A then RTI; writes mark vector choice.
    const uint8_t handler[]={0x48,0xa9,0x5a,0x8d,0,2,0x68,0x40};
    for(unsigned i=0;i<sizeof(handler);i++) { memory[0x9000+i]=handler[i]; memory[0x9100+i]=handler[i]; }
    memory[0x9104]=1;
    memory[0xfffc]=0;memory[0xfffd]=0x80;
    memory[0xfffe]=0;memory[0xffff]=0x90; memory[0xfffa]=0;memory[0xfffb]=0x91;
}
static void align() {
    golden=memory; oracle_init(golden.data());
    cpu.res_n=cpu.irq_n=cpu.nmi_n=cpu.rdy=1; cpu.so_n=0;
    cpu.rst_n=0; tick(); cpu.rst_n=1;
    for(unsigned i=0;i<200 && !(cpu.fetch_o && cpu.pc_o==0x8100);i++) tick();
    require(cpu.fetch_o && cpu.pc_o==0x8100,"authored setup entry");
    for(unsigned i=0;i<200 && !(oracle_sync() && oracle_address()==0x8100);i++) oracle_cycle();
    require(oracle_sync() && oracle_address()==0x8100,"independent setup entry");
}
static void compare() {
    prepare(); ++compared;
    require(cpu.bus_addr==oracle_address(),"bus address");
    require(cpu.bus_we==!oracle_rw(),"read/write direction");
    require(cpu.fetch_o==bool(oracle_sync()),"SYNC");
    if(cpu.bus_we) require(cpu.bus_data_o==oracle_data(),"write data");
    else require(memory[cpu.bus_addr]==golden[oracle_address()],"read data");
    if(cpu.fetch_o) {
        oracle_settle_registers();
        require(cpu.a_o==oracle_a() && cpu.x_o==oracle_x() && cpu.y_o==oracle_y() &&
            cpu.sp_o==oracle_sp(),"architectural registers");
        require((cpu.status_o&0xcf)==(oracle_p()&0xcf),"architectural flags");
    }
    require(!cpu.fault_o,"unexpected fault");
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    // Sweep every sampling edge through flag controls, stack, RMW, stores,
    // BRK and RTI. Pin expectations come only from the independent netlist.
    const unsigned scenarios=8+2*4*80;
    for(test=0;test<scenarios;test++) {
        load();
        const uint8_t code[]={0x58,0xea,0x78,0xea,0x58,0xea,0x48,0x68,0x38,0x08,0x28,0xea,
            0xe6,0x30,0x8d,0x00,0x03,0xa5,0x30,0x00,0xea,0x4c,0x00,0x81};
        for(unsigned i=0;i<sizeof(code);i++) memory[0x8100+i]=code[i];
        if(test>=328) {
            const uint8_t branches[]={0x58,0xa9,0,0xd0,2,0x18,0x90,0,0x4c,0xf8,0x81};
            const uint8_t crossing[]={0xa9,1,0xd0,5};
            const uint8_t indexed[]={0xa2,1,0xbd,0xff,0x83,0xfe,0xff,0x83,0xca,0xd0,0xf5,0x4c,0,0x81};
            for(unsigned i=0;i<sizeof(branches);i++) memory[0x8100+i]=branches[i];
            for(unsigned i=0;i<sizeof(crossing);i++) memory[0x81f8+i]=crossing[i];
            for(unsigned i=0;i<sizeof(indexed);i++) memory[0x8201+i]=indexed[i];
        }
        if(test==7) {
            const uint8_t warm[]={0xf8,0x38,0xa9,0x5a,0x4c,0x04,0x81};
            for(unsigned i=0;i<sizeof(warm);i++) memory[0x8100+i]=warm[i];
            memory[0x8200]=0x4c;memory[0x8201]=0;memory[0x8202]=0x82;
        }
        align();
        if(test==7) { memory[0xfffd]=golden[0xfffd]=0x82; }
        for(cycle=0;cycle<180;cycle++) {
            int irq=1,nmi=1,ready=1,so=0,res=1;
            if(test==0 && cycle>=1 && cycle<20) irq=0;
            if(test==1 && cycle>=4 && cycle<26) irq=0;
            if(test==2 && cycle>=8 && cycle<11) nmi=0;
            if(test==3 && cycle>=8 && cycle<11) { irq=0;nmi=0; }
            if(test==4 && cycle>=20 && cycle<24) ready=0;
            if(test==5 && cycle>=25 && cycle<29) ready=0;
            if(test==6 && cycle>=3 && cycle<6) so=1;
            if(test==7 && cycle>=40 && cycle<50) res=0;
            if(test>=8) {
                unsigned kind=((test-8)%320)/80, arrival=(test-8)%80;
                if(cycle>=arrival && cycle<arrival+3) {
                    if(kind==0) irq=0;
                    if(kind==1) nmi=0;
                    if(kind==2) irq=nmi=0;
                    if(kind==3) ready=0;
                }
            }
            // Apply pin levels during phi2, before its falling sampling edge.
            cpu.irq_n=irq;cpu.nmi_n=nmi;cpu.rdy=ready;cpu.so_n=so;cpu.res_n=res;
            oracle_pins(res,irq,nmi,ready,so);
            if(test==7 && cycle>=40) {
                // Silicon held-reset accesses are unspecified. After release,
                // align only at the new reset vector, without reinitializing
                // registers with software or injecting either model's state.
                if(cycle==50) {
                    for(unsigned j=0;j<100 && !(cpu.fetch_o && cpu.pc_o==0x8200);j++) tick();
                    for(unsigned j=0;j<100 && !(oracle_sync() && oracle_address()==0x8200);j++) oracle_cycle();
                    require(cpu.fetch_o && cpu.pc_o==0x8200 && oracle_sync() && oracle_address()==0x8200,"warm reset entry");
                    compare();
                    require(cpu.a_o==0x5a && cpu.x_o==0xff && cpu.y_o==0 && cpu.sp_o==0xfc &&
                            (cpu.status_o&0x0d)==0x0d,"warm reset preservation and three stack decrements");
                    break;
                }
                tick(); oracle_cycle();
            } else { compare(); tick(); oracle_cycle(); }
        }
    }
    std::printf("PASS %u transistor-oracle pin scenarios, %u compared cycles: IRQ, NMI, priority, RDY, SO and warm reset\n",scenarios,compared);
}
