#include "Vintel_80286_code_load.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <unordered_map>
#include <vector>

// Expected semantics are Intel Appendix B's enumerated JMP/CALL checks.
// Exact byte traffic is the explicitly documented A11/A13 functional contract.
struct Test {
    Vintel_80286_code_load d;
    struct Transfer { uint32_t address; uint8_t value; bool write; };
    struct Packet {
        unsigned request_selector,request_offset,selector,base,limit,access,valid,special,fault,vector,error;
        uint64_t descriptor;
        bool operator==(const Packet& p) const {
            return request_selector==p.request_selector && request_offset==p.request_offset &&
                selector==p.selector && base==p.base && limit==p.limit && access==p.access &&
                valid==p.valid && special==p.special && fault==p.fault && vector==p.vector &&
                error==p.error && descriptor==p.descriptor;
        }
    };
    std::unordered_map<uint32_t,uint8_t> memory;
    std::vector<Transfer> transfers;
    unsigned cycles=0,cases=0;
    uint32_t random=0x8028663;
    Packet packet() const { return {d.request_selector_o,d.request_offset_o,d.selector_o,d.base_o,d.limit_o,
        d.access_o,d.cache_valid_o,d.special_o,d.fault_o,d.fault_vector_o,d.fault_error_o,d.special_descriptor_o}; }
    static void require(bool ok,const char* message) { if (!ok) throw std::runtime_error(message); }
    unsigned next() { random^=random<<13; random^=random>>17; random^=random<<5; return random; }
    void tick(bool ready) {
        const auto before=packet();
        d.clk=0; d.bus_ready_i=ready; d.bus_rdata_i=uint8_t(cycles^0xa5); d.eval();
        const bool request=d.bus_req_o,write=d.bus_write_o;
        const uint32_t address=d.bus_addr_o; const uint8_t data=d.bus_wdata_o;
        if (request && ready) {
            auto found=memory.find(address);
            require(found!=memory.end(),"CS descriptor transaction at unexpected address");
            if (write) memory[address]=data; else d.bus_rdata_i=found->second;
            transfers.push_back({address,write?data:uint8_t(d.bus_rdata_i),write});
        }
        d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); ++cycles;
        if (d.rst_n && request && !ready) {
            require(d.bus_req_o && d.bus_addr_o==address && bool(d.bus_write_o)==write,"CS stalled command changed");
            if (write) require(d.bus_wdata_o==data,"CS stalled accessed-byte data changed");
            require(!d.done_o,"CS completion escaped a stalled command");
        }
        if (d.rst_n && !d.done_o) require(packet()==before,"CS partial/new-request result escaped before completion");
    }
    void reset() {
        d.start_i=0; d.rst_n=0; d.eval(); require(!d.bus_req_o,"CS reset did not suppress request");
        tick(false); tick(false);
        require(!d.busy_o && !d.done_o && packet()==Packet{},"CS reset state");
        d.rst_n=1; d.eval();
    }
    static Packet reference(unsigned sel,unsigned ip,unsigned cpl,bool call,bool stack_ok,
                            unsigned table_limit,bool ldt,uint32_t base,uint16_t limit,unsigned rights) {
        Packet p{}; p.request_selector=sel; p.request_offset=ip;
        const unsigned relative=(sel/8)*8,kind=rights%32,dpl=(rights/32)%4,rpl=sel%4;
        bool allowed=false;
        if (sel/4==0) { p.fault=1; p.vector=13; }
        else if (((sel/4)%2 && !ldt) || relative+7>table_limit) { p.fault=1; p.vector=13; p.error=(sel/4)*4; }
        else if (kind<16) { p.special=1; p.descriptor=(uint64_t(rights)<<40)|(uint64_t(base)<<16)|limit; }
        else {
            switch (kind) {
                case 24: case 25: case 26: case 27: allowed=rpl<=cpl && dpl==cpl; break;
                case 28: case 29: case 30: case 31: allowed=dpl<=cpl; break;
                default: break;
            }
            if (!allowed) { p.fault=1; p.vector=13; p.error=(sel/4)*4; }
            else if (rights<128) { p.fault=1; p.vector=11; p.error=(sel/4)*4; }
            else if (call && !stack_ok) { p.fault=1; p.vector=12; }
            else if (ip>limit) { p.fault=1; p.vector=13; }
            else { p.valid=1; p.selector=(sel/4)*4+cpl; p.base=base; p.limit=limit; p.access=rights; }
        }
        return p;
    }
    uint32_t prepare(unsigned sel,unsigned ip,unsigned cpl,bool call,bool stack_ok,unsigned table_limit,
                     bool ldt,uint32_t base,uint16_t limit,unsigned rights,uint32_t table_base=0x123400) {
        memory.clear(); transfers.clear();
        d.selector_i=sel; d.offset_i=ip; d.cpl_i=cpl; d.call_i=call; d.gate_call_i=0;
        d.stack_ok_i=stack_ok; d.ldt_valid_i=ldt;
        d.gdt_base_i=table_base; d.ldt_base_i=(table_base^0x654300)&0xffffff;
        d.gdt_limit_i=table_limit; d.ldt_limit_i=table_limit;
        const uint32_t address=((sel&4?d.ldt_base_i:d.gdt_base_i)+(sel/8)*8)&0xffffff;
        const uint8_t image[]={uint8_t(limit),uint8_t(limit>>8),uint8_t(base),uint8_t(base>>8),
            uint8_t(base>>16),uint8_t(rights),uint8_t(next()),uint8_t(next())};
        for (unsigned i=0;i<8;++i) memory[(address+i)&0xffffff]=image[i];
        return address;
    }
    void perturb() {
        d.selector_i=next()&0xffff; d.offset_i=next()&0xffff; d.cpl_i=next()&3;
        d.call_i=next()&1; d.gate_call_i=0; d.stack_ok_i=next()&1; d.ldt_valid_i=next()&1;
        d.gdt_base_i=next()&0xffffff; d.ldt_base_i=next()&0xffffff;
        d.gdt_limit_i=next()&0xffff; d.ldt_limit_i=next()&0xffff;
        d.start_i=cycles%5==2;
    }
    void run_case(unsigned sel,unsigned ip,unsigned cpl,bool call,bool stack_ok,unsigned table_limit,
                  bool ldt,uint32_t base,uint16_t limit,unsigned rights,uint32_t table_base=0x123400) {
        require(!d.busy_o,"CS request started before idle");
        const auto expected_packet=reference(sel,ip,cpl,call,stack_ok,table_limit,ldt,base,limit,rights);
        const uint32_t address=prepare(sel,ip,cpl,call,stack_ok,table_limit,ldt,base,limit,rights,table_base);
        const bool needed=sel/4!=0 && (!(sel&4) || ldt) && (sel/8)*8+7<=table_limit;
        std::vector<Transfer> expected;
        if (needed) for (unsigned i=0;i<8;++i) expected.push_back({(address+i)&0xffffff,memory[(address+i)&0xffffff],false});
        if (expected_packet.valid) expected.push_back({(address+5)&0xffffff,uint8_t(rights|1),true});
        d.start_i=1; tick(false); d.start_i=0;
        bool complete=false;
        for (unsigned n=0;n<256 && !complete;++n) { perturb(); tick(next()%4==0); complete=d.done_o; }
        d.start_i=0;
        require(complete && !d.busy_o,"CS descriptor completion timeout");
        require(packet()==expected_packet,"CS completion packet/priority/request snapshot");
        require(transfers.size()==expected.size(),"CS descriptor transfer count");
        for (unsigned i=0;i<expected.size();++i) require(transfers[i].address==expected[i].address &&
            transfers[i].value==expected[i].value && transfers[i].write==expected[i].write,"CS descriptor exact transfer/value/order");
        ++cases;
    }
    void run() {
        reset();
        for (unsigned rights=0;rights<256;++rights) for (unsigned cpl=0;cpl<4;++cpl)
            for (unsigned rpl=0;rpl<4;++rpl) for (bool call: {false,true}) for (bool stack_ok: {false,true})
                for (unsigned ip: {0u,0xabcdu,0xabceu}) for (bool local: {false,true})
            run_case((local?4:8)+rpl,ip,cpl,call,stack_ok,0xffff,true,
                (0xa50001^(rights*7919))&0xffffff,0xabcd,rights);
        for (unsigned sel=0;sel<4;++sel) run_case(sel,0xffff,3,true,false,0,false,0xffffff,0,0xff);
        run_case(4,0,0,false,true,7,false,0x123456,0xffff,0x9a);
        for (unsigned index: {1u,2u,0x123u,0x1fffu}) {
            const unsigned sel=index*8,last=index*8+7;
            run_case(sel,0,0,false,true,last-1,true,0xffffff,0xffff,0x9a);
            run_case(sel,0xffff,0,true,true,last,true,0xffffff,0xffff,0x9a);
        }
        run_case(8,0x1234,0,false,true,15,true,0xabcdef,0x1234,0x9a,0xfffff4);
        for (unsigned cut=0;cut<=9;++cut) {
            prepare(8,0x1234,0,false,true,15,true,0xabcdef,0x1234,0x9a);
            d.start_i=1; tick(false); d.start_i=0;
            for (unsigned n=0;n<64 && transfers.size()<cut;++n) tick(true);
            require(transfers.size()==cut,"CS reset transfer cut missing");
            const auto accepted=memory; reset(); require(memory==accepted,"CS reset rolled back accepted writes");
            for (unsigned n=0;n<16;++n) { tick(true); require(!d.done_o && !d.bus_req_o,"canceled CS load completed later"); }
            ++cases;
        }
        // Hold a write with an older packet, then cancel it through reset.
        run_case(8,0x1234,0,false,true,15,true,0x102030,0x4050,0x9b);
        prepare(16,0x5678,0,true,true,23,true,0xabcdef,0x9876,0x9a);
        d.start_i=1; tick(false); d.start_i=0;
        for (unsigned n=0;n<64 && !(d.bus_req_o && d.bus_write_o);++n) tick(true);
        require(d.bus_req_o && d.bus_write_o && transfers.size()==8,"CS accessed-write phase missing");
        for (unsigned n=0;n<16;++n) { perturb(); tick(false); }
        const auto accepted=memory; reset(); require(memory==accepted,"CS stalled write survived reset");
        for (unsigned n=0;n<16;++n) { tick(true); require(!d.done_o && !d.bus_req_o,"stale CS accessed-write completion"); }
        ++cases;
        std::cout<<"PASS: "<<cases<<" protected CS load transactions, exact reads/writes, special/fault packets, hostile inputs and reset cuts\n";
    }
};

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try { Test test; test.run(); }
    catch (const std::exception& error) { std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1; }
    return 0;
}
