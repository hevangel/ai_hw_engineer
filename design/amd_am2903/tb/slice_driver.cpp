#include "Vtb_top.h"
#include "verilated.h"
#include <array>
#include <fstream>
#include <iostream>
#include <stdexcept>
static Vtb_top dut;
static uint64_t cases=0,checks=0;
static void eq(unsigned got,unsigned expected,const char* field){++checks;if(got!=expected)throw std::runtime_error(std::string(field)+" got "+std::to_string(got)+" expected "+std::to_string(expected)+" case "+std::to_string(cases));}
static void eval(){dut.eval();}
static void cp(unsigned v){dut.cp_i=v;eval();}
static void pulse(){cp(0);cp(1);cp(0);}
static unsigned pattern(unsigned seed,unsigned a){return ((seed>>((a&7)*4))+a*3)&15;}
static void safe(){dut.we_n_i=1;dut.ien_n_i=1;dut.oe_y_n_i=1;dut.oe_b_n_i=1;dut.ea_i=1;dut.cn_i=0;dut.z_i=0;dut.instruction_i=0x18c;dut.sio0_i=0;dut.sio3_i=0;dut.qio0_i=0;dut.qio3_i=0;eval();}
static void write(unsigned addr,unsigned data){safe();cp(0);dut.b_i=addr;dut.y_i=data;dut.we_n_i=0;eval();dut.we_n_i=1;eval();}
static void initialize(unsigned role,unsigned q,unsigned sc,const std::array<unsigned,16>& memory,unsigned a,unsigned b){
  safe();dut.lss_n_i=role!=0;dut.mss_n_i=role!=2;
  for(unsigned i=0;i<16;++i)write(i,memory[i]);
  // FigureB: special A stores XNOR(R3,F3). S=0,Cn=0 gives F3=0.
  safe();dut.instruction_i=0x140;dut.da_i=sc?0:8;dut.db_i=0;dut.ien_n_i=0;pulse();
  safe();dut.instruction_i=0x0cc;dut.da_i=q;dut.ien_n_i=0;pulse();
  safe();dut.a_i=a;dut.b_i=b;cp(1); // read-port latches transparent
}
int main(int argc,char** argv){
  Verilated::commandArgs(argc,argv);
  try{
    if(argc!=2)throw std::runtime_error("usage: slice_driver oracle_vectors");
    std::ifstream input(argv[1]);if(!input)throw std::runtime_error("missing vectors");
    std::array<unsigned,24> v{};
    while(input>>std::hex>>v[0]){
      for(unsigned i=1;i<v.size();++i)if(!(input>>v[i]))throw std::runtime_error("short vector");
      ++cases;std::array<unsigned,16> memory{};
      for(unsigned i=0;i<16;++i)memory[i]=pattern(v[13],i);
      memory[v[11]]=v[2];memory[v[12]]=v[3];
      initialize(v[1],v[4],v[5],memory,v[11],v[12]);
      dut.instruction_i=v[0];dut.da_i=v[6];dut.db_i=v[7];dut.y_i=v[8];
      unsigned pins=v[9];dut.ea_i=pins&1;dut.oe_b_n_i=(pins>>1)&1;dut.oe_y_n_i=(pins>>2)&1;
      dut.cn_i=(pins>>3)&1;dut.z_i=(pins>>4)&1;dut.ien_n_i=(pins>>5)&1;dut.we_n_i=(pins>>6)&1;
      dut.sio0_i=v[10]&1;dut.sio3_i=(v[10]>>1)&1;dut.qio0_i=(v[10]>>2)&1;dut.qio3_i=(v[10]>>3)&1;eval();
      cp(0);
      eq(dut.y_o,v[14],"Y");eq(dut.cn4_o,v[17],"Cn4");eq(dut.gn_o,v[18],"G/N");eq(dut.povr_o,v[19],"P/OVR");eq(dut.z_pull_low_o,v[20],"Z open collector");eq(dut.write_n_o,v[21],"WRITE");eq(dut.shift_o,v[22],"shift value");eq(dut.shift_oe_o,v[23],"shift enables");
      eq(dut.db_o,v[3],"held DB");eq(dut.db_oe_o,!((pins>>1)&1),"DB enable");eq(dut.y_oe_o,!((pins>>2)&1),"Y enable");eq(dut.write_oe_o,v[1]==0,"WRITE role enable");
      if(!dut.we_n_i)memory[v[12]]=dut.oe_y_n_i?v[8]:v[14];
      // Close write before reopening RAM read latches; inputs held across edge.
      dut.we_n_i=1;eval();cp(1);
      safe();dut.instruction_i=0x189; // F=S, source Q, no shift/write
      eq((dut.eval(),dut.y_o),v[15],"post Q");
      dut.instruction_i=0x180; // special C, MSS Z drives held sign compare
      eval();if(v[1]==2)eq(dut.z_pull_low_o,!v[16],"post sign compare");
      safe();dut.oe_b_n_i=0;
      for(unsigned i=0;i<16;++i){dut.b_i=i;eval();eq(dut.db_o,memory[i],"RAM readback");}
      // Both read ports held LOW despite address changes.
      unsigned held=dut.db_o;cp(0);dut.b_i=0;eval();eq(dut.db_o,held,"LOW read hold");
    }
    eq(unsigned(cases),415104,"vector count");
    std::cout<<"TEST PASSED: "<<cases<<" native slice vectors, "<<checks<<" checks\n";
  }catch(const std::exception& e){std::cerr<<"TEST FAILED: "<<e.what()<<"\n";return 1;}
  dut.final();return 0;
}
