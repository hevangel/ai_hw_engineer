#include "Vtb_multiply.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
static Vtb_multiply dut;
static uint64_t checks=0,products=0,words=0;
struct MicroWord {unsigned offset,seq,count,slice,a,b;std::string carry;};
static std::array<MicroWord,5> original;
static void eq(uint32_t got,uint32_t want,const char* what){++checks;if(got!=want)throw std::runtime_error(std::string(what)+" got "+std::to_string(got)+" expected "+std::to_string(want)+" product "+std::to_string(products)+" word "+std::to_string(words));}
static void safe(){dut.auto_write_i=0;dut.we_n_i=1;dut.ien_n_i=1;dut.oe_y_n_i=0;dut.instruction_i=0x18c;dut.cn_i=0;dut.cn_from_z_i=0;dut.eval();}
static void reg_write(unsigned addr,unsigned data){safe();dut.cp_i=0;dut.eval();dut.b_i=addr;dut.external_y_i=data;dut.oe_y_n_i=1;dut.we_n_i=0;dut.eval();dut.we_n_i=1;dut.eval();dut.cp_i=1;dut.eval();}
static unsigned reg_read(unsigned addr){safe();dut.b_i=addr;dut.eval();return dut.db_o;}
static unsigned q_read(){safe();dut.instruction_i=0x189;dut.eval();return dut.y_o;}
static void seq(unsigned op,unsigned d){dut.controller_cp_i=0;dut.controller_instruction_i=op;dut.controller_d_i=d;dut.eval();dut.controller_cp_i=1;dut.eval();}
static void micro_word(const MicroWord& w,unsigned base){
  dut.instruction_i=w.slice;dut.a_i=w.a;dut.b_i=w.b;dut.oe_y_n_i=0;dut.ien_n_i=0;
  dut.auto_write_i=1;dut.cn_i=0;dut.cn_from_z_i=w.carry=="Z";
  dut.controller_cp_i=0;dut.controller_instruction_i=w.seq;dut.controller_d_i=w.count==0xffff?base+1:w.count;dut.eval();
}
static void cycle(){dut.cp_i=0;dut.eval();dut.cp_i=1;dut.controller_cp_i=1;dut.eval();}
static void multiply(uint16_t x,uint16_t y,bool is_signed){
  reg_write(0,0);reg_write(1,x);reg_write(2,y);
  unsigned base=(products&1)?0xffd:0x2ff; // force page carry and PC wrap
  seq(0,0);seq(2,base);
  auto load=original[is_signed?2:0];auto repeat=original[is_signed?3:1];auto last=original[4];
  eq(load.slice,0x0cc,"original load word");eq(repeat.slice,is_signed?0x040:0x000,"original repeat word");eq(last.slice,0x0c0,"original final word");
  eq(load.count,is_signed?14:15,"original LDCT count");eq(repeat.seq,9,"original RPCT");eq(load.seq,12,"original LDCT");
  micro_word(load,base);eq(dut.next_address_o,(base+1)&4095,"load exact next fetch");cycle();++words;dut.controller_instruction_i=14;dut.eval();eq(dut.next_address_o,(base+2)&4095,"load exact post PC");
  eq(q_read(),y,"original R2->Q transfer");
  int32_t partial=0;uint16_t q=y;
  unsigned pc=(base+1)&4095;
  for(unsigned n=0;n<16;++n){
    const auto& w=(is_signed && n==15)?last:repeat;
    eq(pc,(base+(is_signed && n==15?2:1))&4095,"exact executed microaddress");
    micro_word(w,base);
    unsigned expectedNext=(is_signed?(n<14?base+1:n==14?base+2:base+3):(n<15?base+1:base+2))&4095;
    eq(dut.next_address_o,expectedNext,"exact next microinstruction");eq(dut.controller_y_oe_o,1,"controller OE");eq(dut.controller_pl_n_o,0,"pipeline enable");
    eq(dut.controller_map_n_o,1,"map disabled");eq(dut.controller_vect_n_o,1,"vector disabled");eq(dut.write_enabled_o,1,"only native LSS WRITE pin drives");
    eq(dut.zero_bus_o,q&1,"real shared multiply Z=Q0");
    int32_t sum=partial;
    if(q&1)sum+=is_signed?(n==15?-int32_t(int16_t(x)):int32_t(int16_t(x))):int32_t(x);
    int32_t next_partial=is_signed?(sum>=0?sum/2:-((-sum+1)/2)):int32_t(uint32_t(sum)>>1);
    uint16_t next_q=(q>>1)|((uint32_t(sum)&1)<<15);
    eq(dut.y_o,uint16_t(next_partial),"manufacturer shift/17th sign correction");
    eq(dut.shift_enable_o,0x5555,"manufacturer multiply serial pin directions");
    cycle();++words;pc=expectedNext;dut.controller_instruction_i=14;dut.eval();eq(dut.next_address_o,(expectedNext+1)&4095,"exact post-instruction PC");
    eq(reg_read(0),uint16_t(next_partial),"each partial product");eq(q_read(),next_q,"each Q shift");
    partial=next_partial;q=next_q;
  }
  uint32_t actual=(uint32_t(reg_read(0))<<16)|q_read();
  uint32_t expected=is_signed?uint32_t(int32_t(int16_t(x))*int32_t(int16_t(y))):uint32_t(x)*y;
  eq(actual,expected,"full historical product");eq(reg_read(1),x,"preserved multiplicand");eq(reg_read(2),y,"preserved multiplier");
  eq(unsigned(words%(17)),0,"exact 17-word execution");++products;
}
int main(int argc,char** argv){
  Verilated::commandArgs(argc,argv);
  try{
    if(argc!=2)throw std::runtime_error("usage: multiply_driver original_csv");
    std::ifstream input(argv[1]);std::string line;unsigned row=0;
    while(std::getline(input,line)){
      if(line.empty() || line[0]=='#')continue;
      for(auto& c:line)if(c==',')c=' ';
      std::istringstream parse(line);std::string count;
      MicroWord w{};std::string opcode;
      if(!(parse>>w.offset>>opcode>>count>>std::hex>>w.slice>>w.a>>w.b>>w.carry) || row>=5)throw std::runtime_error("invalid original table");
      // Final next-control X is explicitly CONT, an unconstrained fallthrough.
      w.seq=opcode=="X"?14:std::stoul(opcode,nullptr,16);w.count=count=="NEXTSELF"?0xffff:std::stoul(count,nullptr,16);original[row++]=w;
    }
    eq(row,5,"original five microcode rows");safe();dut.cp_i=1;dut.eval();
    for(unsigned x=0;x<256;++x)for(unsigned y=0;y<256;++y){multiply(uint16_t(x),uint16_t(y),false);multiply(uint16_t(int16_t(int8_t(x))),uint16_t(int16_t(int8_t(y))),true);}
    std::array<uint16_t,10> edge={0,1,2,255,256,0x7ffe,0x7fff,0x8000,0xfffe,0xffff};
    for(auto x:edge)for(auto y:edge){multiply(x,y,false);multiply(x,y,true);}
    uint32_t rng=0x19782903;
    for(unsigned i=0;i<4096;++i){rng=rng*1664525+1013904223;uint16_t x=rng>>16;rng=rng*1664525+1013904223;uint16_t y=rng>>16;multiply(x,y,false);multiply(x,y,true);}
    eq(unsigned(products),139464,"product count");eq(unsigned(words),139464*17,"exact executed word count");
    std::cout<<"TEST PASSED: original AMD Figures17/19 microcode, "<<products<<" products, "<<words<<" words, "<<checks<<" exact PC/state checks\n";
  }catch(const std::exception& e){std::cerr<<"TEST FAILED: "<<e.what()<<"\n";return 1;}
  dut.final();return 0;
}
