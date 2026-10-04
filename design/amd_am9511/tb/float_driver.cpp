#include "Vamd_am9511_float.h"
#include "verilated.h"
#include <boost/multiprecision/cpp_bin_float.hpp>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
extern "C" {
#include "am9511.h"
}
using Wide=boost::multiprecision::number<boost::multiprecision::cpp_bin_float<200>>;
static uint64_t cases=0,checks=0,external=0,rejected=0;
static void check(bool v,const char* why){++checks;if(!v){std::fprintf(stderr,"FAIL case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static Wide unpack(uint32_t w){int e=(w>>24)&127;if(e&64)e-=128;return !(w&0x800000)?Wide(0):boost::multiprecision::ldexp(Wide(w&0xffffff),e-24)*((w>>31)?-1:1);}
struct Packed {uint32_t word;unsigned error;};
static Packed pack(Wide x){
    if(x==0)return {0,0};bool neg=x<0;if(neg)x=-x;
    int e;Wide m=boost::multiprecision::frexp(x,&e);
    Wide scaled=boost::multiprecision::ldexp(m,24), down=boost::multiprecision::floor(scaled);
    uint32_t mantissa=down.convert_to<uint32_t>();Wide tail=scaled-down;
    if(tail>Wide(0.5)||(tail==Wide(0.5)&&(mantissa&1)))++mantissa;
    if(mantissa==0x1000000){mantissa>>=1;++e;}
    return {uint32_t((neg?0x80000000u:0)|((e&127)<<24)|mantissa),unsigned(e>63?1:e< -64?2:0)};
}
static void tick(Vamd_am9511_float& d){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
static void push(void* ctx,uint32_t w){for(unsigned i=0;i<4;++i)am_push(ctx,uint8_t(w>>(i*8)));}
static uint32_t pop(void* ctx){uint32_t w=0;for(unsigned i=0;i<4;++i)w=(w<<8)|am_pop(ctx);return w;}
static void execute(Vamd_am9511_float& d,void* ext,unsigned op,uint32_t a,uint32_t b){
    ++cases;Wide aa=unpack(a),bb=unpack(b),value=0;Packed expected{};bool is_float=true,single=false;
    switch(op){
    case 0x10:value=aa+bb;expected=pack(value);break;
    case 0x11:value=bb-aa;expected=pack(value);break;
    case 0x12:value=aa*bb;expected=pack(value);break;
    case 0x13:if(aa==0){expected={b,8};value=bb;}else {value=bb/aa;expected=pack(value);}break;
    case 0x1c: value=int32_t(a);expected=pack(value);break;
    case 0x1d: value=int16_t(a);expected=pack(value);break;
    case 0x1e:case 0x1f:{
        int bits=op==0x1f?15:31;Wide mag=aa<0?-aa:aa;
        if(mag>=boost::multiprecision::ldexp(Wide(1),bits)){expected={a,1};}
        else {is_float=false;single=op==0x1f;int64_t v=aa.convert_to<int64_t>();expected={uint32_t(v)&(single?0xffffu:0xffffffffu),0};}
        break;
    }
    default:std::abort();
    }
    uint32_t r=expected.word;
    uint8_t flags=((single?bool(r&0x8000):bool(r&0x80000000))?0x40:0)|
        ((is_float?!(r&0x800000):single?(r&0xffff)==0:r==0)?0x20:0)|(expected.error<<1);
    d.operation_i=op;d.a_i=a;d.b_i=b;d.start_i=1;tick(d);
    d.start_i=0;unsigned clocks=0;
    while(!d.done_o){d.a_i=~a;d.b_i=~b;check(d.busy_o,"busy during mantissa division");tick(d);check(++clocks<=130,"bounded mantissa division");}
    check(d.done_o,"completion");
    if(d.result_o!=r||d.status_o!=flags){std::fprintf(stderr,"op=%02x a=%08x b=%08x expected=%08x/%02x actual=%08x/%02x\n",op,a,b,r,flags,d.result_o,d.status_o);check(false,"native number/result flags");}
    check(d.float_result_o==is_float&&d.single_result_o==single,"result format");
    d.a_i=~a;d.b_i=~b;tick(d);check(!d.done_o&&d.result_o==r&&d.status_o==flags,"held output");
    // Host float emulator cannot preserve native exponents through IEEE
    // subnormal results. Fixed conversion range at the negative minimum also
    // differs from the original brief's explicit magnitude bit-count rule.
    bool usable=(op>=0x10&&op<=0x13) ? (value==0 || boost::multiprecision::abs(value)>=boost::multiprecision::ldexp(Wide(1),-126)) :
        (op==0x1c||op==0x1d||expected.error==0);
    // It does no native wrap on all IEEE overflow outcomes and its FIXS/D
    // comparisons round the upper bound to host float. Keep those excluded.
    if((op==0x1e||op==0x1f)&&expected.error)usable=false;
    if(op==0x1f && aa>32767)usable=false;
    // fp_am range-checks its internal exponent before adding one, rejecting
    // native exponent -64. Keep the manufacturer-valid edge in the Wide check.
    if(is_float && (r&0x800000) && ((r>>24)&127)==64)usable=false;
    if(usable){
        am_reset(ext);
        if(op==0x1d){am_push(ext,uint8_t(a));am_push(ext,uint8_t(a>>8));}
        else {if(op<=0x13)push(ext,b);push(ext,a);}
        am_command(ext,op);uint32_t er;
        if(single){er=am_pop(ext);er=(er<<8)|am_pop(ext);}else er=pop(ext);
        if(er!=r){std::fprintf(stderr,"EXTERNAL disagreement op=%02x a=%08x b=%08x expected=%08x ext=%08x\n",op,a,b,r,er);check(false,"external arithmetic result");}
        ++external;
    } else ++rejected;
}
int main(int argc,char** argv){
    Verilated::commandArgs(argc,argv);Vamd_am9511_float d;void* ext=am_create(0,0);
    d.reset_i=1;d.start_i=0;tick(d);d.reset_i=0;
    for(unsigned n=0;n<65536;++n)execute(d,ext,0x1d,n,0);
    const uint32_t mantissas[]={0x800000,0x800001,0x800002,0x800003,0xbfffff,0xc00000,0xfffffe,0xffffff};
    const int differences[]={-127,-64,-33,-25,-24,-23,-1,0,1,23,24,25,33,64,127};
    for(int e=-64;e<=63;++e)for(auto m:mantissas)for(int diff:differences){
        int e2=e+diff;if(e2< -64||e2>63)continue;
        for(unsigned sign=0;sign<4;++sign){uint32_t a=((sign&1)?0x80000000u:0)|((e&127)<<24)|m;
            uint32_t b=((sign&2)?0x80000000u:0)|((e2&127)<<24)|mantissas[(m>>1)&7];
            for(unsigned op=0x10;op<=0x13;++op)execute(d,ext,op,a,b);
        }
    }
    for(unsigned op=0x10;op<=0x13;++op)for(int e=-64;e<=63;++e)for(auto m:mantissas){uint32_t a=((e&127)<<24)|m;execute(d,ext,op,a,0);execute(d,ext,op,0,a);}
    const uint32_t ints[]={0,1,0x7fff,0x8000,0xffff,0x10000,0x7fffffff,0x80000000,0xffffffff};
    for(auto i:ints)execute(d,ext,0x1c,i,0);
    for(unsigned op:{0x1eu,0x1fu})for(int e=-64;e<=63;++e)for(auto m:mantissas)for(unsigned sign=0;sign<2;++sign)execute(d,ext,op,((sign?0x80000000u:0)|((e&127)<<24)|m),0);
    std::mt19937 rng(0x9511f);
    for(unsigned i=0;i<20000;++i){uint32_t a=rng()|0x800000,b=rng()|0x800000;for(unsigned op=0x10;op<=0x13;++op)execute(d,ext,op,a,b);execute(d,ext,0x1c,rng(),0);execute(d,ext,0x1e,a,0);execute(d,ext,0x1f,a,0);}
    std::printf("TEST PASSED: native float/conversion %llu cases, %llu checks, %llu external result comparisons, %llu cases outside external contract\n",(unsigned long long)cases,(unsigned long long)checks,(unsigned long long)external,(unsigned long long)rejected);
    d.final();
}
