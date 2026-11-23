// Issue #284 review reproduction harness, committed unchanged from the review
// (hevangel/ai_hw_engineer#284, first comment; the review's file map named it
// review/2026-11-18-214620-intel-80286-repro.cpp). It prints, per case, the
// exceptions the core raises next to what Intel 210498-005 Appendix B expects,
// and asserts nothing. The directed regressions for each finding are in
// tb/bootstrap.cpp, tb/event_control.cpp and the PCE oracle scenarios; the
// before/after output of this harness is recorded in report/final_report.md.
// Directed reproductions for review/2026-11-18-214620-intel-80286.md.
// Each case boots the core with LOADALL at the reset vector, runs one
// instruction and prints the exceptions raised next to what Intel 210498-005
// Appendix B specifies. It checks nothing itself: compare the two lines.
// Build and run from the repository root (Verilator from the project image):
//   verilator --cc --exe --build -j 4 -Wno-fatal --top-module intel_80286 \
//     --Mdir design/intel_80286/work/review_repro -o review_repro \
//     design/intel_80286/src/*.sv design/intel_80286/tb/review_284_repro.cpp
//   design/intel_80286/work/review_repro/review_repro
#include "Vintel_80286.h"
#include "verilated.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>
static std::vector<uint8_t> mem(1<<24);
static void w8(uint32_t a,uint8_t v){mem[a&0xffffff]=v;}
static void w16(uint32_t a,uint16_t v){w8(a,v&0xff);w8(a+1,v>>8);}
static uint16_t r16(uint32_t a){return mem[a&0xffffff]|(mem[(a+1)&0xffffff]<<8);}
static const uint32_t GDT=0x1000, IDT=0x2000, TSSA=0x3000, TSSB=0x3100, LA=0x800;
static void seg(int idx,uint32_t base,uint16_t limit,uint8_t acc){
  uint32_t a=GDT+idx*8; w16(a,limit); w16(a+2,base&0xffff); w8(a+4,base>>16); w8(a+5,acc); w16(a+6,0);}
static void gate(uint32_t a,uint16_t off,uint16_t sel,uint8_t wc,uint8_t acc){
  w16(a,off); w16(a+2,sel); w8(a+4,wc); w8(a+5,acc); w16(a+6,0);}
static void cache(uint32_t o,uint32_t base,uint8_t acc,uint16_t limit){
  w8(LA+o,base&0xff); w8(LA+o+1,(base>>8)&0xff); w8(LA+o+2,base>>16); w8(LA+o+3,acc); w16(LA+o+4,limit);}
struct Cfg{ int cpl=0; uint16_t sp=0x8000, flags=0x0002, tssa_limit=0x2b, idt_limit=0xff; };
static void setup(const Cfg&c){
  std::fill(mem.begin(),mem.end(),0);
  w8(0xfffff0,0x0f); w8(0xfffff1,0x05);                 // LOADALL at the reset vector
  seg(1,0x10000,0xffff,0x9b); seg(2,0x20000,0xffff,0x93);
  seg(3,0x30000,0xffff,0xfb); seg(4,0x40000,0xffff,0xf3);
  seg(5,TSSA,c.tssa_limit,0x83); seg(6,TSSB,0x2b,0x81);
  gate(GDT+7*8,0x0300,0x0008,0,0xe4);                   // call gate DPL3 -> 0008:0300
  seg(8,0x50000,0x0fff,0x96);                           // expand-down writable data, DPL0
  gate(GDT+9*8,0,0x0ff8,0,0x85);                        // task gate, TSS selector beyond GDT limit
  seg(10,0x10000,0x00ff,0x9b);                          // short code segment
  seg(11,0x40000,0xffff,0xf1);                          // read-only data DPL3
  for(int v=0;v<32;v++){ gate(IDT+v*8,0x0400+v*4,0x0008,0,0x86); w8(0x10000+0x0400+v*4,0xf4);}
  w8(0x10000+0x0200,0xf4); w8(0x10000+0x0300,0xf4);
  // TSS B image
  w16(TSSB+14,0x0200); w16(TSSB+16,0x0002); w16(TSSB+26,0x7000);
  w16(TSSB+34,0x10); w16(TSSB+36,0x08); w16(TSSB+38,0x10); w16(TSSB+40,0x10); w16(TSSB+42,0);
  // LOADALL image
  w16(LA+0x06,0xfff1); w16(LA+0x16,0x28); w16(LA+0x18,c.flags); w16(LA+0x1a,0x0100); w16(LA+0x1c,0);
  uint16_t cs=c.cpl?0x1b:0x08, ds=c.cpl?0x23:0x10; uint32_t cb=c.cpl?0x30000:0x10000, db=c.cpl?0x40000:0x20000;
  uint8_t ca=c.cpl?0xfb:0x9b, da=c.cpl?0xf3:0x93;
  w16(LA+0x1e,ds); w16(LA+0x20,ds); w16(LA+0x22,cs); w16(LA+0x24,ds); w16(LA+0x2c,c.sp);
  cache(0x36,db,da,0xffff); cache(0x3c,cb,ca,0xffff); cache(0x42,db,da,0xffff); cache(0x48,db,da,0xffff);
  cache(0x4e,GDT,0,12*8-1); cache(0x54,0,0,0); cache(0x5a,IDT,0,c.idt_limit); cache(0x60,TSSA,0x83,c.tssa_limit);
}
static void code(int cpl,std::initializer_list<int> b){ uint32_t a=(cpl?0x30000:0x10000)+0x100; for(int x:b) w8(a++,x); }
static void run(const char*name,const char*expect){
  Vintel_80286 d; d.clk=0; d.rst_n=0; d.intr_i=0; d.nmi_i=0; d.inta_ready_i=0; d.inta_vector_i=0;
  d.busy_i=0; d.error_n_i=1; d.pereq_i=0; d.bus_ready_i=0; d.bus_rdata_i=0;
  printf("=== %s\n    Intel expects: %s\n    RTL: ",name,expect);
  int lastv=-1,laste=-1; bool lastvalid=false; std::string log;
  for(int cyc=0;cyc<20000;cyc++){
    if(cyc==4) d.rst_n=1;
    d.clk=0; d.eval();
    d.bus_ready_i=d.bus_req_o; d.bus_rdata_i=0;
    if(d.bus_req_o && !d.bus_io_o && !d.bus_write_o) d.bus_rdata_i=mem[d.bus_addr_o&0xffffff];
    d.eval();
    bool wr=d.bus_req_o && d.bus_write_o && !d.bus_io_o; uint32_t wa=d.bus_addr_o; uint8_t wd=d.bus_wdata_o&0xff;
    d.clk=1; d.eval();
    if(wr) mem[wa&0xffffff]=wd;
    if(d.event_packet_valid_o && (!lastvalid || d.event_vector_o!=lastv || d.event_packet_error_code_o!=laste)){
      char t[64]; snprintf(t,sizeof t,"raise #%d(%04x); ",d.event_vector_o,d.event_packet_error_code_o); log+=t;
      lastv=d.event_vector_o; laste=d.event_packet_error_code_o; }
    lastvalid=d.event_packet_valid_o;
    if(d.event_o){ char t[64]; snprintf(t,sizeof t,"handler #%d entered; ",d.event_vector_o); log+=t; }
    if(d.shutdown_o){ log+="SHUTDOWN"; break; }
    if(d.fault_o){ char t[32]; snprintf(t,sizeof t,"STOPPED(code %d)",d.fault_code_o); log+=t; break; }
    if(d.halted_o){ uint64_t s=d.segs_o; char t[96];
      snprintf(t,sizeof t,"HLT at CS=%04x IP=%04x SS=%04x SP=%04x",(unsigned)((s>>16)&0xffff),d.ip_o,(unsigned)((s>>32)&0xffff),(unsigned)(d.regs_o[2]&0xffff)); log+=t; break; }
  }
  printf("%s\n",log.c_str());
}
int main(){
  { Cfg c; c.idt_limit=14*8-1; setup(c); w8(IDT+13*8+5,0x06); code(0,{0xcd,0x40});
    run("T1 #GP whose gate is not present -> #DF through an INTERRUPT gate at vector 8","handler #8 entered (App. B INT allows interrupt/trap/task gate)"); }
  { Cfg c; c.tssa_limit=0x29; setup(c); code(0,{0xea,0,0,0x30,0});
    run("T2a JMP TSS with current TSS limit = 41","task switch completes (SWITCH_TASKS: current TSS limit >= 41)"); }
  { Cfg c; setup(c); w16(TSSA+42,0xbeef); code(0,{0xea,0,0,0x30,0});
    run("T2b JMP TSS, outgoing TSS word at +42 (LDT selector) pre-set to BEEF","task switch completes; +42 not written (save needs limit 41 only)");
    printf("    outgoing TSS+42 after switch = %04x\n",r16(TSSA+42)); }
  { Cfg c; setup(c); code(0,{0xea,0,0,0x48,0});
    run("T3 JMP task gate whose TSS selector is beyond the GDT limit","#GP(0ff8) (App. B JUMP TASK GATE)"); }
  { Cfg c; setup(c); gate(GDT+9*8,0,0x0034,0,0x85); code(0,{0x9a,0,0,0x48,0});
    run("T3b CALL task gate whose TSS selector has TI=1","#GP(0034) (App. B CALL TASK GATE)"); }
  { Cfg c; c.flags=0x4002; setup(c); w16(TSSA,0x30); code(0,{0xcf});
    run("T4 IRET with NT=1, back link names an AVAILABLE TSS","#TS(0030) (App. B: new TSS must be busy else #TS)"); }
  { Cfg c; c.cpl=3; setup(c); w16(TSSA+2,0x7000); w16(TSSA+4,0x10); code(3,{0x9a,0,0,0x3b,0});
    run("T5c (control) CALL gate CPL3->0, expand-up inner stack 0010:7000","HLT at CS=0008 IP=0301 SS=0010 SP=6ff8"); }
  { Cfg c; c.cpl=3; setup(c); w16(TSSA+2,0xfff0); w16(TSSA+4,0x40); code(3,{0x9a,0,0,0x3b,0});
    run("T5 CALL gate CPL3->0, EXPAND-DOWN inner stack 0040:fff0 (limit 0fff)","HLT at CS=0008 IP=0301 SS=0040 SP=ffe8"); }
  { Cfg c; c.sp=2; setup(c); code(0,{0x9a,0x00,0x10,0x50,0});
    run("T6 far CALL: no stack room AND target IP beyond CS limit","#SS(0) (stack room is checked before the IP limit)"); }
  { Cfg c; setup(c); uint32_t s=0x20000+0x8000; w16(s,0x100); w16(s+2,0x1b); w16(s+4,2); w16(s+6,0x8000); w16(s+8,0x5b); code(0,{0xcf});
    run("T7a IRET to outer level, return SS is a read-only data segment","#GP(0058) (App. B IRET)"); }
  { Cfg c; setup(c); uint32_t s=0x20000+0x8000; w16(s,0x100); w16(s+2,0x1b); w16(s+4,0x8000); w16(s+6,0x5b); code(0,{0xcb});
    run("T7b RETF to outer level, same bad return SS","#GP(0058) (App. B RET)"); }
  { Cfg c; c.cpl=3; c.idt_limit=0x10f; setup(c); gate(IDT+0x20*8,0x0480,0x0050,0,0xe6); w16(TSSA+2,0x7000); w16(TSSA+4,0x0000); code(3,{0xcd,0x20});
    run("T8 INT 20h CPL3->0: handler IP beyond its CS limit AND null inner SS in TSS","#TS(0) (inner-stack checks precede the IP limit check)"); }
  { Cfg c; c.cpl=3; setup(c); gate(GDT+7*8,0x0300,0x0008,2,0xe4); cache(0x42,0x40000,0xf6,0x0fff);
    w16(TSSA+2,0x7000); w16(TSSA+4,0x10); code(3,{0x9a,0,0,0x3b,0});
    run("T9 CALL gate (2 parameter words) from an EXPAND-DOWN caller stack (limit 0fff, SP=8000)","HLT at CS=0008 IP=0301 SS=0010 SP=6ff4"); }
  { Cfg c; setup(c); cache(0x3c,0x10000,0x9b,0x010f); code(0,{0xeb,0x7e});
    run("T10 JMP short to IP 0180 with CS limit 010f","open question (finding 10): #GP(0) is listed under JMP; saved IP 0100 if the JMP itself faults");
    printf("    saved IP in the #GP frame = %04x\n",r16(0x20000+0x7ff8+2)); }
  return 0;
}
