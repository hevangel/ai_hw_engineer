#include "Vintel_80286_code_check.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

static void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

// Intel Appendix B's enumerated legal code types and exception ordering;
// arithmetic decoding keeps this reference independent of the RTL bit tests.
static unsigned cases=0;
static void sample(Vintel_80286_code_check& d) {
    const unsigned sel=d.selector_i, relative=(sel/8)*8, rights=unsigned(d.descriptor_i>>40);
    const unsigned kind=rights%32, privilege=(rights/32)%4, requested=sel%4;
    bool needed=false, done=true, valid=false, special=false, fault=false, allowed=false;
    unsigned vector=0,error=0;
    if (sel/4==0) { fault=true; vector=13; }
    else if (((sel/4)%2 && !d.ldt_valid_i) || relative+7>d.table_limit_i) {
        fault=true; vector=13; error=(sel/4)*4;
    } else {
        needed=true; done=d.descriptor_valid_i;
        if (done) {
            switch (kind) {
                case 24: case 25: case 26: case 27:
                    allowed=d.gate_call_i ? privilege<=d.cpl_i :
                        requested<=d.cpl_i && privilege==d.cpl_i; break;
                case 28: case 29: case 30: case 31: allowed=privilege<=d.cpl_i; break;
                default: break;
            }
            if (kind<16) special=true;
            else if (!allowed) { fault=true; vector=13; error=(sel/4)*4; }
            else if (rights<128) { fault=true; vector=11; error=(sel/4)*4; }
            else if (d.call_i && !d.stack_ok_i) { fault=true; vector=12; }
            else if (d.offset_i>uint16_t(d.descriptor_i)) { fault=true; vector=13; }
            else valid=true;
        }
    }
    d.eval();
    check(d.descriptor_offset_o==relative && bool(d.descriptor_needed_o)==needed && bool(d.checked_o)==done,"code descriptor request/bounds");
    check(bool(d.cache_valid_o)==valid && bool(d.special_o)==special && bool(d.fault_o)==fault,"code result classification");
    check(d.fault_vector_o==vector && d.fault_error_o==error,"code exception priority/error");
    if (valid) {
        const unsigned expected_rpl=d.gate_call_i && kind>=24 && kind<=27 ? privilege : d.cpl_i;
        check(d.selector_o==(sel/4)*4+expected_rpl,"CS selector RPL normalization");
        check(d.base_o==uint32_t((d.descriptor_i/65536)&0xffffff) && d.limit_o==uint16_t(d.descriptor_i),"code cache byte layout");
        check(d.access_o==rights && d.accessed_value_o==(rights|1),"code accessed-byte image");
    } else check(!d.selector_o && !d.base_o && !d.limit_o && !d.access_o && !d.accessed_value_o,"invalid code metadata escaped");
    ++cases;
}

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Vintel_80286_code_check d;
        d.table_limit_i=0xffff; d.ldt_valid_i=1; d.descriptor_valid_i=1;
        for (unsigned rights=0;rights<256;++rights) for (unsigned cpl=0;cpl<4;++cpl)
            for (unsigned rpl=0;rpl<4;++rpl) for (bool call: {false,true})
                for (bool gate_call: {false,true})
                for (bool stack_ok: {false,true}) for (unsigned ip: {0u,0xabcdu,0xabceu}) {
            d.selector_i=uint16_t(0x1234+rpl); d.cpl_i=cpl; d.call_i=call;
            d.gate_call_i=gate_call; d.stack_ok_i=stack_ok;
            d.offset_i=ip; d.descriptor_i=(uint64_t(rights)<<40)|0x123456abcdULL; sample(d);
        }
        // GDT null versus LDT index zero, inclusive final descriptor byte,
        // arbitrary descriptor contents while unavailable, and LDT usability.
        for (unsigned sel: {0u,1u,2u,3u,4u,5u,6u,7u,8u,0xfff8u,0xffffu})
            for (unsigned limit: {0u,6u,7u,14u,15u,0xfffeu,0xffffu})
                for (bool ldt: {false,true}) for (bool available: {false,true}) {
            d.selector_i=sel; d.table_limit_i=limit; d.ldt_valid_i=ldt; d.descriptor_valid_i=available;
            d.cpl_i=3; d.call_i=0; d.gate_call_i=0; d.stack_ok_i=0; d.offset_i=0xffff;
            d.descriptor_i=available?0xfa123456ffffULL:0x001234560000ULL; sample(d);
        }
        std::cout<<"PASS: "<<cases<<" ordinary protected CS check cases, deferred system types and exact exception priority\n";
    } catch (const std::exception& error) {
        std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1;
    }
}
