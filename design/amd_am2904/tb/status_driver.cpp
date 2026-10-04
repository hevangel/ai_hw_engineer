#include "Vtb_top.h"
#include "verilated.h"
#include "manufacturer_oracle.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_top dut;
static uint64_t checks=0,cases=0;
static unsigned rnd=0x29041979u;
static unsigned random_word(){rnd^=rnd<<13;rnd^=rnd>>17;rnd^=rnd<<5;return rnd;}
static void equal(unsigned got,unsigned want,const char*what,unsigned inst=0,unsigned control=0){
 ++checks;if(got!=want){std::fprintf(stderr,"FAIL %s case=%llu inst=%04x controls=%06x got=%x want=%x\n",what,(unsigned long long)cases,inst,control,got,want);std::exit(1);}
}
static void drive(unsigned inst,unsigned c){
 dut.instruction_i=inst;dut.status_i=c&15;dut.y_i=(c>>4)&15;dut.shift_i=(c>>8)&15;
 dut.cx_i=(c>>12)&1;dut.ceu_n_i=(c>>13)&1;dut.cem_n_i=(c>>14)&1;dut.e_n_i=(c>>15)&15;
 dut.oey_n_i=(c>>19)&1;dut.oect_n_i=(c>>20)&1;dut.se_n_i=(c>>21)&1;dut.eval();
}
static void edge(unsigned inst,unsigned c){dut.cp_i=0;drive(inst,c);dut.cp_i=1;dut.eval();dut.cp_i=0;dut.eval();}
static unsigned probe(unsigned block){
 // Current-state Y output; no CP transition and no state debug access.
 drive(block<<4,(1u<<13)|(1u<<14)|(15u<<15)|(1u<<21));
 equal(dut.y_oe_o,1,"Y probe enable");return dut.y_o;
}
static void initialize(unsigned u,unsigned m){
 edge(0,(u<<4)|(1u<<13)|(1u<<21));
 edge(0,(m<<4)|(1u<<21));
}
static unsigned pins(){return dut.y_o|(dut.y_oe_o<<4)|(dut.ct_o<<5)|(dut.ct_oe_o<<6)|(dut.carry_o<<7)|(dut.shift_o<<8)|(dut.shift_oe_o<<12);}
static void vector(unsigned inst,unsigned control,unsigned u,unsigned m){
 ++cases;initialize(u,m);equal(probe(1),u,"initialize U");equal(probe(2),m,"initialize M");
 dut.cp_i=0;drive(inst,control);Golden want=golden(inst,control,u,m);
 equal(pins(),want.pins,"pre-edge combinational pins",inst,control);
 dut.cp_i=1;dut.eval();dut.cp_i=0;dut.eval();
 equal(pins(),golden(inst,control,want.next&15,want.next>>4).pins,"post-edge combinational pins",inst,control);
 equal(probe(1),want.next&15,"post-edge U",inst,control);equal(probe(2),want.next>>4,"post-edge M",inst,control);
}
static void historical_applications(){
 // Manufacturer interrupt application, PDF99 / printed2-91: read both Y
 // sources, run handler, then two octal00 loads (U first, M second).
 for(unsigned u=0;u<16;++u)for(unsigned m=0;m<16;++m){
  initialize(u,m);unsigned save_u=probe(1),save_m=probe(2);
  edge(1,1u<<21);equal(probe(1),15,"handler U clobber");equal(probe(2),15,"handler M clobber");
  edge(0,(save_u<<4)|(1u<<21));edge(0,(save_m<<4)|(1u<<21));
  equal(probe(1),u,"two-load interrupt U restore");equal(probe(2),m,"two-load interrupt M restore");
  // Original one-level microstatus stack alternative: octal02 twice.
  edge(2,1u<<21);equal(probe(1),m,"interrupt swap U");equal(probe(2),u,"interrupt swap M");
  edge(2,1u<<21);equal(probe(1),u,"swap return U");equal(probe(2),m,"swap return M");
 }
 // PDF95 overflow-retain and PDF97 borrow-save/return-carry examples.
 initialize(0,0);edge(6,8|(1u<<21));edge(7,0|(1u<<21));equal(probe(1)&8,8,"sticky overflow remains");
 for(unsigned carry=0;carry<2;++carry){
  initialize(0,0);edge(0x18,(carry<<1)|(1u<<21));
  equal((probe(1)>>1)&1,carry^1,"borrow saved U");equal((probe(2)>>1)&1,carry^1,"borrow saved M");
  drive(0x1818,(1u<<13)|(1u<<14)|(1u<<21));equal(dut.carry_o,carry,"borrow reinverted U");
  drive(0x1838,(1u<<13)|(1u<<14)|(1u<<21));equal(dut.carry_o,carry,"borrow reinverted M");
 }
 std::puts("Manufacturer applications PASSED: 256 two-load interrupt restores, 256 swap returns, sticky overflow and borrow-save");
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);dut.cp_i=0;
 historical_applications();
 // Every 13-bit word over all possible pre-edge U/M contents.
 for(unsigned inst=0;inst<8192;++inst)for(unsigned s=0;s<256;++s)
  vector(inst,random_word()&0x3fffff,s&15,s>>4);
 // Exhaust all status inputs over all U/M states and low six-bit operations.
 for(unsigned op=0;op<64;++op)for(unsigned s=0;s<256;++s)for(unsigned input=0;input<16;++input)
  vector(op, input|(((s*5+input)&15)<<4)|(1u<<21),s&15,s>>4);
 // Exhaust CEU/CEM, all individual M enables for each op and input.
 for(unsigned op=0;op<64;++op)for(unsigned input=0;input<16;++input)for(unsigned enables=0;enables<64;++enables)
  vector(op,input|(((input+3)&15)<<4)|(enables<<13)|(1u<<21),(input+1)&15,(input^9));
 // Table7 all serial combinations, status states, SE, forced-disabled
 // machine enables: explicitly exercise the shift carry priority exception.
 for(unsigned sh=0;sh<32;++sh)for(unsigned s=0;s<256;++s)for(unsigned serial=0;serial<16;++serial)for(unsigned se=0;se<2;++se)
  vector((sh<<6)|3,((s^serial)&15)|(serial<<8)|(1u<<13)|(1u<<14)|(15u<<15)|(se<<21),s&15,s>>4);
 std::printf("TEST PASSED: %llu native vectors, %llu pin/state checks; all 8192 words and all 32 shift rows\n",(unsigned long long)cases,(unsigned long long)checks);
 dut.final();return 0;
}
