#include "Vmos_6526_serial.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
struct Rig {
    Vmos_6526_serial dut;
    std::uint64_t cycles=0, interrupts=0;
    void require(bool value,const char *message) {
        if(!value) { std::cerr<<message<<" cycle="<<cycles<<'\n'; throw std::runtime_error(message); }
    }
    void tick(bool baud=false,bool receive=false,bool input=true) {
        dut.baud_pulse_i=baud; dut.cnt_rise_i=receive; dut.sp_i=input; dut.eval();
        interrupts+=dut.irq_event_o;
        dut.clk=1; dut.eval(); dut.clk=0; dut.eval(); ++cycles;
        require(dut.cnt_oe==(dut.output_mode_i&&!dut.cnt_o) &&
                dut.sp_oe==(dut.output_mode_i&&!dut.sp_o),"serial open-drain intents");
    }
    void reset(bool output=false) {
        dut.clk=0; dut.rst_n=0; dut.output_mode_i=0; dut.write_i=0; dut.data_i=0;
        tick(); dut.rst_n=1; dut.output_mode_i=output; tick();
    }
    void put(unsigned data,bool baud=false) {
        dut.data_i=data; dut.write_i=1; tick(baud); dut.write_i=0; dut.eval();
        require(dut.data_o==data,"SDR write readback");
    }
};
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Rig rig; rig.reset();
        for(unsigned data=0;data<256;++data) {
            auto previous=rig.interrupts;
            for(int bit=7;bit>=0;--bit) {
                rig.tick(false,false,!((data>>bit)&1));
                rig.tick(false,true,(data>>bit)&1);
                if(bit) rig.require(rig.interrupts==previous,"receive IRQ cannot precede bit eight");
            }
            rig.require(rig.dut.data_o==data && rig.interrupts==previous+1,"all input bytes MSB first");
        }
        for(unsigned pair=0;pair<65536;++pair) {
            unsigned first=pair>>8, second=pair&255, decoded=0, received=0;
            rig.reset(true); rig.put(first); auto previous=rig.interrupts;
            for(unsigned half=0;half<32;++half) {
                bool before=rig.dut.cnt_o;
                // Queue the second byte while the first one is in flight.
                if(half==3) rig.put(second,true); else rig.tick(true);
                if(!before && rig.dut.cnt_o) { decoded=(decoded<<1)|rig.dut.sp_o; ++received; }
                if(half%3==0) {
                    auto clock=rig.dut.cnt_o, data=rig.dut.sp_o;
                    rig.tick(); rig.require(rig.dut.cnt_o==clock && rig.dut.sp_o==data,"baud gaps preserve clock and data");
                }
            }
            for(unsigned drain=0;drain<4;++drain) rig.tick();
            rig.require(received==16 && decoded==pair && rig.interrupts==previous+2,"all buffered output byte pairs");
            rig.require(!rig.dut.active_o && !rig.dut.pending_o && rig.dut.cnt_o && rig.dut.sp_o==(second&1),
                        "serial idle retains final bit and releases CNT");
        }
        // Exact hardware-qualified request latency, with sparse baud pulses.
        rig.reset(true); rig.put(0x55); auto previous=rig.interrupts;
        for(unsigned half=0;half<15;++half) {
            rig.tick(true);
            if(half!=14) for(unsigned gap=0;gap<8;++gap) rig.tick();
        }
        rig.require(!rig.dut.cnt_o && rig.interrupts==previous,"bit eight presented before completion request");
        for(unsigned delay=0;delay<3;++delay) {
            rig.tick(); rig.require(rig.interrupts==previous,"no early transmit request");
        }
        rig.tick();
        rig.require(rig.interrupts==previous+1 && !rig.dut.cnt_o,"request four clocks after fifteenth baud pulse");
        rig.tick(true);
        rig.require(rig.dut.cnt_o && !rig.dut.active_o,"sixteenth pulse completes CNT wire transfer");
        rig.reset(true); rig.put(0x55); previous=rig.interrupts;
        for(unsigned half=0;half<15;++half) rig.tick(true);
        rig.dut.output_mode_i=0; rig.tick();
        for(unsigned drain=0;drain<4;++drain) rig.tick();
        rig.require(rig.interrupts==previous,"direction change cancels an in-flight transmit request");
        rig.reset(true); rig.put(0x12); rig.put(0x34); // overwrite full pending slot
        unsigned decoded=0;
        for(unsigned half=0;half<16;++half) {
            bool before=rig.dut.cnt_o; rig.tick(true);
            if(!before && rig.dut.cnt_o) decoded=(decoded<<1)|rig.dut.sp_o;
        }
        rig.require(decoded==0x34,"latest write replaces pending byte");
        rig.reset();
        for(unsigned bit=0;bit<7;++bit) rig.tick(false,true,true);
        previous=rig.interrupts; rig.dut.write_i=1; rig.dut.data_i=0x5a; rig.tick(false,true,true); rig.dut.write_i=0;
        rig.require(rig.dut.data_o==0x5a && rig.interrupts==previous+1,"CPU SDR write wins coincident receive completion");
        rig.reset(true); rig.put(0); rig.tick(true); rig.dut.output_mode_i=0; rig.tick();
        rig.require(!rig.dut.active_o && !rig.dut.pending_o && rig.dut.cnt_o && rig.dut.sp_o && !rig.dut.cnt_oe && !rig.dut.sp_oe,
                    "direction transition flushes and releases lines");
        std::cout<<"MOS 6526 SERIAL PASS: 256 RX bytes, 65536 buffered TX pairs; cycles="<<rig.cycles<<'\n';
    } catch(const std::exception &error) { std::cerr<<error.what()<<'\n'; return 1; }
}
