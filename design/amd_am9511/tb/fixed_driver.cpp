#include "Vamd_am9511_fixed.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
extern "C" {
#include "ova.h"
}

static uint64_t cases=0, checks=0, external_compares=0, adapter_differences=0, rejected_external=0;
static void check(bool ok,const char* why) {
    ++checks; if(!ok){std::fprintf(stderr,"FAIL case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}
}
static void tick(Vamd_am9511_fixed& d){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
static std::array<unsigned char,4> bytes(uint32_t x){return {uint8_t(x),uint8_t(x>>8),uint8_t(x>>16),uint8_t(x>>24)};}
static uint32_t word(const std::array<unsigned char,4>& x){return uint32_t(x[0])|(uint32_t(x[1])<<8)|(uint32_t(x[2])<<16)|(uint32_t(x[3])<<24);}
struct Expected {uint32_t result; uint8_t status,mask; bool defined;};

// Independent oracle: immutable ova.c supplies byte arithmetic. A separate
// wide-integer calculation pins primary-manual error/result differences.
// Never read RTL to generate or adjust this oracle.
static Expected oracle(bool single,unsigned op,uint32_t a,uint32_t b){
    unsigned n=single?16:32;
    uint64_t limit=uint64_t(1)<<n, mask=limit-1, min=limit/2;
    a&=mask;b&=mask;
    int64_t sa=(a&min)?int64_t(a)-int64_t(limit):a;
    int64_t sb=(b&min)?int64_t(b)-int64_t(limit):b;
    uint32_t r=0; unsigned error=0; bool carry=false,defined=true;
    int64_t low=-int64_t(min), high=int64_t(min)-1;
    switch(op){
    case 0: {int64_t v=sa+sb;r=(uint64_t(a)+b)&mask;carry=uint64_t(a)+b>=limit;error=v<low||v>high;break;}
    case 1: {int64_t v=sb-sa;r=(uint64_t(b)-a)&mask;carry=b<a;error=a==min||v<low||v>high;break;}
    case 2: case 3:
        if(a==min||b==min){r=min;error=1;defined=single||op==2;}
        else {uint64_t p=uint64_t(sa*sb),upper=(p>>n)&mask;r=(op==3?upper:p)&mask;error=op==2&&upper!=0;}
        break;
    case 4:
        if(a==0){r=b;error=8;}
        else if(!single&&(a==min||b==min)){r=0;error=1;defined=false;}
        else r=uint64_t(sb/sa)&mask;
        break;
    case 5:r=(uint64_t(0)-a)&mask;error=a==min;break;
    default:std::abort();
    }
    auto aa=bytes(a), bb=bytes(b);std::array<unsigned char,4> rr{};
    unsigned ext_error=0;bool ext_carry=false;
    // Upstream add64 aliases its inputs in mul32/cm64; add32's carry path
    // overwrites an input before using it. Reject that whole double-multiply
    // implementation, rather than blessing arbitrary divergent results.
    // sub16 also spuriously asserts borrow for a minimum-negative minuend;
    // this propagates into sub32 across either 16-bit half.
    bool reliable= !((op==2||op==3)&&!single) &&
        !(op==1&&((b&0xffff)==0x8000 || (!single&&
            ((b>>16)==0x8000 || ((b&0xffff)<(a&0xffff)&&(b>>16)==0x8001)))));
    if(defined&&reliable){
        switch(op){
        case 0:ext_carry=single?add16(bb.data(),aa.data(),rr.data()):add32(bb.data(),aa.data(),rr.data());
               ext_error=single?oadd16(bb.data(),aa.data(),rr.data()):oadd32(bb.data(),aa.data(),rr.data());break;
        case 1:ext_carry=single?sub16(bb.data(),aa.data(),rr.data()):sub32(bb.data(),aa.data(),rr.data());
               ext_error=single?osub16(bb.data(),aa.data(),rr.data()):osub32(bb.data(),aa.data(),rr.data());break;
        case 2:ext_error=single?mull16(bb.data(),aa.data(),rr.data()):mull32(bb.data(),aa.data(),rr.data());break;
        case 3:ext_error=single?mulu16(bb.data(),aa.data(),rr.data()):mulu32(bb.data(),aa.data(),rr.data());break;
        case 4:ext_error=(single?div16(bb.data(),aa.data(),rr.data()):div32(bb.data(),aa.data(),rr.data()))?8:0;break;
        case 5:ext_error=single?cm16(aa.data(),rr.data()):cm32(aa.data(),rr.data());break;
        }
        ++external_compares;
        if((word(rr)&mask)!=r || ext_error!=error || ext_carry!=carry){
            // Enumerated manufacturer adapters: divide zero returns B; forced
            // subtract-min overflow; signed discarded upper multiplication;
            // upstream double-multiply typo in second minimum-negative test.
            bool permitted=(op==4&&a==0) || (op==1&&a==min) ||
                (op==2&&(sa*sb<0 || a==min || b==min));
            if(!permitted){std::fprintf(stderr,"ORACLE disagreement single=%d op=%u a=%08x b=%08x r=%08x ext=%08x e=%u ext_e=%u c=%d ext_c=%d\n",single,op,a,b,r,word(rr),error,ext_error,carry,ext_carry);std::exit(1);}
            ++adapter_differences;
        }
    } else if(defined) ++rejected_external;
    uint8_t status=uint8_t(((r&min)?0x40:0)|(r==0?0x20:0)|(error<<1)|carry);
    return {r,status,uint8_t(defined?0x7f:0x1f),defined};
}
static void execute(Vamd_am9511_fixed& d,bool single,unsigned op,uint32_t a,uint32_t b){
    ++cases; auto expected=oracle(single,op,a,b);
    check(!d.busy_o&&!d.done_o,"idle before start");
    d.single_i=single;d.operation_i=op;d.a_i=a;d.b_i=b;d.start_i=1;tick(d);
    unsigned cycles=0;
    while(!d.done_o){
        check(d.busy_o,"busy until completion");
        // Deliberately keep START asserted and change every payload pin while
        // the unit is busy. Only its accepted command may affect computation.
        d.single_i=!single;d.operation_i=7;d.a_i=~a;d.b_i=~b;tick(d);
        check(++cycles<=32,"bounded completion");
    }
    check(d.result_defined_o==expected.defined,"documented-result validity");
    if(expected.defined&&d.result_o!=expected.result){std::fprintf(stderr,"op=%u single=%d a=%08x b=%08x actual=%08x expected=%08x\n",op,single,a,b,d.result_o,expected.result);check(false,"result");}
    check((d.status_o&expected.mask)==(expected.status&expected.mask),"status");
    uint32_t result=d.result_o;uint8_t status=d.status_o;
    d.start_i=0;tick(d);check(!d.busy_o&&!d.done_o,"completion pulse then idle");
    tick(d);check(d.result_o==result&&d.status_o==status,"result held idle");
}
int main(int argc,char** argv){
    Verilated::commandArgs(argc,argv);Vamd_am9511_fixed d;
    d.reset_i=1;d.start_i=0;tick(d);d.reset_i=0;tick(d);
    for(unsigned a=0;a<65536;++a)execute(d,true,5,a,0);
    for(int a=-128;a<128;++a)for(int b=-128;b<128;++b)
        for(unsigned op=0;op<5;++op){execute(d,true,op,uint16_t(a),uint16_t(b));execute(d,false,op,uint32_t(a),uint32_t(b));}
    const uint32_t edges[]={0,1,2,0x7fff,0x8000,0x8001,0xffff,0x10000,0x7fffffff,0x80000000,0x80000001,0xffffffff};
    for(bool single:{false,true})for(auto a:edges)for(auto b:edges)for(unsigned op=0;op<6;++op)execute(d,single,op,a,b);
    std::mt19937 rng(0x9511);
    for(unsigned i=0;i<30000;++i)for(bool single:{false,true})for(unsigned op=0;op<6;++op)execute(d,single,op,rng(),rng());
    // Reset must abort either iterative algorithm without producing completion.
    for(unsigned op:{2u,4u})for(unsigned elapsed=0;elapsed<32;++elapsed){
        d.start_i=1;d.single_i=0;d.operation_i=op;d.a_i=17;d.b_i=0x76543210;tick(d);d.start_i=0;
        for(unsigned k=0;k<elapsed;++k)tick(d);
        d.reset_i=1;tick(d);check(!d.busy_o&&!d.done_o&&d.status_o==0,"reset abort");d.reset_i=0;tick(d);
    }
    std::printf("TEST PASSED: fixed arithmetic %llu cases, %llu checks, %llu external comparisons, %llu documented manufacturer adapter differences, %llu cases reject defective upstream routines\n",(unsigned long long)cases,(unsigned long long)checks,(unsigned long long)external_compares,(unsigned long long)adapter_differences,(unsigned long long)rejected_external);
    d.final();
}
