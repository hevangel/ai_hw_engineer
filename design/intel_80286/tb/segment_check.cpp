#include "Vintel_80286_segment_check.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

// Independent accepted-type lists from 86Box x86seg.c loadseg_2386,
// 1db9ae4cc910b0b7e6e9b49995910b0cc19747a0. Layout: pinned PCjs segx86.js.
struct Test {
    Vintel_80286_segment_check d;
    unsigned cases=0;
    void require(bool ok,const char* message) {
        if(!ok) throw std::runtime_error(message);
    }
    void check(uint16_t selector,unsigned cpl,bool stack,uint16_t table_limit,bool ldt,bool available,
               uint32_t base,uint16_t limit,unsigned rights,bool needed,bool done,bool valid,unsigned vector) {
        d.selector_i=selector; d.cpl_i=cpl; d.stack_i=stack; d.table_limit_i=table_limit;
        d.ldt_valid_i=ldt; d.descriptor_valid_i=available;
        d.descriptor_i=uint64_t(limit)+uint64_t(base)*65536+(uint64_t(rights)<<40);
        d.eval(); ++cases;
        if(d.fault_vector_o!=vector || bool(d.cache_valid_o)!=valid) {
            std::cerr<<"case "<<cases<<" selector="<<std::hex<<selector<<" access="<<rights
                     <<" cpl="<<cpl<<" stack="<<stack<<std::dec<<'\n';
        }
        require(d.descriptor_offset_o==(selector/8)*8,"descriptor offset");
        require(bool(d.descriptor_needed_o)==needed && bool(d.checked_o)==done,"descriptor request/availability");
        require(bool(d.cache_valid_o)==valid && bool(d.fault_o)==bool(vector),"load validity/fault");
        require(d.fault_vector_o==vector,"fault priority/vector");
        require(d.fault_error_o==(vector?selector&0xfffc:0),"selector error code");
        require(d.base_o==(valid?base:0) && d.limit_o==(valid?limit:0),"little-endian base/limit");
        require(d.access_o==(valid?rights:0) && d.accessed_value_o==(valid?rights|1:0),"raw/accessed bytes");
        const unsigned descriptor_class=((rights>>4)&1u)<<2 |
                                        ((rights>>3)&1u)<<1 | ((rights>>1)&1u);
        require(d.descriptor_class_o==(available?descriptor_class:0),
                "fault-classification descriptor type");
    }
    void run() {
        for(unsigned rights=0;rights<256;++rights) for(unsigned cpl=0;cpl<4;++cpl)
        for(unsigned rpl=0;rpl<4;++rpl) for(bool stack:{false,true}) for(bool local:{false,true}) {
            const unsigned kind=rights%32, dpl=(rights/32)%4;
            bool allowed=false;
            if(stack) {
                switch(kind) {case 18:case 19:case 22:case 23: allowed=cpl==dpl && rpl==cpl; break; default:break;}
            } else {
                switch(kind) {
                    case 16:case 17:case 18:case 19:case 20:case 21:case 22:case 23:case 26:case 27:
                        allowed=cpl<=dpl && rpl<=dpl; break;
                    case 30:case 31:allowed=true; break;
                    default:break;
                }
            }
            unsigned vector=!allowed?13:rights<128?(stack?12:11):0;
            check(uint16_t((local?4:8)+rpl),cpl,stack,0xffff,true,true,
                  0x12ab34^(rights*7919),uint16_t(0x7f01^(rights*239)),rights,true,true,!vector,vector);
        }
        for(unsigned rpl=0;rpl<4;++rpl) for(bool stack:{false,true})
            check(uint16_t(rpl),3,stack,0,false,false,0xffffff,0xffff,0xff,false,true,false,stack?13:0);
        // LDT index zero is valid; invalid/missing LDT and wait for its data
        // are distinguished from the GDT null-selector case.
        check(4,0,false,7,true,true,0xffffff,0,0x93,true,true,true,0);
        check(4,0,false,7,false,true,0xffffff,0,0x93,false,true,false,13);
        check(4,0,false,7,true,false,0xffffff,0,0x93,true,false,false,0);
        for(unsigned index:{1u,2u,0x123u,0x1fffu}) {
            const uint16_t selector=uint16_t(index*8), last=uint16_t(index*8+7);
            check(selector,0,false,uint16_t(last-1),true,true,0xffffff,0xffff,0x93,false,true,false,13);
            check(selector,0,false,last,true,true,0xffffff,0xffff,0x93,true,true,true,0);
            check(selector,0,false,last,true,false,0xffffff,0xffff,0x93,true,false,false,0);
        }
        // Explicit security edges: conforming readable code bypasses ordinary
        // data privilege comparison; invalid/privilege failure precedes NP.
        check(11,3,false,15,true,true,0xabcdef,0xffff,0x9e,true,true,true,0);
        check(11,3,false,15,true,true,0xabcdef,0xffff,0x1a,true,true,false,13);
        check(8,0,false,15,true,true,0,0,0x13,true,true,false,11);
        check(8,0,true,15,true,true,0,0,0x13,true,true,false,12);
        check(9,0,true,15,true,true,0,0,0x13,true,true,false,13);
        check(8,0,false,15,true,true,0,0,0x00,true,true,false,13);
        std::cout<<"PASS protected segment-check component: "<<cases<<" source-derived cases\n";
    }
};
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {Test test;test.run();}
    catch(const std::exception& error) {std::cerr<<"FAIL: "<<error.what()<<'\n';return 1;}
    return 0;
}
