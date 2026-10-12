#include "Vintel_8086.h"
#include "Vintel_8086___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdlib>
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
    bool request(){return dut.bus_req_o;}
    void seed_queue(const std::vector<std::pair<uint32_t,uint8_t>> &){ }
    unsigned acknowledgements=0;
    unsigned data_reads=0,esc_events=0;
    uint8_t escaped_opcode=0;
    uint32_t escaped_address=0;
    void tick(bool stall=false) {
        dut.clk=0; dut.bus_ready_i=!stall;
        dut.eval();
        uint32_t address=dut.bus_addr_o;
        dut.bus_rdata_i=dut.bus_intack_o ? 0x20 : dut.bus_io_o ? 65535 : memory[address] | (uint16_t(memory[(address+1)&0xfffff])<<8);
        dut.eval();
        if (dut.bus_req_o && dut.bus_ready_i) {
            if(!dut.bus_fetch_o && !dut.bus_write_o && !dut.bus_intack_o)++data_reads;
            if(dut.bus_intack_o) {
                if(!dut.lock_o) throw std::runtime_error("interrupt acknowledge not locked");
                ++acknowledgements;
            }
            if (dut.bus_write_o) {
                for(unsigned lane=0;lane<2;++lane) if(dut.bus_be_o&(1<<lane)) {
                    auto selected=(address+lane)&0xfffff;
                    uint8_t value=uint8_t(dut.bus_wdata_o>>(8*lane));
                    if(!dut.bus_io_o) {set(selected,value); writes[selected]=value;}
                    ordered_writes.emplace_back(selected|(dut.bus_io_o ? 1<<20:0),value);
                }
            } else if (dut.bus_fetch_o) {
                uint32_t selected=(address+(dut.bus_be_o==2))&0xfffff;
                if(!saw_fetch) {first_fetch_address=selected; first_fetch_byte=memory[selected];}
                fetch_address=selected; fetch_byte=memory[selected]; saw_fetch=true;
            }
        }
        dut.clk=1; dut.eval(); ++cycles;
        if(dut.esc_valid_o){++esc_events;escaped_opcode=dut.esc_opcode_o;escaped_address=dut.esc_address_o;}
    }
    void set(uint32_t address,uint8_t value) {
        address&=0xfffff; memory[address]=value; touched.push_back(address);
    }
    void reset() {
        for (auto address:touched) memory[address]=0;
        touched.clear(); writes.clear(); ordered_writes.clear(); cycles=0; saw_fetch=false; acknowledgements=0;data_reads=esc_events=0;
        dut.intr_i=0; dut.nmi_i=0; dut.hold_i=0; dut.test_n_i=0;
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
    void host_registers(const Registers &r) {
        for(int i=0;i<8;++i) dut.rootp->intel_8086__DOT__gpr[i]=r[i];
        for(int i=0;i<4;++i) dut.rootp->intel_8086__DOT__seg[i]=r[8+i];
        dut.eval();
    }
    void retire() {
        saw_fetch=false;
        for (unsigned step=0;step<10000;++step) {
            // Deterministic ready backpressure affects every instruction family.
            tick((cycles%7)<3);
            if(dut.fault_o) throw std::runtime_error("unexpected fault");
            if(dut.retire_o) return;
        }
        throw std::runtime_error("retirement watchdog");
    }
};
#include "tb_vectors_common.hpp"
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
#include "tb_control.hpp"
#include "tb_dos.hpp"
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc!=3) throw std::runtime_error("usage: runner --vectors file | --software file");
        Bench b;
        if(std::string(argv[1])=="--vectors") vectors(b,argv[2]);
        else if(std::string(argv[1])=="--software") software(b,argv[2]);
        else if(std::string(argv[1])=="--control") control(b);
        else if(std::string(argv[1])=="--debug") debug_software(b,argv[2]);
        else throw std::runtime_error("unknown test mode");
        b.dut.final();
    } catch(const std::exception &error) {std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1;}
    return 0;
}
