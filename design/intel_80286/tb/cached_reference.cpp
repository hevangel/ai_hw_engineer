// Independent interval/type-list reference from Intel 210498-005 7.4/11.2.2.
// Retained CS fetch policy: pinned MAME actual fetch(), documented as A14.
#include "Vintel_80286_cached_reference.h"
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>

struct Cache { uint32_t base; uint16_t limit; uint8_t access; bool usable; };
static uint32_t random_state=0x286ca14;
static uint32_t random_value() {
    random_state^=random_state<<13; random_state^=random_state>>17;
    random_state^=random_state<<5; return random_state;
}
static bool reference(const Cache& cache,unsigned role,unsigned kind,bool trusted,
                      unsigned offset,unsigned delta) {
    if (!cache.usable) return false;
    const unsigned end=offset+delta;
    if (trusted && role==1 && kind==2) return end<=cache.limit;
    const unsigned type=cache.access&31;
    bool permitted=false;
    if (kind==0) {
        switch (type) {
            case 16: case 17: case 18: case 19: case 20: case 21:
            case 22: case 23: case 26: case 27: case 30: case 31: permitted=true;
        }
    } else if (kind==1 || kind==3) {
        permitted=type==18 || type==19 || type==22 || type==23;
    } else permitted=type>=24 && type<=31;
    const unsigned low=type>=20 && type<=23 ? unsigned(cache.limit)+1 : 0;
    const unsigned high=type>=20 && type<=23 ? 65535 : cache.limit;
    return permitted && offset>=low && end<=high;
}

int main() {
    try {
        Vintel_80286_cached_reference d;
        unsigned checks=0;
        auto test=[&](const std::array<Cache,4>& bank,unsigned role,unsigned kind,
                      bool trusted,unsigned offset,unsigned delta) {
            d.bases_i[0]=0; d.bases_i[1]=0; d.bases_i[2]=0;
            d.limits_i=0; d.access_i=0; d.usable_i=0;
            // Bitwise packing independently crosses both 32-bit boundaries.
            for (unsigned i=0;i<4;++i) {
                for (unsigned bit=0;bit<24;++bit) if (bank[i].base&(1u<<bit))
                    d.bases_i[(i*24+bit)/32]|=1u<<((i*24+bit)%32);
                d.limits_i|=uint64_t(bank[i].limit)<<(i*16);
                d.access_i|=uint32_t(bank[i].access)<<(i*8);
                d.usable_i|=unsigned(bank[i].usable)<<i;
            }
            d.role_i=role; d.kind_i=kind; d.trusted_cs_i=trusted;
            d.offset_i=offset; d.last_delta_i=delta; d.eval();
            const bool allowed=reference(bank[role],role,kind,trusted,offset,delta);
            const unsigned address=allowed ? (bank[role].base+offset)&0xffffff : 0;
            if (d.allow_o!=allowed || d.fault_o==allowed || d.physical_o!=address ||
                d.fault_error_o || d.fault_vector_o!=(allowed?0:role==2?12:13))
                throw std::runtime_error("cache routing/type/span/trusted-CS/address mismatch at case "+
                                         std::to_string(checks));
            ++checks;
        };
        const std::array<std::array<unsigned,3>,12> ranges={{{65535,0,65535},{0,0,0},
            {0,1,0},{65535,65535,0},{65535,65535,1},{32767,32767,0},
            {32767,32768,0},{32767,32768,32767},{32767,32768,32768},
            {65534,65535,0},{65535,0,0},{1,0,2}}};
        for (unsigned raw=0;raw<256;++raw) for (unsigned role=0;role<4;++role)
            for (unsigned kind=0;kind<4;++kind) for (bool usable:{false,true})
                for (bool trusted:{false,true}) for (const auto& range:ranges) {
            std::array<Cache,4> bank={{{0x012345,0,0,false},{0x456789,1,0xff,false},
                                      {0x89abcd,65535,0x93,true},{0xfedcba,32767,0x9b,true}}};
            bank[role].access=uint8_t(raw); bank[role].usable=usable;
            bank[role].limit=uint16_t(range[0]);
            test(bank,role,kind,trusted,range[1],range[2]);
        }
        // Every selected base bit, carry across each byte, and modulo-24 wrap.
        for (unsigned role=0;role<4;++role) for (unsigned bit=0;bit<24;++bit)
            for (unsigned offset:{0u,1u,255u,256u,65535u}) {
            std::array<Cache,4> bank;
            for (auto& cache:bank) cache={0,65535,0x93,true};
            bank[role].base=1u<<bit; test(bank,role,0,false,offset,0);
            bank[role].base=0xffffff; test(bank,role,0,false,offset,0);
        }
        // Aliased bases must not alias usability, access rights, limits or #SS.
        for (unsigned i=0;i<200000;++i) {
            std::array<Cache,4> bank;
            for (auto& cache:bank) cache={random_value()&0xffffff,uint16_t(random_value()),
                                         uint8_t(random_value()),bool(random_value()&1)};
            if (i&1) for (auto& cache:bank) cache.base=0x654321;
            test(bank,random_value()%4,random_value()%4,random_value()&1,
                 random_value()&65535,random_value()&65535);
        }
        std::cout<<"PASS: "<<checks<<" cache-bank references, explicit roles, inherited-CS fetch, exact spans and 24-bit addresses\n";
    } catch (const std::exception& e) {
        std::cerr<<"FAIL: "<<e.what()<<'\n'; return 1;
    }
}
