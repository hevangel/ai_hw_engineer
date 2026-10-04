#include "Vtb_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

static Vtb_top dut;
struct MicroWord{unsigned a,b,dest,func,src,cn;};
static MicroWord rom[5];
static uint64_t instructions,products,checks;
static void require(bool ok,const char* label){++checks;if(!ok){std::cerr<<"FAIL "<<label<<" at "<<products<<" product, "<<instructions<<" words\n";std::exit(1);}}
static void word(unsigned instruction,unsigned a,unsigned b,unsigned data=0,unsigned carry=0,bool multiply=false){
  dut.instruction_i=instruction;dut.a_i=a;dut.b_i=b;dut.d_i=data;dut.cn_i=carry;dut.oe_n_i=0;
  dut.multiply_i=multiply;dut.ram0_i=0;dut.ram3_i=0;dut.q0_i=0;dut.q3_i=0;dut.eval();
}
static void cycle(){
  dut.cp_i=0;dut.eval();
  if(dut.multiply_i){dut.q3_hold_i=dut.ram0_o;dut.edge_hold_i=1;dut.eval();}
  dut.cp_i=1;dut.eval();
  dut.edge_hold_i=0;dut.eval();
}
static void set_reg(unsigned addr,unsigned value){word(192|7,0,addr,value);cycle();word(64|7,0,0);}
static unsigned read_reg(unsigned addr){word(64|4,addr,0);return dut.y_o;}
static unsigned read_q(){word(64|2,0,0);return dut.y_o;}
static unsigned encode(const MicroWord& w){return (w.dest<<6)|(w.func<<3)|w.src;}
static void execute(unsigned pc,unsigned expected_pc,unsigned expected_q,unsigned expected_f){
  require(pc==expected_pc && pc<5,"exact microstore address; unused positions poison");
  // Independent numeric words read directly from the rendered original table.
  const unsigned original_words[]={0034,0243,0401,0411,0232};
  const unsigned original_a[]={0,0,1,1,0},original_b[]={0,3,3,3,2};
  const unsigned original_sequence[]={0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,4};
  require(pc==original_sequence[instructions%19],"original exact microprogram sequence");
  const auto& w=rom[pc]; bool shifting=pc==2 || pc==3;
  require(encode(w)==original_words[pc] && w.a==original_a[pc] && w.b==original_b[pc] && w.cn==(pc==3 ? 1u:0u),"independently transcribed historical word");
  word(encode(w),w.a,w.b,0,w.cn,shifting);
  unsigned expected_instruction=original_words[pc];
  if(shifting) expected_instruction=(expected_instruction&~2u)|((expected_q&1) ? 0u:2u);
  require(dut.executed_instruction_o==expected_instruction,"exact executed microinstruction including Q0 control");
  if(shifting) require(dut.y_o==expected_f && dut.multiplier_lsb_o==(expected_q&1),"published add/subtract/shift inputs");
  if(shifting) require(dut.ram0_enabled_o==15 && dut.q0_enabled_o==15 && !dut.ram3_enabled_o && !dut.q3_enabled_o,"historical shift-pin direction");
  cycle();instructions++;
}
static void multiply(int16_t multiplicand,int16_t multiplier){
  set_reg(0,uint16_t(multiplier));set_reg(1,uint16_t(multiplicand));set_reg(2,0xa5a5);set_reg(3,0x5a5a);
  execute(0,0,0,0);require(read_q()==uint16_t(multiplier),"historical multiplier transfer");
  execute(1,1,0,0);require(read_reg(3)==0,"historical partial-product clear");
  int32_t partial=0;uint16_t q=uint16_t(multiplier);
  unsigned pc=2;
  for(unsigned bit=0;bit<16;bit++){
    unsigned expected_pc=bit<15 ? 2:3;
    int32_t sum=partial;
    if(q&1) sum+=bit<15 ? int32_t(multiplicand):-int32_t(multiplicand);
    execute(pc,expected_pc,q,uint16_t(sum));
    // Independent signed integer algorithm, including the 17th sign bit.
    uint16_t next_q=(q>>1)|((uint32_t(sum)&1)<<15);
    int32_t next_partial=sum>=0 ? sum/2:-((-sum+1)/2);
    unsigned actual_partial=read_reg(3),actual_q=read_q();
    if(actual_partial!=uint16_t(next_partial) || actual_q!=next_q)
      std::cerr<<"x="<<multiplicand<<" y="<<multiplier<<" bit="<<bit<<" pc="<<pc<<" sum="<<sum<<" partial="<<actual_partial<<" expected="<<uint16_t(next_partial)<<" q="<<actual_q<<" expected="<<next_q<<"\n";
    require(actual_partial==uint16_t(next_partial) && actual_q==next_q,"each historical shift result");
    partial=next_partial;q=next_q;
    unsigned next_pc=bit<14 ? 2:(bit==14 ? 3:4);
    pc=next_pc;
  }
  execute(pc,4,q,0);
  uint32_t actual=(uint32_t(read_reg(3))<<16)|read_reg(2);
  require(actual==uint32_t(int32_t(multiplicand)*int32_t(multiplier)),"full signed historical product");
  require(read_reg(0)==uint16_t(multiplier) && read_reg(1)==uint16_t(multiplicand),"historical preserved inputs");
  products++;
}
int main(int argc,char** argv){
  Verilated::commandArgs(argc,argv);if(argc!=2)return 2;
  std::ifstream source(argv[1]);if(!source)return 2;std::string line;unsigned rows=0;
  while(std::getline(source,line)){
    if(line.empty() || line[0]=='#')continue;
    unsigned pc;std::string repeat;MicroWord w{};std::istringstream parse(line);
    if(!(parse>>pc>>w.a>>w.b>>w.dest>>w.func>>w.src>>w.cn>>repeat) || pc>=5)return 2;
    rom[pc]=w;rows++;
  }
  require(rows==5,"original five-word microprogram");dut.cp_i=1;word(64|7,0,0);
  for(int x=-128;x<128;x++)for(int y=-128;y<128;y++)multiply(int16_t(x),int16_t(y));
  int16_t edges[]={INT16_MIN,INT16_MIN+1,-256,-1,0,1,255,256,INT16_MAX-1,INT16_MAX};
  for(auto x:edges)for(auto y:edges)multiply(x,y);
  uint32_t rng=0x19750805;
  for(unsigned i=0;i<4096;i++){rng=rng*1664525+1013904223;int16_t x=int16_t(rng>>16);rng=rng*1664525+1013904223;multiply(x,int16_t(rng>>16));}
  require(products==69732 && instructions==products*19,"complete historical regression counts");
  std::cout<<"TEST PASSED: manufacturer 1975 microcode; "<<products<<" signed products, "<<instructions<<" executed words, "<<checks<<" exact microcode/state checks\n";
  dut.final();
}
