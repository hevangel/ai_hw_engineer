#include "Vintel_8086.h"
#include "Vintel_8086___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

using Registers = std::array<uint16_t,14>;
static uint32_t physical(uint16_t segment, uint16_t offset) {
    return ((uint32_t(segment)<<4)+offset)&0xfffff;
}
class Bench {
public:
    Vintel_8086 dut;
    std::vector<uint8_t> memory = std::vector<uint8_t>(1<<20);
    std::vector<uint32_t> touched;
    std::unordered_map<uint32_t,uint8_t> writes;
    std::vector<std::pair<uint32_t,uint8_t>> ordered_writes;
    uint32_t cycles=0, fetch_address=0, first_fetch_address=0;
    uint8_t fetch_byte=0, first_fetch_byte=0;
    bool saw_fetch=false;
    void tick(bool stall=false) {
        dut.clk=0; dut.bus_ready_i=!stall;
        dut.eval();
        uint32_t address=dut.bus_addr_o;
        dut.bus_rdata_i=memory[address] | (uint16_t(memory[(address+1)&0xfffff])<<8);
        dut.eval();
        if (dut.bus_req_o && dut.bus_ready_i) {
            uint32_t selected=(address+(dut.bus_be_o==2))&0xfffff;
            if (dut.bus_write_o) {
                uint8_t value=uint8_t(dut.bus_wdata_o>>(dut.bus_be_o==2 ? 8:0));
                set(selected,value); writes[selected]=value; ordered_writes.emplace_back(selected,value);
            } else if (dut.bus_fetch_o) {
                if(!saw_fetch) {first_fetch_address=selected; first_fetch_byte=memory[selected];}
                fetch_address=selected; fetch_byte=memory[selected]; saw_fetch=true;
            }
        }
        dut.clk=1; dut.eval(); ++cycles;
    }
    void set(uint32_t address,uint8_t value) {
        address&=0xfffff; memory[address]=value; touched.push_back(address);
    }
    void reset() {
        for (auto address:touched) memory[address]=0;
        touched.clear(); writes.clear(); ordered_writes.clear(); cycles=0; saw_fetch=false;
        dut.rst_n=0; tick(); tick(); dut.rst_n=1;
    }
    void load(const Registers &r) {
        auto *root=dut.rootp;
        for (int i=0;i<8;++i) root->intel_8086__DOT__gpr[i]=r[i];
        for (int i=0;i<4;++i) root->intel_8086__DOT__seg[i]=r[8+i];
        root->intel_8086__DOT__ip=r[12]; root->intel_8086__DOT__flags=r[13];
        dut.eval();
    }
    Registers read() {
        Registers r{};
        for(int i=0;i<8;++i) r[i]=(dut.regs_o[i/2]>>(16*(i%2)))&65535;
        for(int i=0;i<4;++i) r[8+i]=(dut.segs_o>>(16*i))&65535;
        r[12]=dut.ip_o; r[13]=dut.flags_o; return r;
    }
    void retire() {
        saw_fetch=false;
        for (unsigned step=0;step<1000;++step) {
            // Deterministic ready backpressure affects every instruction family.
            tick((cycles%7)<3);
            if(dut.fault_o) throw std::runtime_error("unexpected fault");
            if(dut.retire_o) return;
        }
        throw std::runtime_error("retirement watchdog");
    }
};
static uint32_t number(std::istream &in,unsigned bytes) {
    uint32_t value=0;
    for(unsigned i=0;i<bytes;++i) {
        int c=in.get(); if(c<0) throw std::runtime_error("truncated fixture");
        value|=uint32_t(c)<<(8*i);
    }
    return value;
}
static Registers registers(std::istream &in) {
    Registers r{}; for(auto &v:r) v=number(in,2); return r;
}
static std::vector<std::pair<uint32_t,uint8_t>> pairs(std::istream &in) {
    std::vector<std::pair<uint32_t,uint8_t>> result;
    auto n=number(in,4);
    for(uint32_t i=0;i<n;++i) {auto a=number(in,4); auto v=number(in,1); result.emplace_back(a,v);}
    return result;
}
static std::unordered_map<uint32_t,uint8_t> ram(std::istream &in) {
    auto data=pairs(in); return {data.begin(),data.end()};
}
static void compare(const Registers &actual,const Registers &expected,uint16_t mask) {
    static const char *names[]={"AX","CX","DX","BX","SP","BP","SI","DI","ES","CS","SS","DS","IP","FLAGS"};
    for(unsigned i=0;i<14;++i) {
        auto difference=actual[i]^expected[i]; if(i==13) difference&=mask;
        if(difference) throw std::runtime_error(std::string(names[i])+" actual="+
            std::to_string(actual[i])+" expected="+std::to_string(expected[i]));
    }
}
static void next_nop(Bench &b,const Registers &expected) {
    auto prior_flags=b.dut.flags_o;
    auto address=physical(expected[9],expected[12]);
    b.set(address,0x90); b.writes.clear(); b.ordered_writes.clear(); b.retire();
    auto after=expected; after[12]++; after[13]=prior_flags;
    compare(b.read(),after,65535);
    if(!b.saw_fetch || b.fetch_address!=address || b.fetch_byte!=0x90 || !b.writes.empty())
        throw std::runtime_error("next executed instruction was not the exact target NOP");
}
static void vectors(Bench &b,const char *path) {
    std::ifstream input(path,std::ios::binary); if(!input) throw std::runtime_error("missing vector file");
    std::string magic(8,'\0'); input.read(magic.data(),8);
    if(magic!=std::string("8086V1\0\0",8)) throw std::runtime_error("bad vector header");
    unsigned count=0; std::string label;
    try {
        while(input.peek()!=EOF) {
            auto n=number(input,2); label.resize(n); input.read(label.data(),n);
            auto initial=registers(input),expected=registers(input); auto mask=number(input,2);
            auto initial_ram=ram(input),expected_ram=ram(input);
            auto expected_writes=pairs(input);
            for(auto [a,v]:initial_ram) if(!expected_ram.count(a)) expected_ram[a]=v;
            b.reset(); b.load(initial);
            for(auto [a,v]:initial_ram) b.set(a,v);
            b.retire(); compare(b.read(),expected,mask);
            for(auto [a,v]:expected_ram) if(b.memory[a]!=v)
                throw std::runtime_error("memory mismatch at "+std::to_string(a));
            for(auto [a,v]:b.writes) if(!expected_ram.count(a) || expected_ram[a]!=v)
                throw std::runtime_error("unlisted/incorrect write at "+std::to_string(a));
            if(b.ordered_writes!=expected_writes)
                throw std::runtime_error("ordered byte writes differ from the hardware bus trace");
            if(!b.dut.halted_o) next_nop(b,expected);
            else { b.tick(); if(b.dut.bus_req_o || b.dut.retire_o) throw std::runtime_error("HLT did not stay idle"); }
            ++count;
        }
    } catch(const std::exception &error) {
        throw std::runtime_error(label+": "+error.what());
    }
    if(!count) throw std::runtime_error("empty fixture run");
    std::cout<<"PASS: "<<count<<" physical-chip vectors, exact state/memory/next instruction\n";
}
static void software(Bench &b,const char *path) {
    std::ifstream input(path,std::ios::binary);
    std::vector<uint8_t> code((std::istreambuf_iterator<char>(input)),{});
    if(code.size()!=16) throw std::runtime_error("unexpected assembled startup length");
    b.reset();
    const uint8_t jump[]={0xea,0,0,0,0x10};
    for(unsigned i=0;i<5;++i) b.set(0xffff0+i,jump[i]);
    for(unsigned i=0;i<code.size();++i) b.set(0x10000+i,code[i]);
    const uint16_t ips[]={0,3,5,7,10,12,15,16};
    const uint8_t opcodes[]={0xea,0xb8,0x8e,0x8e,0xb8,0x8e,0xbc,0xf4};
    for(unsigned i=0;i<8;++i) {
        auto before=b.read(); auto start=physical(before[9],before[12]);
        b.retire();
        if(b.dut.ip_o!=ips[i] || !b.saw_fetch || b.first_fetch_address!=start ||
           b.first_fetch_byte!=opcodes[i])
            throw std::runtime_error("historical startup exact IP/next instruction mismatch");
    }
    auto r=b.read();
    if(r[0]!=0x3000 || r[4]!=200 || r[8]!=0x2000 || r[9]!=0x1000 ||
       r[10]!=0x3000 || r[11]!=0x2000 || !b.dut.halted_o || !b.writes.empty())
        throw std::runtime_error("historical startup final state mismatch");
    std::cout<<"PASS: Intel 1979 figure 2-63 startup, reset far jump and all exact instruction boundaries\n";
}
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc!=3) throw std::runtime_error("usage: runner --vectors file | --software file");
        Bench b;
        if(std::string(argv[1])=="--vectors") vectors(b,argv[2]);
        else if(std::string(argv[1])=="--software") software(b,argv[2]);
        else throw std::runtime_error("unknown test mode");
        b.dut.final();
    } catch(const std::exception &error) {std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1;}
    return 0;
}
