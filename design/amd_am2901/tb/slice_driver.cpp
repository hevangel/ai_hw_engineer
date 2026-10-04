#include "Vamd_am2901.h"
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>

static Vamd_am2901 dut;
static uint64_t checks;
static void require(bool ok,const char* what) {
  ++checks; if(!ok){std::cerr<<"FAIL "<<what<<" at check "<<checks<<"\n";std::exit(1);}
}
static void eval(){dut.eval();}
static void word(unsigned instruction,unsigned a,unsigned b,unsigned d=0,unsigned cn=0,unsigned shift=0,unsigned oe=0){
  dut.instruction_i=instruction;dut.a_i=a;dut.b_i=b;dut.d_i=d;dut.cn_i=cn;dut.oe_n_i=oe;
  dut.ram0_i=shift&1;dut.ram3_i=(shift>>1)&1;dut.q0_i=(shift>>2)&1;dut.q3_i=(shift>>3)&1;eval();
}
static void cycle(){dut.cp_i=0;eval();dut.cp_i=1;eval();}
static unsigned read_reg(unsigned address){word(64|4,address,0);return dut.y_o;}
static unsigned read_q(){word(64|2,0,0);return dut.y_o;}
static void set_reg(unsigned address,unsigned value){word(192|7,0,address,value);cycle();word(64|7,0,0);}
static void set_q(unsigned value){word(7,0,0,value);cycle();word(64|7,0,0);}
static unsigned pattern(uint32_t seed,unsigned i){return ((seed>>((i&7)*4))+i*3)&15;}
static void phases(){
  set_reg(0,3);set_reg(1,9);set_reg(2,12);set_q(5);
  word(64|4,0,0);require(dut.y_o==3,"high-phase A read");
  word(64|4,1,0);require(dut.y_o==9,"transparent high address");
  dut.cp_i=0;eval();word(64|4,2,0);require(dut.y_o==9,"closed low address latch");
  dut.cp_i=1;eval();require(dut.y_o==12,"reopened A latch");
  word(192|7,0,2,6);dut.cp_i=0;eval();
  word(192|7,0,2,10);word(64|4,2,0);dut.cp_i=1;eval();
  require(dut.y_o==10,"transparent low RAM data");
  word(192|7,0,2,4);require(read_reg(2)==10,"no high-phase write");
  word(7,0,0,7);dut.cp_i=0;eval();word(64|2,0,0);
  require(dut.y_o==5,"Q retains before rising edge");
  word(7,0,0,7);dut.cp_i=1;eval();require(read_q()==7,"Q rising update");
  // During LOW B-address changes write different words with held A/B operands.
  word(192|7,0,3,2);dut.cp_i=0;eval();word(192|7,0,4,11);
  word(64|7,0,0);dut.cp_i=1;eval();
  require(read_reg(3)==2 && read_reg(4)==11,"transparent low B write address");
}
int main(int argc,char** argv){
  Verilated::commandArgs(argc,argv);if(argc!=2)return 2;
  dut.cp_i=1;word(64|7,0,0);phases();
  std::ifstream input(argv[1]);if(!input)return 2;
  uint64_t fields[19], cases=0;
  while(input>>std::hex>>fields[0]){
    for(unsigned i=1;i<19;i++)if(!(input>>std::hex>>fields[i]))return 2;
    auto* v=fields;
    for(unsigned i=0;i<16;i++)set_reg(i,pattern(uint32_t(v[10]),i));
    set_reg(v[1],v[7]);set_reg(v[2],v[8]);set_q(v[9]);
    word(v[0],v[1],v[2],v[3],v[4],v[6],v[5]);
    require(dut.y_oe_o==v[12] && (!v[12] || dut.y_o==v[11]),"oracle Y");
    unsigned flags=dut.p_n_o|(dut.g_n_o<<1)|(dut.cn4_o<<2)|(dut.ovr_o<<3)|(dut.f3_o<<4)|(dut.zero_o<<5);
    require(flags==v[13],"manufacturer status");
    unsigned enabled=dut.ram0_oe_o|(dut.ram3_oe_o<<1)|(dut.q0_oe_o<<2)|(dut.q3_oe_o<<3);
    unsigned shifted=dut.ram0_o|(dut.ram3_o<<1)|(dut.q0_o<<2)|(dut.q3_o<<3);
    require(enabled==v[15] && (shifted&enabled)==v[14],"oracle bidirectional shifts");
    dut.cp_i=0;eval();require(!v[12] || dut.y_o==v[11],"closed-port output during write");
    dut.cp_i=1;eval();require(read_q()==v[16],"oracle Q destination");
    for(unsigned i=0;i<16;i++)require(read_reg(i)==((v[18]>>(i*4))&15),"oracle RAM destination/retention");
    cases++;
  }
  require(cases==98304,"complete vector file");
  std::cout<<"TEST PASSED: "<<cases<<" independent cases, "<<checks<<" output/storage/phase checks\n";
  dut.final();
}
