#include "Vtb_math.h"
#include "verilated.h"
#include <boost/multiprecision/cpp_int.hpp>
#include <random>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
using boost::multiprecision::cpp_int;
static uint64_t checks=0,cases=0;
static void check(bool v,const char* why){++checks;if(!v){std::fprintf(stderr,"FAIL math case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static cpp_int mask(unsigned w){return (cpp_int(1)<<w)-1;}
template<class T> static void put(T& port,cpp_int x,unsigned n){for(unsigned i=0;i<n;++i)port[i]=((x>>(i*32))&0xffffffff).convert_to<uint32_t>();}
template<class T> static cpp_int get(const T& port,unsigned n){cpp_int x=0;for(unsigned i=n;i>0;--i)x=(x<<32)|port[i-1];return x;}
static cpp_int sign(cpp_int x,unsigned bits){return (x&(cpp_int(1)<<(bits-1)))!=0?x-(cpp_int(1)<<bits):x;}
static void tick(Vtb_math& d){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
static void run(Vtb_math& d,cpp_int n,uint64_t denom,bool signed_mode,cpp_int value,cpp_int modulus){
 ++cases;put(d.numerator_i,n,4);d.denominator_i=denom;d.signed_i=signed_mode;put(d.value_i,value,6);put(d.modulus_i,modulus,4);
 cpp_int a=signed_mode?sign(n,128):n,b=signed_mode?sign(cpp_int(denom),64):cpp_int(denom);
 cpp_int quotient=0,remainder=0;if(b!=0){quotient=(a/b)&mask(128);remainder=(a%b)&mask(64);}
 uint64_t phase=((value%modulus)>>56).convert_to<uint64_t>();
 d.start_i=1;tick(d);d.start_i=0;bool div_seen=false,phase_seen=false;
 for(unsigned age=0;age<177;++age){
  if(d.divide_done_o){check(!div_seen,"single divider completion");div_seen=true;check(get(d.quotient_o,4)==quotient,"independent wide quotient");check(d.remainder_o==remainder,"independent wide remainder");check(bool(d.zero_o)==(denom==0),"zero divisor flag");check(age==(denom?128u:0u),"exact serial division latency");}
  if(d.phase_done_o){check(!phase_seen,"single phase completion");phase_seen=true;check(d.phase_o==phase,"independent wide modulo phase");check(age==176,"exact serial phase latency");}
  // Inputs and spurious starts may change while BOTH units are busy. A completed
  // divider is left idle while the longer phase reduction finishes.
  if(!div_seen&&!phase_seen){put(d.numerator_i,mask(128)^n,4);d.denominator_i=~denom;put(d.value_i,mask(176)^value,6);put(d.modulus_i,1,4);d.start_i=(age%7)==3;}
  else d.start_i=0;
  check(d.divide_busy_o||div_seen,"divider remains busy until result");check(d.phase_busy_o||phase_seen,"phase remains busy until result");tick(d);
 }
 check(div_seen&&phase_seen,"both numerical units complete");check(!d.divide_busy_o&&!d.phase_busy_o,"both return idle");
}
int main(int argc,char** argv){Verilated::commandArgs(argc,argv);Vtb_math d;d.reset_i=1;d.start_i=0;tick(d);d.reset_i=0;std::mt19937_64 rng(0x9511176);
 for(bool signed_mode:{false,true})for(unsigned i=0;i<4096;++i){cpp_int n=(cpp_int(rng())<<64)|rng(),v=(cpp_int(rng())<<128)|(cpp_int(rng())<<64)|rng();v&=mask(176);cpp_int m=((cpp_int(rng())<<64)|rng())&mask(115);if(m==0)m=1;uint64_t denom=rng();
  if(i<16){n=(i&1)?cpp_int(1)<<127:mask(128);denom=(i&2)?0:(i&4)?uint64_t(1)<<63:(i&8)?UINT64_MAX:1;m=(i&4)?mask(115):cpp_int(1);v=(i&8)?mask(176):cpp_int(0);}
  run(d,n,denom,signed_mode,v,m);
 }
 d.start_i=1;d.denominator_i=7;put(d.modulus_i,31,4);tick(d);d.start_i=0;for(unsigned i=0;i<37;++i)tick(d);d.reset_i=1;tick(d);check(!d.divide_busy_o&&!d.phase_busy_o&&!d.divide_done_o&&!d.phase_done_o,"reset aborts both iterative units");check(get(d.quotient_o,4)==0&&d.remainder_o==0&&d.phase_o==0,"reset clears private arithmetic outputs");
 d.final();std::printf("TEST PASSED: independent divider/phase %llu cases, %llu checks\n",(unsigned long long)cases,(unsigned long long)checks);
}
