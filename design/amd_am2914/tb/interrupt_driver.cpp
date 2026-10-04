#include "Vtb_top.h"
#include "verilated.h"
#include "manufacturer_model.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static Vtb_top dut;
static Manufacturer ref;
static uint64_t checks=0,cycles=0,cases=0,historical=0,board_cases=0;
static unsigned random_state=0x29141979u;
static unsigned random_word(){random_state^=random_state<<13;random_state^=random_state>>17;random_state^=random_state<<5;return random_state;}
static void equal(unsigned got,unsigned want,const char*what){
 ++checks;if(got!=want){std::fprintf(stderr,"FAIL %s cycle=%llu case=%llu got=%x want=%x\n",what,(unsigned long long)cycles,(unsigned long long)cases,got,want);std::exit(1);}
}
static void pins(const Inputs&i){
 Pins w=ref.pins(i);
 equal(dut.m_o,w.m,"M data");equal(dut.s_o,w.s,"S data");equal(dut.v_o,w.v,"V data");
 equal(dut.m_oe_o,w.mo,"M enable");equal(dut.s_oe_o,w.so,"S enable");equal(dut.v_oe_o,w.vo,"V enable");
 equal(dut.irq_pull_low_o,w.irq,"IRQ pull-low");equal(dut.gs_n_o,w.gs,"GS");equal(dut.gas_n_o,w.gas,"GAS");
 equal(dut.rd_n_o,w.rd,"RD");equal(dut.pd_o,w.pd,"PD");equal(dut.sv_n_o,w.sv,"SV");
}
static void drive(const Inputs&i){
 dut.instruction_i=i.op;dut.m_i=i.m;dut.s_i=i.s;dut.p_n_i=i.p;dut.ie_n_i=i.ie;
 dut.lb_i=i.lb;dut.ge_n_i=i.ge;dut.gar_n_i=i.gar;dut.id_n_i=i.id;
}
static void observe(const Inputs&i,bool high=false){
 if(high && !dut.cp_i){std::fputs("testbench attempted an unmodeled rising edge\n",stderr);std::exit(1);}
 dut.cp_i=high;drive(i);ref.phase(i,high);dut.eval();pins(i);
}
static void execute(const Inputs&i,bool return_low=true){
 ++cycles;observe(i);ref.edge(i);ref.phase(i,true);dut.cp_i=1;dut.eval();pins(i);
 if(return_low){ref.phase(i,false);dut.cp_i=0;dut.eval();pins(i);}
}
static Inputs command(unsigned op){Inputs i;i.op=op;i.ie=0;return i;}
static void initialize(){
 Inputs i=command(0);dut.cp_i=0;drive(i);ref.phase(i,false);dut.eval();
 ref.edge(i);ref.phase(i,true);dut.cp_i=1;dut.eval();pins(i);
 ref.phase(i,false);dut.cp_i=0;dut.eval();pins(i);++cycles;
}
static void capture(unsigned requests,bool latch=true){
 Inputs i;i.lb=!latch;i.p=(~requests)&255;observe(i);
 if(latch){i.p=255;observe(i);}execute(i);
}
static void native_vectors(){
 for(unsigned req=0;req<256;++req)for(unsigned mask=0;mask<256;++mask)for(unsigned status=0;status<8;++status){
  ++cases;initialize();Inputs i=command(14);i.m=mask;execute(i);
  i=command(9);i.s=status;execute(i);capture(req);
  i=command(5);i.lb=0;execute(i);
 }
 const unsigned mask_ops[]={8,10,11,12,14};
 for(unsigned op:mask_ops)for(unsigned mask=0;mask<256;++mask)for(unsigned data=0;data<256;++data){
  ++cases;initialize();Inputs i=command(14);i.m=mask;execute(i);
  i=command(op);i.m=data;execute(i);i=command(7);observe(i);equal(dut.m_oe_o,1,"native mask read enable");
 }
 const unsigned clear_ops[]={0,1,2,3,4};
 for(unsigned op:clear_ops)for(unsigned req=0;req<256;++req)for(unsigned data=0;data<256;++data){
  ++cases;initialize();capture(req);Inputs i=command(14);i.m=data;i.lb=0;execute(i);
  i=command(5);i.lb=0;execute(i);i=command(op);i.m=data^0x5a;i.lb=0;execute(i);
  i=command(9);i.lb=0;execute(i);i=command(12);i.lb=0;execute(i);
  i=command(5);i.lb=0;observe(i);
 }
 // All16 words, IE both levels, and GE/GAR/ID/LB variations on native state.
 for(unsigned op=0;op<16;++op)for(unsigned ctl=0;ctl<32;++ctl)for(unsigned req=0;req<256;++req){
  ++cases;initialize();capture(req);Inputs i=command(op);
  i.m=random_word()&255;i.s=random_word()&7;i.ie=ctl&1;i.ge=(ctl>>1)&1;
  i.gar=(ctl>>2)&1;i.id=(ctl>>3)&1;i.lb=(ctl>>4)&1;i.p=random_word()&255;execute(i);
 }
 // Free-running native sequences, with sub-cycle pulses and changes in both
 // phases; expected model interprets source actions, never DUT internals.
 initialize();
 for(unsigned n=0;n<131072;++n){
  ++cases;Inputs i=command(random_word()&15);i.m=random_word()&255;i.s=random_word()&7;
  unsigned ctl=random_word();i.ie=ctl&1;i.ge=(ctl>>1)&1;i.gar=(ctl>>2)&1;i.id=(ctl>>3)&1;i.lb=(ctl>>4)&1;
  i.p=random_word()&255;observe(i,false);i.p=random_word()&255;observe(i,false);execute(i,false);
  i.ie=1;i.p=random_word()&255;observe(i,true);i.p=255;observe(i,true);observe(i,false);
 }
}
static void historical_procedures(){
 // Original Figure4/PDF177: save mask/status, read vector, acknowledge input,
 // clear held vector, service with new state, restore mask/status.
 for(unsigned vector=0;vector<8;++vector)for(unsigned mask=0;mask<256;++mask)if(!(mask&(1u<<vector)))
  for(unsigned threshold=0;threshold<=vector;++threshold){
   ++historical;initialize();Inputs i=command(14);i.m=mask;execute(i);
   i=command(9);i.s=threshold;execute(i);capture(1u<<vector);
   i=command(7);i.lb=0;observe(i);unsigned saved_mask=dut.m_o;equal(dut.m_oe_o,1,"save mask bus");
   i=command(6);i.lb=0;observe(i);unsigned saved_status=dut.s_o;equal(dut.s_oe_o,1,"save status bus");
   i=command(5);i.lb=0;observe(i);equal(dut.v_oe_o,1,"original vector enable");equal(dut.v_o,vector,"original vector read");execute(i);
   i=command(4);i.lb=0;execute(i);equal(dut.irq_pull_low_o,0,"held vector cleared");
   i=command(8);execute(i);i=command(9);i.s=7;execute(i);
   i=command(14);i.m=saved_mask;execute(i);i=command(9);i.s=saved_status;execute(i);
   i=command(7);observe(i);equal(dut.m_o,mask,"original mask restored");
   i=command(6);observe(i);equal(dut.s_o,threshold,"original status restored");equal(dut.sv_n_o,1,"original overflow reset");
  }
 // Software IRQ inhibit must leave vector eligibility and priority alive.
 initialize();capture(1u<<3);Inputs i=command(13);i.lb=0;execute(i);
 equal(dut.irq_pull_low_o,0,"software IRQ disabled");i=command(5);i.lb=0;observe(i);equal(dut.v_oe_o,1,"DISIN does not inhibit vector read");
 // Pulse capture vs bypass, held-level clear/reassert, and sticky SV even if
 // caller deliberately omits the normal SV-to-ID board wire.
 initialize();Inputs pulse;pulse.lb=1;pulse.p=0xfe;observe(pulse);pulse.p=255;observe(pulse);execute(pulse);
 equal(dut.irq_pull_low_o,0,"bypassed pulse disappeared before CP");
 initialize();capture(128);i=command(5);i.lb=0;execute(i);equal(dut.sv_n_o,0,"read highest vector overflows");
 i=command(1);i.lb=0;execute(i);i=command(5);i.lb=0;execute(i);equal(dut.sv_n_o,0,"overflow sticky after idle RDVC");
 i=command(9);execute(i);equal(dut.sv_n_o,1,"LDSTA resets overflow");
}
static void board_drive(unsigned op,unsigned status=0,bool enabled=true){
 dut.board_instruction_i=op;dut.board_s_i=status;dut.board_ie_n_i=!enabled;dut.board_m_i=0;dut.board_lb_i=0;dut.eval();
}
static void board_edge(unsigned op,unsigned status=0,bool enabled=true){
 dut.board_cp_i=0;board_drive(op,status,enabled);dut.board_cp_i=1;dut.eval();dut.board_cp_i=0;dut.eval();
}
static void board_reset(unsigned threshold=0){
 dut.board_cp_i=0;dut.board_p_n_i=~uint64_t(0);board_edge(0);board_edge(9,threshold);
 equal(dut.board_gs_n_o,255^(1u<<(threshold>>3)),"one lowest group after status load");
 equal(dut.board_sv_n_o,255,"board overflow reset");
}
static void board_capture(uint64_t requests){
 board_drive(0,0,false);dut.board_p_n_i=~requests;dut.eval();dut.board_p_n_i=~uint64_t(0);dut.eval();board_edge(0,0,false);
}
static void board_tests(){
 for(unsigned threshold=0;threshold<64;++threshold)for(unsigned vector=0;vector<64;++vector){
  ++board_cases;board_reset(threshold);
  uint64_t lower=(uint64_t(random_word())<<32)|random_word();
  lower=vector==63?lower:(lower & ((uint64_t(1)<<vector)-1));
  board_capture((uint64_t(1)<<vector)|lower);
  equal(dut.board_irq_o,vector>=threshold,"64-level threshold IRQ");
  board_drive(6,threshold);equal(dut.board_status_high_oe_o,1,"status expander gate");
  equal(dut.board_s_oe_o,1u<<(threshold>>3),"status one driver");equal(dut.board_status_o,threshold,"exact full status bus");
  if(vector>=threshold){
   board_drive(5);equal(dut.board_vector_high_oe_o,1,"vector expander gate");equal(dut.board_v_oe_o,1u<<(vector>>3),"vector one driver");
   equal(dut.board_v_o,vector,"exact full vector bus");board_edge(5);
   if(vector==63){
    equal(dut.board_sv_n_o>>7,0,"highest group overflow");equal(dut.board_irq_o,0,"highest overflow disables all");
    board_edge(4);
    board_edge(6);board_edge(5);equal(dut.board_sv_n_o>>7,0,"highest overflow persists through idle vector read");
   }else{
    unsigned next=vector+1;board_drive(6);
    equal(dut.board_gs_n_o,255^(1u<<(next>>3)),"group advance exact selected group");
    equal(dut.board_s_oe_o,1u<<(next>>3),"advanced status one driver");equal(dut.board_status_o,next,"advanced status exact bus");
    equal(dut.board_irq_o,0,"lower/equal requests blocked after vector read");
   }
   // Original held-vector clear / service / state restoration sequence.
   board_edge(4);board_edge(9,threshold);board_drive(6);
   equal(dut.board_status_o,threshold,"restored original full status");
   equal(dut.board_sv_n_o,255,"restoration resets each overflow");
  }else{
   board_drive(5);equal(dut.board_v_oe_o,0,"no vector driver below threshold");
  }
 }
 // Boundary transfer: each group7 advances to the next group's0, including
 // new higher pulse arrival while a lower interrupt is in service.
 for(unsigned group=0;group<7;++group){
  ++board_cases;unsigned low=group*8+7,high=low+1;
  board_reset();board_capture(uint64_t(1)<<low);board_edge(5);board_drive(6);
  equal(dut.board_status_o,high,"boundary threshold transfer");
  board_capture(uint64_t(1)<<high);equal(dut.board_irq_o,1,"nested higher request");
  board_drive(5);equal(dut.board_v_o,high,"nested full vector");equal(dut.board_v_oe_o,1u<<(high>>3),"nested one driver");
  board_edge(5);board_edge(4);board_edge(9,0);equal(dut.board_irq_o,1,"original lower request remains after clearing nested held vector");
 }
 std::printf("Original cascade application PASSED: %llu eight-controller/two-Am2913 cases\n",(unsigned long long)board_cases);
}
int main(int argc,char**argv){
 Verilated::commandArgs(argc,argv);dut.cp_i=0;dut.board_cp_i=0;dut.board_p_n_i=~uint64_t(0);dut.board_ie_n_i=1;dut.board_lb_i=1;
 native_vectors();historical_procedures();board_tests();
 std::printf("TEST PASSED: %llu native cases, %llu native cycles, %llu original interrupt procedures, %llu pin checks\n",(unsigned long long)cases,(unsigned long long)cycles,(unsigned long long)historical,(unsigned long long)checks);
 dut.final();return 0;
}
