#include "Vtb_top.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdlib>
#include <iostream>

static Vtb_top dut;
static uint64_t checks,cycles,cases,historical_words;
static void require(bool ok,const char* what){++checks;if(!ok){std::cerr<<"FAIL "<<what<<" cases="<<cases<<" cycles="<<cycles<<" got="<<std::hex<<dut.y_o<<"\n";std::exit(1);}}
// Figure 6's top-first list representation, not the RTL's memory/pointer.
struct Reference{unsigned pc=0,reg=0;std::array<unsigned,4> stack{};} ref;
struct Controls{unsigned sel=0,d=0,r=0,mask=0;bool re=true,fe=true,push=false,zero=true,oe=false,cin=true;};
static unsigned source(const Controls& c){return c.sel==0 ? ref.pc:c.sel==1 ? ref.reg:c.sel==2 ? ref.stack[0]:c.d;}
static unsigned expected_y(const Controls& c){return c.zero ? source(c):0;}
static void drive(const Controls& c){
  dut.select_i=c.sel;dut.d_i=c.d;dut.re_n_i=c.re;dut.fe_n_i=c.fe;
  dut.push_i=c.push;dut.zero_n_i=c.zero;dut.oe_n_i=c.oe;dut.cn_i=c.cin;dut.eval();
}
static void clock_edge(){dut.cp_i=0;dut.eval();dut.cp_i=1;dut.eval();cycles++;}
static unsigned step(const Controls& c){
  unsigned y=expected_y(c),old_pc=ref.pc;
  drive(c);
  require(dut.y_oe_o==!c.oe,"OE physical release");
  if(!c.oe)require(dut.y_o==y,"Figure 6 pre-edge selected/OR/ZERO address");
  require(dut.cn12_o==(y==4095 && c.cin),"12-bit carry independent of OE");
  if(!c.re)ref.reg=c.d;
  if(!c.fe){
    if(c.push){ref.stack={old_pc,ref.stack[0],ref.stack[1],ref.stack[2]};}
    else{ref.stack={ref.stack[1],ref.stack[2],ref.stack[3],ref.stack[0]};}
  }
  ref.pc=(y+unsigned(c.cin))&4095;
  clock_edge();return y;
}
static void visible(unsigned sel,unsigned value){Controls c;c.sel=sel;c.cin=false;drive(c);require(dut.y_o==value && dut.y_oe_o,"visible exact post-edge state");}
static void inspect(){
  visible(0,ref.pc);visible(1,ref.reg);unsigned saved_pc=ref.pc;
  for(unsigned i=0;i<4;i++){visible(2,ref.stack[0]);Controls pop;pop.sel=2;pop.fe=false;pop.cin=false;step(pop);}
  Controls restore;restore.sel=3;restore.d=saved_pc;restore.cin=false;step(restore);
  visible(0,saved_pc);
}
static void initialize(unsigned pc,unsigned reg,unsigned seed){
  // ZERO and register load establish known state without reset or forced internals.
  Controls first;first.zero=false;first.cin=false;first.re=false;first.d=reg;
  drive(first);clock_edge();ref.pc=0;ref.reg=reg;
  // Four real pushes overwrite the full unknown physical stack regardless of SP.
  for(unsigned i=0;i<4;i++){
    Controls load;load.sel=3;load.d=(seed+i*337)&4095;load.cin=false;step(load);
    Controls push;push.sel=3;push.d=(seed+i*229+19)&4095;push.fe=false;push.push=true;step(push);
  }
  Controls load;load.sel=3;load.d=pc;load.cin=false;step(load);inspect();
}
static void transitions(){
  for(unsigned pc=0;pc<16;pc++)for(unsigned controls=0;controls<256;controls++)for(unsigned value=0;value<16;value++){
    unsigned spread_pc=pc*273,reg=((value*7+pc)&15)*273;
    initialize(spread_pc,reg,(value*199+controls*37)&4095);
    Controls c;c.sel=controls&3;c.re=(controls>>2)&1;c.fe=(controls>>3)&1;c.push=(controls>>4)&1;
    c.zero=(controls>>5)&1;c.oe=(controls>>6)&1;c.cin=(controls>>7)&1;
    c.d=value*273;c.r=((value+pc+3)&15)*273;c.mask=((value*5+pc)&15)*273;
    step(c);inspect();cases++;
  }
  uint32_t rng=0x29091975;
  for(unsigned i=0;i<65536;i++){
    rng=rng*1664525+1013904223;unsigned controls=rng>>24;
    Controls c;c.sel=controls&3;c.re=(controls>>2)&1;c.fe=(controls>>3)&1;c.push=(controls>>4)&1;
    c.zero=(controls>>5)&1;c.oe=(controls>>6)&1;c.cin=(controls>>7)&1;
    rng=rng*1664525+1013904223;c.d=(rng>>16)&4095;rng=rng*1664525+1013904223;c.r=(rng>>16)&4095;
    rng=rng*1664525+1013904223;c.mask=(rng>>16)&4095;step(c);inspect();cases++;
  }
}
enum Instruction{POISON,CONTINUE,CALL_A,CALL_B,RETURN};
static void shared_bus(){
  initialize(0x100,0xabc,0x290);
  Controls c;c.sel=1;c.d=0x111;c.cin=false;
  drive(c);require(dut.y_o==0xabc,"live D must not replace disabled held register");
  step(c);inspect();
  c.re=false;c.d=0xdef;
  drive(c);require(dut.y_o==0xabc,"enabled register retains pre-edge source");
  step(c);inspect();
  c.re=true;c.d=0x456;
  drive(c);require(dut.y_o==0xdef,"register captures D only at enabled edge");
  step(c);inspect();
  c.sel=3;drive(c);require(dut.y_o==0x456,"direct path observes changed shared D");
}
static void historical(unsigned j,unsigned a,unsigned b,bool nested){
  std::array<Instruction,4096> rom{};
  auto put=[&](unsigned pc,Instruction instruction){require(pc<4096 && rom[pc]==POISON,"no overlapping historical microstore");rom[pc]=instruction;};
  put(j,CONTINUE);put(j+1,CONTINUE);put(j+2,CALL_A);put(j+3,CONTINUE);put(j+4,CONTINUE);
  put(a,CONTINUE);put(a+1,CONTINUE);put(a+2,nested ? CALL_B:RETURN);
  if(nested){put(b,RETURN);put(a+3,CONTINUE);put(a+4,RETURN);}
  // Literal Figures 7 and 8 traces, independent of the state-model transitions.
  const std::array<unsigned,10> simple={j,j+1,j+2,a,a+1,a+2,j+3,j+4,0,0};
  const std::array<unsigned,10> complex={j,j+1,j+2,a,a+1,a+2,b,a+3,a+4,j+3};
  const std::array<unsigned,10> simple_next={j+1,j+2,a,a+1,a+2,j+3,j+4,j+5,0,0};
  const std::array<unsigned,10> complex_next={j+1,j+2,a,a+1,a+2,b,a+3,a+4,j+3,j+4};
  initialize(j+1,0,0x100);unsigned executing=j;
  for(unsigned t=0;t<(nested ? 10u:8u);t++){
    require(executing==(nested ? complex[t]:simple[t]),"exact historical executed micro-PC");
    require(rom[executing]!=POISON,"poisoned unimplemented microstore landing");
    Controls c;
    switch(rom[executing]){
      case CONTINUE:break;
      case CALL_A:case CALL_B:c.sel=3;c.d=rom[executing]==CALL_A ? a:b;c.fe=false;c.push=true;break;
      case RETURN:c.sel=2;c.fe=false;break;
      default:std::exit(1);
    }
    drive(c);unsigned fetched=dut.y_o;
    require(fetched==(nested ? complex_next[t]:simple_next[t]),"exact next historical fetch address");
    step(c);visible(0,(fetched+1)&4095);
    // Last sample ends the published trace; every executed next sample is real.
    if(t+1<(nested ? 10u:8u))require(rom[fetched]!=POISON,"next-executed word exists exactly");
    executing=fetched;historical_words++;
  }
}
int main(int argc,char** argv){
  Verilated::commandArgs(argc,argv);dut.cp_i=1;Controls start;drive(start);
  transitions();shared_bus();historical(0x0fe,0x3fd,0x9ff,false);historical(0x0fe,0x3fd,0x9ff,true);
  historical(0x10,0x120,0x800,false);historical(0x10,0x120,0x800,true);
  require(cases==131072 && historical_words==36,"complete transition and authentic-code counts");
  std::cout<<"TEST PASSED: "<<cases<<" Figure 6 transition cases, "<<historical_words<<" original Figures 7/8 words, "<<checks<<" visible-state/control/address checks\n";
  dut.final();
}
