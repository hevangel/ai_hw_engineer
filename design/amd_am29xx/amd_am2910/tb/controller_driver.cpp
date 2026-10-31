#include "Vtb_top.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <vector>

static Vtb_top dut;
static uint64_t checks=0, cases=0, firmwareWords=0;
static void eq(unsigned got,unsigned want,const char* what) {
  ++checks;
  if(got!=want) throw std::runtime_error(std::string(what)+" got "+std::to_string(got)+" expected "+std::to_string(want)+" case "+std::to_string(cases));
}
static void drive(unsigned op,unsigned d=0,unsigned pins=1) {
  dut.cp_i=0; dut.instruction_i=op; dut.d_i=d;
  dut.cc_n_i=pins&1; dut.ccen_n_i=(pins>>1)&1; dut.ci_i=(pins>>2)&1;
  dut.rld_n_i=(pins>>3)&1; dut.oe_n_i=(pins>>4)&1; dut.eval();
}
static void edge() { dut.cp_i=1; dut.eval(); dut.cp_i=0; dut.eval(); }
static void apply(unsigned op,unsigned d=0,unsigned pins=9) {drive(op,d,pins);edge();}
static void initialize(unsigned pc,unsigned rc,unsigned depth,const std::array<unsigned,5>& words) {
  apply(0); // JZ empties without clearing any storage.
  for(auto word:words) {apply(2,word);apply(4);} // failed PUSH retains R
  for(unsigned i=depth;i<5;++i) apply(11,0,8); // passed CJPP discards one
  apply(12,rc);apply(2,pc);
}
static void transitions(const char* path) {
  std::ifstream in(path); if(!in) throw std::runtime_error("missing oracle vectors");
  std::array<unsigned,21> v{};
  while(in>>std::hex>>v[0]) {
    for(unsigned i=1;i<v.size();++i) if(!(in>>v[i])) throw std::runtime_error("short oracle vector");
    ++cases;
    std::array<unsigned,5> words{};for(unsigned i=0;i<5;++i) words[i]=v[5+i];
    initialize(v[4],v[3],v[2],words);
    drive(v[0],v[10],v[1]);
    if(v[11]) eq(dut.y_o,v[12],"pre-edge Y");
    eq(dut.y_oe_o,!((v[1]>>4)&1),"OE");eq(dut.full_n_o,v[2]!=5,"pre FULL");
    eq(dut.pl_n_o,v[0]==2 || v[0]==6,"PL");eq(dut.map_n_o,v[0]!=2,"MAP");eq(dut.vect_n_o,v[0]!=6,"VECT");
    edge(); eq(dut.full_n_o,v[14]!=5,"post FULL");
    drive(14,0,9);if(v[11]) eq(dut.y_o,v[13],"post PC");
    drive(7,0,9);eq(dut.y_o,v[15],"post counter");
    // Observe the active stack through actual return instructions, not internals.
    for(unsigned n=v[14];n>0;--n) {
      drive(10,0,8);eq(dut.y_o,v[16+n-1],"retained stack word");edge();
      eq(dut.full_n_o,1,"FULL after pop");
    }
    // Empty pop saturates; next push becomes one entry, not wrapped depth.
    apply(11,0xabc,8);apply(2,0x123);apply(4);
    drive(10,0,8);eq(dut.y_o,0x123,"push after empty pop");edge();
    apply(2,0x456);apply(4);drive(10,0,8);eq(dut.y_o,0x456,"second empty saturation");
  }
  eq(unsigned(cases),87040,"transition count");
}
struct Word {unsigned op,d,pins;};
static constexpr unsigned fail=13, pass=12; // CI=1, RLD=1; CCEN=0, CC selects.
static void historical(const std::map<unsigned,Word>& rom,const std::vector<unsigned>& trace) {
  std::array<unsigned,5> words={1,2,3,4,5};
  initialize(trace.front()+1,0,0,words);
  for(unsigned i=0;i+1<trace.size();++i) {
    auto it=rom.find(trace[i]);if(it==rom.end()) throw std::runtime_error("unmapped historical execution at "+std::to_string(trace[i]));
    drive(14,0,9);eq(dut.y_o,(trace[i]+1)&4095,"exact executed PC linkage");
    drive(it->second.op,it->second.d,it->second.pins);
    eq(dut.y_o,trace[i+1],"historical exact next instruction");
    edge();drive(14,0,9);eq(dut.y_o,(trace[i+1]+1)&4095,"historical post PC");
    ++firmwareWords;
  }
}
static std::map<unsigned,Word> sequential(unsigned first,unsigned last) {
  std::map<unsigned,Word> rom;for(unsigned a=first;a<=last;++a) rom[a]={14,0,fail};return rom;
}
static void software() {
  // AMD Figure4 instruction1/10: conditional early return or unconditional97.
  for(bool early:{false,true}) {
    auto rom=sequential(50,54);auto sub=sequential(90,97);rom.insert(sub.begin(),sub.end());
    rom[52]={1,90,pass};rom[93]={10,0,early?pass:fail};rom[97]={10,0,14};
    std::vector<unsigned> trace={50,51,52,90,91,92,93};
    if(!early) for(unsigned a=94;a<=97;++a)trace.push_back(a);
    trace.push_back(53);trace.push_back(54);historical(rom,trace);
  }
  // Figure4 RFCT: PUSH at50, actual four-word51..54 loop, N+1 passes.
  for(unsigned n:{0u,1u,2u,15u,4095u}) {
    auto rom=sequential(50,55);rom[50]={4,n,pass};rom[54]={8,0,fail};
    std::vector<unsigned> trace={50};
    for(unsigned i=0;i<=n;++i)for(unsigned a=51;a<=54;++a)trace.push_back(a);
    trace.push_back(55);historical(rom,trace);
    eq(dut.full_n_o,1,"RFCT removed loop frame");
    // Figure4 RPCT: LDCT at51, single-word52 loop; stack unchanged.
    rom=sequential(51,53);rom[51]={12,n,fail};rom[52]={9,52,fail};trace={51};
    for(unsigned i=0;i<=n;++i)trace.push_back(52);
    trace.push_back(53);historical(rom,trace);
  }
  // Figure4 LOOP at56 returns to52 until pass, then falls through57.
  {
    auto rom=sequential(51,57);rom[51]={4,0,fail};rom[56]={13,0,fail};
    std::vector<unsigned> trace={51,52,53,54,55,56,52,53,54,55,56};
    std::array<unsigned,5> words={1,2,3,4,5};initialize(52,0,0,words);
    for(unsigned i=0;i<trace.size();++i) {
      unsigned addr=trace[i];auto w=rom.at(addr);
      if(i+1==trace.size())w.pins=pass;
      unsigned next=i+1<trace.size()?trace[i+1]:57;
      drive(14,0,9);eq(dut.y_o,addr+1,"LOOP exact executed PC");
      drive(w.op,w.d,w.pins);eq(dut.y_o,next,"LOOP exact next");edge();++firmwareWords;
    }
    drive(14,0,9);eq(dut.y_o,58,"LOOP post PC");
  }
  // Figure4 TWB memory search:63 PUSH N,64 compare,65 three-way branch.
  for(unsigned n:{0u,1u,7u,4095u}) for(bool found:{false,true}) {
    auto rom=sequential(63,66);rom[63]={4,n,pass};rom[65]={15,72,found?pass:fail};
    std::vector<unsigned> trace={63};
    unsigned passes=found?1:n+1;
    for(unsigned i=0;i<passes;++i){trace.push_back(64);trace.push_back(65);}
    trace.push_back(found?66:72);historical(rom,trace);
    drive(7,0,9);eq(dut.y_o,found?(n==0?0:n-1):0,"TWB decrement even on passed exit");
  }
}
int main(int argc,char** argv) {
  Verilated::commandArgs(argc,argv);
  try {
    if(argc!=2)throw std::runtime_error("usage: controller_driver oracle_vectors");
    transitions(argv[1]);software();
    std::cout<<"TEST PASSED: "<<cases<<" manufacturer-table transitions, "<<firmwareWords<<" original Figure 4 firmware words, "<<checks<<" checks\n";
  }catch(const std::exception& e){std::cerr<<"TEST FAILED: "<<e.what()<<"\n";return 1;}
  dut.final();return 0;
}
