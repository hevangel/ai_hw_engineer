#include "Vmos_6526_timer.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <random>
#include <algorithm>
extern "C" {
void cia_oracle_reset(void), cia_oracle_cycle(unsigned,unsigned,int);
unsigned cia_oracle_count(void), cia_oracle_latch(void), cia_oracle_started(void), cia_oracle_underflow(void);
}
struct Rig {
    Vmos_6526_timer dut;
    std::uint64_t cycles=0, underflows=0;
    bool phi2=false;
    void compare() {
        if (dut.count_o!=cia_oracle_count() || dut.latch_o!=cia_oracle_latch() ||
            dut.started_o!=cia_oracle_started() || dut.underflow_o!=cia_oracle_underflow()) {
            std::cerr<<"CIA timer mismatch cycle="<<cycles<<std::hex<<" count="<<dut.count_o<<"/"<<cia_oracle_count()
                <<" latch="<<dut.latch_o<<"/"<<cia_oracle_latch()<<" started="<<unsigned(dut.started_o)<<"/"<<cia_oracle_started()
                <<" underflow="<<unsigned(dut.underflow_o)<<"/"<<cia_oracle_underflow()<<std::dec<<'\n';
            throw std::runtime_error("unchanged external timer oracle");
        }
    }
    void reset() {
        cia_oracle_reset(); phi2=false;
        dut.clk=0; dut.rst_n=0; dut.phi2_mode_i=0; dut.pulse_i=0;
        dut.write_low_i=0; dut.write_high_i=0; dut.write_control_i=0; dut.data_i=0;
        dut.eval(); dut.clk=1; dut.eval(); dut.clk=0; dut.rst_n=1; dut.eval(); compare();
    }
    void step(unsigned command=0,unsigned data=0,bool pulse=false) {
        dut.phi2_mode_i=phi2; dut.pulse_i=pulse;
        dut.write_low_i=command==1; dut.write_high_i=command==2; dut.write_control_i=command==3;
        dut.data_i=data; dut.eval(); dut.clk=1; dut.eval(); dut.clk=0;
        cia_oracle_cycle(command,data,pulse);
        if (command==3) phi2=!(data&0x20);
        dut.eval(); ++cycles; compare(); underflows+=dut.underflow_o;
    }
};
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Rig rig;
        // Every 16-bit load: stopped high-byte reload, force/start, pipeline,
        // continuous/one-shot alternating, then stop while stages are active.
        for(unsigned load=0;load<65536;++load) {
            rig.reset(); rig.step(1,load&255); rig.step(2,load>>8);
            rig.step(3,(load&1)?0x19:0x11);
            for(unsigned i=0;i<std::min(load+6,24u);++i) rig.step();
            rig.step(3,0); for(unsigned i=0;i<4;++i) rig.step();
        }
        for(unsigned load : {0u,1u,2u,255u,256u,65534u,65535u}) {
            for(unsigned mode : {0x11u,0x19u,0x31u,0x39u}) {
                rig.reset(); rig.step(1,load&255); rig.step(2,load>>8); rig.step(3,mode);
                for(unsigned i=0;i<load+8;++i) rig.step(0,0,!rig.phi2);
            }
        }
        // Seeded writes can coincide with pending loads/underflows. Clock and
        // pulse modes use the independent emulator's public APIs unchanged.
        std::mt19937 random(0x6526);
        rig.reset();
        for(unsigned i=0;i<1000000;++i) {
            const unsigned choice=random()%16;
            const unsigned command=choice<3?choice+1:0;
            unsigned data=random()&255;
            if(command==2 && (random()&1)) data=0;
            rig.step(command,data,!rig.phi2 && (random()&1));
        }
        std::cout<<"MOS 6526 TIMER ORACLE PASS: 65536 loads; cycles="<<rig.cycles<<" underflows="<<rig.underflows<<'\n';
    } catch(const std::exception &error) { std::cerr<<error.what()<<'\n'; return 1; }
}
