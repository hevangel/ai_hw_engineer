#include "Vamd_am9511_derived.h"
#include "verilated.h"
#include <boost/multiprecision/cpp_bin_float.hpp>
#include <boost/math/constants/constants.hpp>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
using Wide=boost::multiprecision::number<boost::multiprecision::cpp_bin_float<100>>;
static uint64_t cases=0,checks=0,valid_cases=0,domain_cases=0;
static long double worst[12]={};
static void check(bool v,const char* why){++checks;if(!v){std::fprintf(stderr,"FAIL case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static Wide unpack(uint32_t w){int e=(w>>24)&127;if(e&64)e-=128;return !(w&0x800000)?Wide(0):boost::multiprecision::ldexp(Wide(w&0xffffff),e-24)*((w>>31)?-1:1);}
static uint32_t pack(Wide x){
    if(x==0)return 0;bool neg=x<0;if(neg)x=-x;int e;
    Wide scaled=boost::multiprecision::ldexp(boost::multiprecision::frexp(x,&e),24);
    Wide down=boost::multiprecision::floor(scaled);uint32_t m=down.convert_to<uint32_t>();Wide tail=scaled-down;
    if(tail>Wide(0.5)||(tail==Wide(0.5)&&(m&1)))++m;
    if(m==0x1000000){m>>=1;++e;}
    return (neg?0x80000000u:0)|((e&127)<<24)|m;
}
static void tick(Vamd_am9511_derived& d){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
static void execute(Vamd_am9511_derived& d,unsigned op,uint32_t a,uint32_t b){
    ++cases;Wide aa=unpack(a),bb=unpack(b),truth=0,argument=0;unsigned error=0;
    switch(op){
    case 1:if(aa<0)error=4;else truth=sqrt(aa);break;
    case 2:truth=sin(aa);break;
    case 3:truth=cos(aa);break;
    case 4:truth=tan(aa);break;
    case 5:if(abs(aa)>1)error=12;else truth=asin(aa);break;
    case 6:if(abs(aa)>1)error=12;else truth=acos(aa);break;
    case 7:truth=atan(aa);break;
    case 8:if(aa<=0)error=4;else truth=log10(aa);break;
    case 9:if(aa<=0)error=4;else truth=log(aa);break;
    case 10:if(abs(aa)>32)error=12;else truth=exp(aa);break;
    case 11:
        if(bb<=0)error=4;
        else {argument=aa*log(bb);if(abs(argument)>32)error=12;else truth=exp(argument);}
        break;
    default:std::abort();
    }
    check(!d.busy_o&&!d.done_o,"idle before command");
    d.start_i=1;d.operation_i=op;d.a_i=a;d.b_i=b;tick(d);d.start_i=0;
    unsigned clocks=0;
    while(!d.done_o){
        check(d.busy_o,"busy during calculation");
        d.operation_i=0;d.a_i=~a;d.b_i=~b;tick(d);check(++clocks<6000,"bounded iterative latency");
    }
    check(((d.status_o>>1)&15)==error,"domain/error code");
    if(!error){
        ++valid_cases;Wide actual=unpack(d.result_o),difference=abs(actual-truth),bound;
        // Use the original brief's function-specific bounds in its guaranteed
        // input ranges. Outside the trig ±2pi range use an absolute numeric
        // reconstruction check, without inventing a historical guarantee.
        Wide pi=boost::math::constants::pi<Wide>();
        switch(op){
        case 1:bound=abs(truth)*Wide("2e-7");break;
        case 2:case 3:case 4:
            bound=abs(aa)<=2*pi ? abs(truth)*Wide("5e-7") : Wide("2e-7")*(1+abs(truth));
            break;
        case 5:bound=abs(truth)*Wide("4e-7");break;
        case 6:bound=abs(truth)*Wide("2e-7");break;
        case 7:bound=abs(truth)*Wide("3e-7");break;
        case 8:bound=(aa>=Wide("0.1")&&aa<=10) ? Wide("2e-7") : abs(truth)*Wide("2e-7");break;
        case 9:bound=(aa>=exp(Wide(-1))&&aa<=exp(Wide(1))) ? Wide("2e-7") : abs(truth)*Wide("2e-7");break;
        case 10:bound=abs(truth)*Wide("5e-7");break;
        case 11:bound=abs(truth)*Wide("7e-7");break;
        }
        if(difference>bound){std::fprintf(stderr,"op=%u a=%08x b=%08x result=%08x actual=%.17Lg truth=%.17Lg difference=%.8Lg bound=%.8Lg\n",op,a,b,d.result_o,actual.convert_to<long double>(),truth.convert_to<long double>(),difference.convert_to<long double>(),bound.convert_to<long double>());check(false,"manufacturer accuracy bound");}
        uint8_t expected_flags=((d.result_o&0x80000000)?0x40:0)|(!(d.result_o&0x800000)?0x20:0);
        check(d.status_o==expected_flags,"sign/zero flags");
        long double measured=(truth==0?difference:difference/abs(truth)).convert_to<long double>();if(measured>worst[op])worst[op]=measured;
    }else ++domain_cases;
    uint32_t saved=d.result_o;uint8_t saved_status=d.status_o;tick(d);check(!d.busy_o&&!d.done_o,"one completion");tick(d);check(d.result_o==saved&&d.status_o==saved_status,"held idle result");
}
int main(int argc,char** argv){
    Verilated::commandArgs(argc,argv);Vamd_am9511_derived d;d.reset_i=1;d.start_i=0;tick(d);d.reset_i=0;tick(d);
    const char* edges[]={"0","1e-20","-1e-20","0.000244140625","-0.000244140625","0.5","-0.5","0.7071067","-0.7071067","0.99999994","-0.99999994","1","-1","1.00000011920928955078125","-1.00000011920928955078125","1.5","-1.5","1.5707963","-1.5707963","3.1415927","-3.1415927","6.2831854","-6.2831854","31.999998","-31.999998","32","-32","32.000004","-32.000004","1e10","-1e10","9e18","-9e18"};
    for(auto edge:edges)for(unsigned op=1;op<=11;++op)execute(d,op,pack(Wide(edge)),pack(Wide("1.00000011920928955078125")));
    for(int e=-64;e<=63;++e)for(uint32_t mantissa:{0x800000u,0x800001u,0xbfffffu,0xfffffeu,0xffffffu})for(unsigned sign=0;sign<2;++sign){
        uint32_t a=(sign?0x80000000u:0)|((e&127)<<24)|mantissa;
        for(unsigned op=1;op<=11;++op)execute(d,op,a,pack(Wide(2)));
    }
    std::mt19937 rng(0x9511d);
    for(unsigned n=0;n<2000;++n){
        uint32_t a=rng()|0x800000,b=rng()|0x800000;
        for(unsigned op=1;op<=11;++op){
            uint32_t input=a,base=b;
            if(op==5||op==6)input=pack(Wide(int32_t(rng()))/Wide(2147483648LL));
            if(op==10)input=pack(Wide(int32_t(rng()))/Wide(67108864));
            if(op==11){input=pack(Wide(int32_t(rng()))/Wide(268435456));base=pack(Wide((rng()%100000)+1)/Wide(10000));}
            execute(d,op,input,base);
        }
    }
    for(unsigned op=1;op<=11;++op){
        d.start_i=1;d.operation_i=op;d.a_i=pack(Wide("0.75"));d.b_i=pack(Wide(2));tick(d);d.start_i=0;tick(d);
        d.reset_i=1;tick(d);check(!d.busy_o&&!d.done_o&&d.status_o==0,"reset abort");d.reset_i=0;tick(d);
        std::printf("operation %u worst observed relative error %.9Lg\n",op,worst[op]);
    }
    std::printf("TEST PASSED: derived functions %llu cases, %llu valid results, %llu domain errors, %llu checks\n",(unsigned long long)cases,(unsigned long long)valid_cases,(unsigned long long)domain_cases,(unsigned long long)checks);
    d.final();
}
