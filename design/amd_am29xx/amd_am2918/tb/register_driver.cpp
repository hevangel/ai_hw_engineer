#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_top dut;
static uint64_t checks=0,bridge_cases=0,serial_cycles=0;
static void equal(unsigned got,unsigned want,const char*what){
 ++checks;if(got!=want){std::fprintf(stderr,"FAIL %s got=%x want=%x\n",what,got,want);std::exit(1);}
}
static void native_check(unsigned q,unsigned oe){
 equal(dut.q_o,q,"continuous Q");equal(dut.y_o,q,"Y data");equal(dut.y_oe_o,!oe,"independent OE");
}
static void native(){
 for(unsigned q=0;q<16;++q)for(unsigned d=0;d<16;++d)for(unsigned oe=0;oe<2;++oe){
  dut.cp_i=0;dut.d_i=q;dut.oe_n_i=1;dut.eval();dut.cp_i=1;dut.eval();native_check(q,1);
  dut.cp_i=0;dut.eval();dut.d_i=d;dut.oe_n_i=oe;dut.eval();native_check(q,oe);
  dut.cp_i=1;dut.eval();native_check(d,oe);
  dut.d_i=d^15;dut.eval();native_check(d,oe);dut.oe_n_i=oe^1;dut.eval();native_check(d,oe^1);
  dut.cp_i=0;dut.eval();native_check(d,oe^1);dut.d_i=q^15;dut.eval();native_check(d,oe^1);
 }
}
static void bridge(){
 // All original stored bus values, every OE combination and new external
 // bus inputs. Enabled drivers own their bus; external sources are released.
 for(unsigned a=0;a<16;++a)for(unsigned b=0;b<16;++b)for(unsigned oe=0;oe<4;++oe)
  for(unsigned ext=0;ext<256;++ext){
   ++bridge_cases;dut.bridge_cp_i=0;dut.bridge_oe_n_i=3;dut.a_external_i=a;dut.b_external_i=b;dut.eval();
   dut.bridge_cp_i=1;dut.eval();dut.bridge_cp_i=0;dut.eval();
   dut.a_external_i=ext&15;dut.b_external_i=ext>>4;dut.bridge_oe_n_i=oe;dut.eval();
   unsigned a_bus=(oe&2)?(ext&15):b,b_bus=(oe&1)?(ext>>4):a;
   equal(dut.a_stored_o,a,"A continuous store");equal(dut.b_stored_o,b,"B continuous store");
   equal(dut.a_bus_o,a_bus,"B to A bus");equal(dut.b_bus_o,b_bus,"A to B bus");equal(dut.bridge_enable_o,oe^3,"two independent bus enables");
   dut.bridge_cp_i=1;dut.eval();equal(dut.a_stored_o,a_bus,"A rising capture");equal(dut.b_stored_o,b_bus,"B rising capture");
   equal(dut.a_bus_o,(oe&2)?(ext&15):b_bus,"post-edge A bus");equal(dut.b_bus_o,(oe&1)?(ext>>4):a_bus,"post-edge B bus");
   dut.bridge_cp_i=0;dut.eval();equal(dut.a_stored_o,a_bus,"A falling hold");equal(dut.b_stored_o,b_bus,"B falling hold");
  }
}
static unsigned shift_word=0;
static void serial_check(){
 equal(dut.serial_q_o,shift_word,"eight-bit direct word");equal(dut.serial_y_o,shift_word,"eight-bit bus word");
 equal(dut.serial_enable_o,dut.serial_oe_n_i?0:3,"common serial OE");
}
static void shift(unsigned bit,unsigned oe,bool known=true){
 ++serial_cycles;dut.serial_cp_i=0;dut.serial_i=bit;dut.serial_oe_n_i=oe;dut.eval();if(known)serial_check();
 unsigned old=shift_word;dut.serial_cp_i=1;dut.eval();shift_word=((old<<1)|bit)&255;if(known)serial_check();
 // Data changes while HIGH must not leak into the serial chain.
 dut.serial_i=bit^1;dut.serial_oe_n_i=oe^1;dut.eval();if(known)serial_check();
 dut.serial_cp_i=0;dut.eval();if(known)serial_check();
}
static void serial(){
 // Actual eight clocks establish state; nothing assumes power-on zeros.
 for(unsigned i=0;i<8;++i)shift(0,1,false);serial_check();
 for(unsigned initial=0;initial<256;++initial)for(unsigned input=0;input<256;++input){
  for(int bit=7;bit>=0;--bit)shift((initial>>bit)&1,(initial+input+bit)&1);
  equal(dut.serial_q_o,initial,"original initial parallel word");
  for(int bit=7;bit>=0;--bit)shift((input>>bit)&1,(initial+input+bit)&1);
  equal(dut.serial_q_o,input,"original converted parallel word");
 }
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);dut.cp_i=0;dut.bridge_cp_i=0;dut.serial_cp_i=0;
 native();bridge();serial();
 std::printf("TEST PASSED: 512 native transitions, %llu original bidirectional cases, 65536 original serial word/stream cases, %llu serial clocks, %llu checks\n",(unsigned long long)bridge_cases,(unsigned long long)serial_cycles,(unsigned long long)checks);
 dut.final();return 0;
}
