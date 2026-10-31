#include "Vintel_80286_segment_load.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <unordered_map>
#include <vector>

// Semantic type lists: pinned 86Box loadseg_2386. Transaction order follows
// read_descriptor/accessed-bit publication, with explicit functional A11.
struct Test {
    Vintel_80286_segment_load d;
    struct Transfer {uint32_t address;uint8_t value;bool write;};
    struct Packet {
        unsigned selector,base,limit,access,valid,fault,vector,error;
        bool operator==(const Packet& p) const {
            return selector==p.selector && base==p.base && limit==p.limit && access==p.access &&
                   valid==p.valid && fault==p.fault && vector==p.vector && error==p.error;
        }
    };
    std::unordered_map<uint32_t,uint8_t> memory;
    std::vector<Transfer> transfers;
    unsigned cycles=0,cases=0;
    uint32_t random=0x8028641;
    Packet packet() const {return {d.selector_o,d.base_o,d.limit_o,d.access_o,d.cache_valid_o,
                                   d.fault_o,d.fault_vector_o,d.fault_error_o};}
    void require(bool ok,const char* text) {if(!ok) throw std::runtime_error(text);}
    unsigned next() {random^=random<<13;random^=random>>17;random^=random<<5;return random;}
    void tick(bool ready) {
        const auto before=packet();
        d.clk=0; d.bus_ready_i=ready; d.bus_rdata_i=uint8_t(cycles^0xa5); d.eval();
        const bool request=d.bus_req_o,write=d.bus_write_o;
        const uint32_t address=d.bus_addr_o;
        const uint8_t data=d.bus_wdata_o;
        if(request && ready) {
            auto found=memory.find(address);
            require(found!=memory.end(),"descriptor transaction at an unexpected address");
            if(write) memory[address]=data; else d.bus_rdata_i=found->second;
            transfers.push_back({address,write?data:uint8_t(d.bus_rdata_i),write});
        }
        d.eval();d.clk=1;d.eval();d.clk=0;d.eval();++cycles;
        if(d.rst_n && request && !ready) {
            require(d.bus_req_o && d.bus_addr_o==address && bool(d.bus_write_o)==write,"stalled descriptor command changed");
            if(write) require(d.bus_wdata_o==data,"stalled access-byte data changed");
            require(!d.done_o,"completion escaped a stalled command");
        }
        if(d.rst_n && !d.done_o) require(packet()==before,"partial/new-request metadata escaped before completion");
    }
    void reset() {
        d.start_i=0;d.rst_n=0;d.eval();require(!d.bus_req_o,"reset did not suppress descriptor request");
        tick(false);tick(false);require(!d.busy_o && !d.done_o && packet()==Packet{},"descriptor reset state");
        d.rst_n=1;d.eval();
    }
    static unsigned vector_for(unsigned sel,unsigned cpl,bool stack,unsigned table_limit,bool ldt,unsigned rights) {
        if(sel/4==0) return stack?13:0;
        if(((sel/4)%2 && !ldt) || (sel/8)*8+7>table_limit) return 13;
        const unsigned kind=rights%32,dpl=(rights/32)%4,rpl=sel%4;
        bool allowed=false;
        if(stack) {
            switch(kind) {case 18:case 19:case 22:case 23:allowed=rpl==cpl && dpl==cpl;break;default:break;}
        } else {
            switch(kind) {
                case 16:case 17:case 18:case 19:case 20:case 21:case 22:case 23:case 26:case 27:
                    allowed=rpl<=dpl && cpl<=dpl;break;
                case 30:case 31:allowed=true;break;
                default:break;
            }
        }
        return !allowed?13:rights<128?(stack?12:11):0;
    }
    uint32_t prepare(unsigned selector,unsigned cpl,bool stack,unsigned table_limit,bool ldt,
                     uint32_t base,uint16_t limit,unsigned rights,uint32_t table_base=0x123400) {
        memory.clear();transfers.clear();
        d.selector_i=selector;d.cpl_i=cpl;d.stack_i=stack;d.ldt_valid_i=ldt;
        d.gdt_base_i=table_base;d.ldt_base_i=(table_base^0x654300)&0xffffff;
        d.gdt_limit_i=table_limit;d.ldt_limit_i=table_limit;
        const uint32_t address=((selector&4?d.ldt_base_i:d.gdt_base_i)+(selector/8)*8)&0xffffff;
        const uint8_t bytes[]={uint8_t(limit),uint8_t(limit>>8),uint8_t(base),uint8_t(base>>8),
                               uint8_t(base>>16),uint8_t(rights),uint8_t(next()),uint8_t(next())};
        for(unsigned i=0;i<8;++i) memory[(address+i)&0xffffff]=bytes[i];
        return address;
    }
    void perturb() {
        // All caller inputs, including selected table, are hostile after start.
        d.selector_i=next()&0xffff;d.cpl_i=next()&3;d.stack_i=next()&1;d.ldt_valid_i=next()&1;
        d.gdt_base_i=next()&0xffffff;d.ldt_base_i=next()&0xffffff;
        d.gdt_limit_i=next()&0xffff;d.ldt_limit_i=next()&0xffff;
        d.start_i=cycles%5==2;
    }
    void run_case(unsigned selector,unsigned cpl,bool stack,unsigned table_limit,bool ldt,
                  uint32_t base,uint16_t limit,unsigned rights,uint32_t table_base=0x123400) {
        require(!d.busy_o,"new case started before idle");
        const uint32_t address=prepare(selector,cpl,stack,table_limit,ldt,base,limit,rights,table_base);
        std::vector<Transfer> expected;
        const bool needed=selector/4!=0 && (!(selector&4) || ldt) && (selector/8)*8+7<=table_limit;
        const unsigned vector=vector_for(selector,cpl,stack,table_limit,ldt,rights);
        const bool valid=needed && !vector;
        if(needed) for(unsigned i=0;i<8;++i) expected.push_back({(address+i)&0xffffff,memory[(address+i)&0xffffff],false});
        if(valid) expected.push_back({(address+5)&0xffffff,uint8_t(rights|1),true});
        d.start_i=1;tick(false);d.start_i=0;
        bool complete=false;
        for(unsigned n=0;n<256 && !complete;++n) {perturb();tick(next()%4==0);complete=d.done_o;}
        d.start_i=0;require(complete && !d.busy_o,"descriptor completion timeout");
        const Packet expected_packet={selector,valid?base:0u,valid?unsigned(limit):0u,valid?rights:0u,
                                      unsigned(valid),unsigned(bool(vector)),vector,vector?selector&0xfffc:0u};
        require(packet()==expected_packet,"descriptor completion packet");
        require(transfers.size()==expected.size(),"descriptor transfer count");
        for(unsigned i=0;i<expected.size();++i)
            require(transfers[i].address==expected[i].address && transfers[i].value==expected[i].value &&
                    transfers[i].write==expected[i].write,"descriptor exact transfer/value/order");
        ++cases;
    }
    void run() {
        reset();
        for(unsigned rights=0;rights<256;++rights) for(unsigned cpl=0;cpl<4;++cpl)
        for(unsigned rpl=0;rpl<4;++rpl) for(bool stack:{false,true}) for(bool local:{false,true})
            run_case((local?4:8)+rpl,cpl,stack,0xffff,true,
                     (0xa50001^(rights*7919))&0xffffff,uint16_t(0xab01^(rights*239)),rights);
        for(unsigned sel=0;sel<4;++sel) for(bool stack:{false,true})
            run_case(sel,3,stack,0,false,0xffffff,0xffff,0xff);
        run_case(4,0,false,7,false,0x123456,0xffff,0x93);
        for(unsigned index:{1u,2u,0x123u,0x1fffu}) {
            const unsigned selector=index*8,last=index*8+7;
            run_case(selector,0,false,last-1,true,0xffffff,0xffff,0x92);
            run_case(selector,0,false,last,true,0xffffff,0xffff,0x92);
        }
        run_case(8,0,false,15,true,0xabcdef,0x1234,0x92,0xfffff4); // Physical wrap at byte 4.
        // Cancel before any traffic, after each read, before/after the write.
        for(unsigned cut=0;cut<=9;++cut) {
            prepare(8,0,false,15,true,0xabcdef,0x1234,0x92);d.start_i=1;tick(false);d.start_i=0;
            for(unsigned n=0;n<64 && transfers.size()<cut;++n) tick(true);
            require(transfers.size()==cut,"descriptor reset transfer cut missing");
            const auto accepted=memory;reset();require(memory==accepted,"reset rolled back descriptor writes");
            for(unsigned n=0;n<16;++n) {tick(true);require(!d.done_o && !d.bus_req_o,"canceled descriptor load completed later");}
            ++cases;
        }
        // Stall the accessed write specifically, retaining an older completion.
        run_case(8,0,false,15,true,0x102030,0x4050,0x93);
        prepare(8,0,false,15,true,0xabcdef,0x1234,0x92);d.start_i=1;tick(false);d.start_i=0;
        for(unsigned n=0;n<64 && !(d.bus_req_o && d.bus_write_o);++n) tick(true);
        require(d.bus_req_o && d.bus_write_o && transfers.size()==8,"accessed write phase missing");
        for(unsigned n=0;n<16;++n) {perturb();tick(false);}
        const auto accepted=memory;reset();require(memory==accepted,"stalled accessed write survived reset");
        for(unsigned n=0;n<16;++n) {tick(true);require(!d.done_o && !d.bus_req_o,"stale accessed-write completion");}
        ++cases;
        std::cout<<"PASS protected segment-load transactions: "<<cases
                 <<" cases, exact eight-byte reads/accessed writes, hostile inputs, stalls and reset cuts\n";
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {Test test;test.run();}
    catch(const std::exception& error) {std::cerr<<"FAIL: "<<error.what()<<'\n';return 1;}
    return 0;
}
