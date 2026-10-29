#include "Vmos_6526_tod.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
static unsigned bcd(unsigned value) { return (value/10)*16+value%10; }
static std::uint32_t pack(unsigned hour,unsigned minute,unsigned second,unsigned tenth,bool pm) {
    return ((bcd(hour)|(pm?128:0))<<24)|(bcd(minute)<<16)|(bcd(second)<<8)|tenth;
}
struct Rig {
    Vmos_6526_tod dut;
    std::uint64_t cycles=0, alarms=0;
    void require(bool value,const char *message) {
        if(!value) {
            std::cerr<<message<<" cycles="<<cycles<<" time="<<std::hex<<dut.time_o<<" alarm="<<dut.alarm_o<<std::dec<<'\n';
            throw std::runtime_error(message);
        }
    }
    void tick(bool edge=false) {
        dut.edge_i=edge; dut.eval(); alarms+=dut.alarm_event_o;
        dut.clk=1; dut.eval(); dut.clk=0; dut.eval(); ++cycles;
    }
    void reset() {
        dut.clk=0; dut.rst_n=0; dut.edge_i=0; dut.mode_50hz_i=0;
        dut.write_i=0; dut.read_i=0; dut.alarm_select_i=0; dut.addr=0; dut.data_i=0;
        tick(); dut.rst_n=1; dut.eval();
        require(dut.time_o==0x01000000 && dut.stopped_o && !dut.latched_o,"TOD explicit reset profile");
    }
    void put(unsigned address,unsigned data,bool alarm=false) {
        dut.addr=address; dut.data_i=data; dut.alarm_select_i=alarm; dut.write_i=1; tick();
        dut.write_i=0; dut.eval();
    }
    unsigned get(unsigned address) {
        dut.addr=address; dut.read_i=1; dut.edge_i=0; dut.eval();
        unsigned result=dut.data_o; tick(); dut.read_i=0; dut.eval(); return result;
    }
    void set(unsigned h,unsigned m,unsigned s,unsigned t,bool pm) {
        unsigned hour=bcd(h)|(pm?128:0);
        // Compensate the independently documented write-hour-12 PM flip to
        // establish each intended calendar state through actual register I/O.
        if(h==12) hour^=128;
        put(3,hour); put(2,bcd(m)); put(1,bcd(s)); put(0,t);
        require(dut.time_o==pack(h,m,s,t,pm),"TOD calendar register initialization");
    }
    void tenth() { for(unsigned i=0;i<(dut.mode_50hz_i?5u:6u);++i) tick(true); dut.edge_i=0; dut.eval(); }
};
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Rig rig; rig.reset(); unsigned states=0;
        for(unsigned pm=0;pm<2;++pm) for(unsigned h=1;h<=12;++h)
            for(unsigned m=0;m<60;++m) for(unsigned s=0;s<60;++s) for(unsigned t=0;t<10;++t) {
                rig.dut.mode_50hz_i=t&1; rig.set(h,m,s,t,pm);
                // Independent mathematical 24-hour calendar, rather than a
                // second copy of RTL's per-digit BCD counter implementation.
                unsigned next=((((h%12)+(pm?12:0))*3600+m*60+s)*10+t+1)%864000;
                unsigned nt=next%10; next/=10; unsigned ns=next%60; next/=60;
                unsigned nm=next%60, nh24=next/60, nh=nh24%12;
                if(!nh) nh=12;
                rig.tenth();
                rig.require(rig.dut.time_o==pack(nh,nm,ns,nt,nh24>=12),"TOD independent calendar next state");
                ++states;
            }
        rig.reset(); rig.put(3,0x12); rig.require(rig.dut.time_o==0x92000000 && rig.dut.stopped_o,"TOD raw hour-12 write quirk");
        rig.put(3,0x12,true); rig.require(rig.dut.alarm_o==0x12000000,"TOD alarm hour-12 does not flip PM");
        rig.reset(); rig.set(11,59,59,9,false);
        rig.require(rig.get(3)==0x11 && rig.dut.latched_o,"TOD hours starts coherent snapshot");
        rig.tenth(); rig.require(rig.dut.time_o==0x92000000,"TOD live clock continues while latched");
        rig.require(rig.get(1)==0x59 && rig.get(3)==0x11,"TOD repeated hours retains original snapshot");
        rig.require(rig.get(0)==9 && !rig.dut.latched_o,"TOD tenths reads old snapshot then releases");
        rig.require(rig.get(3)==0x92 && rig.get(0)==0,"TOD next snapshot captures current time");
        rig.reset(); rig.set(1,0,0,4,false);
        rig.put(3,1,true); rig.put(2,0,true); rig.put(1,0,true); rig.put(0,5,true);
        auto previous=rig.alarms; rig.tenth(); rig.require(rig.alarms==previous+1,"TOD advancing alarm match");
        for(unsigned i=0;i<10;++i) rig.tick();
        rig.require(rig.alarms==previous+1,"TOD equal clock does not repeatedly generate alarm");
        rig.put(0,6,true); previous=rig.alarms; rig.put(0,5,true);
        rig.require(rig.alarms==previous+1,"TOD alarm-register write comparison");
        rig.reset(); rig.put(3,1); rig.put(2,0); rig.put(1,0); rig.put(0,15); rig.tenth();
        rig.require(rig.dut.time_o==0x01000000,"TOD invalid tenths F wraps without decimal carry");
        rig.put(1,0x0f); rig.put(0,9); rig.tenth(); rig.require(rig.dut.time_o==0x01000000,"TOD invalid second nibble wraps");
        rig.put(1,0x79); rig.put(0,9); rig.tenth(); rig.require(rig.dut.time_o==0x01000000,"TOD invalid second tens wraps");
        std::cout<<"MOS 6526 TOD PASS: calendar_states="<<states<<" cycles="<<rig.cycles<<"; latch/alarm/BCD/write-12 checks\n";
    } catch(const std::exception &error) { std::cerr<<error.what()<<'\n'; return 1; }
}
