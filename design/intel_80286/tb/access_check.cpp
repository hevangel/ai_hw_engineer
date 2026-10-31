#include "Vintel_80286_access_check.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

// Independent interval arithmetic and Intel's enumerated allowed types.
static uint64_t cases=0;
static void sample(Vintel_80286_access_check& d,unsigned rights,unsigned limit,unsigned offset,
                   unsigned delta,unsigned operation,bool usable,bool stack) {
    unsigned low=0,high=limit;
    if (rights>=20 && rights<=23) { low=limit+1; high=65535; }
    bool permission=false;
    if (operation==0) {
        switch (rights) {
            case 16: case 17: case 18: case 19: case 20: case 21: case 22: case 23:
            case 26: case 27: case 30: case 31: permission=true; break;
            default: break;
        }
    } else if (operation==2) {
        switch (rights) {
            case 24: case 25: case 26: case 27: case 28: case 29: case 30: case 31: permission=true; break;
            default: break;
        }
    } else {
        switch (rights) { case 18: case 19: case 22: case 23: permission=true; break; default: break; }
    }
    const bool expected=usable && permission && offset>=low && offset+delta<=high;
    d.access_i=rights>>1; d.limit_i=limit; d.offset_i=offset; d.last_delta_i=delta;
    d.kind_i=operation; d.cache_valid_i=usable; d.stack_i=stack; d.eval();
    if (bool(d.allow_o)!=expected || bool(d.fault_o)==expected || d.fault_error_o ||
        d.fault_vector_o!=(expected?0:stack?12:13)) {
        std::cerr<<"access tuple rights="<<rights<<" limit="<<limit<<" offset="<<offset<<" delta="<<delta
                 <<" kind="<<operation<<" usable="<<usable<<" SS="<<stack<<'\n';
        throw std::runtime_error("cached access type/range/fault decision");
    }
    ++cases;
}

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Vintel_80286_access_check d;
        for (unsigned rights=0;rights<32;++rights) for (unsigned operation=0;operation<4;++operation)
            for (bool usable: {false,true}) for (bool stack: {false,true})
                for (unsigned limit: {0u,1u,0x7fffu,0xfffeu,0xffffu})
                    for (unsigned offset: {0u,1u,2u,0x7ffeu,0x7fffu,0x8000u,0xfffdu,0xfffeu,0xffffu})
                        for (unsigned delta: {0u,1u,2u,3u,7u,15u,0x7fffu,0x8000u,0xfffeu,0xffffu})
            sample(d,rights,limit,offset,delta,operation,usable,stack);
        // Every limit value, including strict expand-down equality, the first
        // permitted byte, FFFF+1 overflow and code conforming-bit independence.
        for (unsigned limit=0;limit<=65535;++limit) for (unsigned rights: {16u,18u,22u,28u})
            for (unsigned offset: {limit,(limit+1)&65535}) for (unsigned delta: {0u,1u})
                for (unsigned operation: {0u,2u}) sample(d,rights,limit,offset,delta,operation,true,true);
        uint32_t random=0x8028675;
        auto next=[&]() { random^=random<<13; random^=random>>17; random^=random<<5; return random; };
        for (unsigned n=0;n<16384;++n) {
            const unsigned rights=next()%32,limit=next()%65536,offset=next()%65536,delta=next()%65536,kind=next()%4;
            const bool usable=next()%2,stack=next()%2;
            sample(d,rights,limit,offset,delta,kind,usable,stack);
        }
        std::cout<<"PASS: "<<cases<<" cached-access cases, all limit boundaries, permission kinds and nonwrapping spans\n";
    } catch (const std::exception& error) { std::cerr<<"FAIL: "<<error.what()<<'\n'; return 1; }
}
