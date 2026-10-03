#include "Vamd_am9080_alu.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
extern "C" {
#include "../references/superzazu/i8080.c"
}
static uint8_t instruction;
static uint8_t read_byte(void *,uint16_t) { return instruction; }
static void write_byte(void *,uint16_t,uint8_t) {}
static uint8_t port_in(void *,uint8_t) { return 0; }
static void port_out(void *,uint8_t,uint8_t) {}
int main(int argc,char **argv) {
  Verilated::commandArgs(argc,argv);
  Vamd_am9080_alu dut;
  const uint8_t opcodes[]={0x80,0x88,0x90,0x98,0xa0,0xa8,0xb0,0xb8,
                           0x3c,0x3d,0x27,0x07,0x0f,0x17,0x1f,0x2f};
  unsigned long checks=0;
  for (unsigned kind=0;kind<16;kind++) for (unsigned lhs=0;lhs<256;lhs++)
    for (unsigned rhs=0;rhs<(kind<8?256u:1u);rhs++) for (unsigned f=0;f<32;f++) {
      i8080 cpu; i8080_init(&cpu);
      cpu.read_byte=read_byte; cpu.write_byte=write_byte; cpu.port_in=port_in; cpu.port_out=port_out;
      cpu.a=lhs; cpu.b=rhs; cpu.sf=(f>>4)&1; cpu.zf=(f>>3)&1;
      cpu.hf=(f>>2)&1; cpu.pf=(f>>1)&1; cpu.cf=f&1;
      dut.kind_i=kind; dut.lhs_i=lhs; dut.rhs_i=rhs;
      dut.flags_i=(cpu.sf<<7)|(cpu.zf<<6)|(cpu.hf<<4)|(cpu.pf<<2)|2|cpu.cf;
      instruction=opcodes[kind]; i8080_step(&cpu);
      // Narrow AMD adaptation, manufacturer 3-10/3-11 and physical-chip tests.
      if (kind==4) cpu.hf=0;
      unsigned expected_flags=(cpu.sf<<7)|(cpu.zf<<6)|(cpu.hf<<4)|(cpu.pf<<2)|2|cpu.cf;
      dut.eval();
      if (dut.value_o!=cpu.a || dut.flags_o!=expected_flags) {
        std::fprintf(stderr,"ALU mismatch kind=%u lhs=%02x rhs=%02x flags=%02x result=%02x/%02x flags=%02x/%02x\n",
          kind,lhs,rhs,dut.flags_i,dut.value_o,cpu.a,dut.flags_o,expected_flags); return 1;
      }
      checks++;
    }
  dut.final();
  if (checks!=16842752) return 1;
  std::printf("TEST PASSED: %lu independent-oracle ALU/flag checks; 0 failures\n",checks);
  return 0;
}
