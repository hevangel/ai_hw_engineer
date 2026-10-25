#include "Vtb_top.h"
#include "verilated.h"
#include "manufacturer_oracle.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_top dut;
static uint64_t checks=0,hierarchy_cases=0;
static unsigned highest(uint64_t requests,unsigned width){
 unsigned result=0;for(unsigned i=0;i<width;++i)if(requests&(uint64_t(1)<<i))result=i;return result;
}
static void equal(unsigned got,unsigned want,const char*what,uint64_t input){
 ++checks;if(got!=want){std::fprintf(stderr,"FAIL %s input=%016llx got=%x want=%x\n",what,(unsigned long long)input,got,want);std::exit(1);}
}
static void hierarchy(uint64_t request){
 ++hierarchy_cases;dut.hierarchy_request_n_i=~request;dut.eval();
 equal(dut.hierarchy_a_o,highest(request,64),"64-input vector",request);
 equal(dut.hierarchy_eo_n_o,request!=0,"64-input EO",request);
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);dut.cascade_request_n_i=0xffff;dut.hierarchy_request_n_i=~uint64_t(0);
 for(unsigned input=0;input<16384;++input){
  dut.request_n_i=input&255;dut.ei_n_i=(input>>8)&1;dut.gates_i=input>>9;dut.eval();
  unsigned want=manufacturer[input];
  equal(dut.a_o,want&7,"native A",input);equal(dut.eo_n_o,(want>>3)&1,"native EO",input);equal(dut.a_oe_o,want>>4,"native gates",input);
 }
 // Two actual chips chained through EO/EI; gates independent of cascade.
 for(unsigned ei=0;ei<2;++ei)for(unsigned gates=0;gates<32;++gates)for(unsigned req=0;req<65536;++req){
  dut.ei_n_i=ei;dut.gates_i=gates;dut.cascade_request_n_i=req;dut.eval();
  uint64_t input=uint64_t(req)|(uint64_t(ei)<<16)|(uint64_t(gates)<<17);
  unsigned active=(~req)&65535,high=active>>8,low=active&255;
  unsigned heo=ei || high!=0,leo=heo || low!=0,gate=gates==3;
  equal(dut.cascade_high_a_o,ei?0:highest(high,8),"cascade high vector",input);
  equal(dut.cascade_low_a_o,heo?0:highest(low,8),"cascade low vector",input);
  equal(dut.cascade_high_eo_n_o,heo,"cascade high EO",input);
  equal(dut.cascade_low_eo_n_o,leo,"cascade low EO",input);
  equal(dut.cascade_high_oe_o,gate,"cascade high gates",input);
  equal(dut.cascade_low_oe_o,gate,"cascade low gates",input);
  if(!ei && active)equal(heo ? 8+dut.cascade_high_a_o : dut.cascade_low_a_o,highest(active,16),"cascade selected 16-input vector",input);
 }
 hierarchy(0);hierarchy(~uint64_t(0));hierarchy(0xaaaaaaaaaaaaaaaaULL);hierarchy(0x5555555555555555ULL);
 for(unsigned i=0;i<64;++i)hierarchy(uint64_t(1)<<i);
 for(unsigned i=0;i<64;++i)for(unsigned j=0;j<64;++j)hierarchy((uint64_t(1)<<i)|(uint64_t(1)<<j));
 uint64_t state=0x29131979abcdefULL;
 for(unsigned i=0;i<65536;++i){state^=state<<13;state^=state>>7;state^=state<<17;hierarchy(state);}
 std::printf("TEST PASSED: 16384 native cases, 4194304 actual two-chip cascade cases, %llu actual nine-chip hierarchy cases; %llu checks\n",(unsigned long long)hierarchy_cases,(unsigned long long)checks);
 dut.final();return 0;
}
