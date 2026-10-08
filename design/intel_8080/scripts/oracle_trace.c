// Trace adapter for immutable superzazu/8080; never derives semantics from RTL.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../amd_am9080/references/superzazu/i8080.h"

static uint8_t memory[65536];
static uint16_t write_address[2];
static uint8_t write_value[2], out_port, out_value;
static unsigned writes, outs;
static int done;
static FILE *console;
static uint8_t rb(void *ctx, uint16_t addr) { (void)ctx; return memory[addr]; }
static void wb(void *ctx, uint16_t addr, uint8_t val) {
  (void)ctx;
  if (writes >= 2) { fputs("too many writes\n",stderr); exit(1); }
  write_address[writes]=addr; write_value[writes++]=val; memory[addr]=val;
}
static uint8_t port_in(void *ctx, uint8_t port) { (void)ctx; return port ^ 0x5a; }
static void port_out(void *ctx, uint8_t port, uint8_t value) {
  i8080 *cpu=ctx;
  outs++; out_port=port; out_value=value;
  if (port==0) done=1;
  if (port==1 && cpu->c==2) fputc(cpu->e,console);
  if (port==1 && cpu->c==9) {
    uint16_t addr=(uint16_t)((cpu->d<<8)|cpu->e);
    unsigned guard=0;
    while (memory[addr]!='$') {
      if (++guard>65536) { fputs("unterminated BDOS string\n",stderr); exit(1); }
      fputc(memory[addr++],console);
    }
  }
}
static unsigned flags(const i8080 *cpu) {
  return (cpu->sf<<7)|(cpu->zf<<6)|(cpu->hf<<4)|(cpu->pf<<2)|2|cpu->cf;
}
int main(int argc, char **argv) {
  if (argc!=3) { fprintf(stderr,"usage: %s diagnostic.COM output-prefix\n",argv[0]); return 2; }
  FILE *input=fopen(argv[1],"rb");
  if (!input) { perror(argv[1]); return 1; }
  size_t bytes=fread(memory+0x100,1,0xff00,input);
  if (ferror(input) || !bytes || !feof(input)) { fputs("invalid program size\n",stderr); return 1; }
  fclose(input);
  memory[0]=0xc3; memory[1]=0x80; memory[2]=0;
  memory[5]=0xd3; memory[6]=1; memory[7]=0xc9; // CP/M BDOS service outside ROM.
  const uint8_t boot[]={0x31,0x00,0x70,0xf1,0x06,0,0x0e,0,0x16,0,0x1e,0,
                       0x26,0,0x2e,0,0xc3,0,1};
  memcpy(memory+0x80,boot,sizeof boot);
  memory[0x7000]=2; memory[0x7001]=0; // Actual POP PSW, no hidden DUT initialization.
  char path[1024];
  snprintf(path,sizeof path,"%s.mem",argv[2]); FILE *memout=fopen(path,"w");
  if (!memout) { perror(path); return 1; }
  for (unsigned addr=0;addr<65536;addr++) fprintf(memout,"%02x\n",memory[addr]);
  fclose(memout);
  snprintf(path,sizeof path,"%s.console",argv[2]); console=fopen(path,"w");
  snprintf(path,sizeof path,"%s.trace",argv[2]); FILE *trace=fopen(path,"w");
  if (!console || !trace) { perror(path); return 1; }
  i8080 cpu; i8080_init(&cpu);
  cpu.userdata=&cpu; cpu.read_byte=rb; cpu.write_byte=wb; cpu.port_in=port_in; cpu.port_out=port_out;
  unsigned long count=0;
  unsigned fully_initialized=0;
  while (!done && count<1000000) {
    if (cpu.pc==0x100 && !fully_initialized) {
      fully_initialized=1;
      // Warm-boot exit service replaces the now-unused reset trampoline.
      memory[0]=0xd3; memory[1]=0;
    }
    uint16_t before=cpu.pc;
    uint8_t op=memory[before];
    writes=0; outs=0; memset(write_address,0,sizeof write_address); memset(write_value,0,sizeof write_value);
    out_port=0; out_value=0;
    i8080_step(&cpu);
    fprintf(trace,"%04x %02x %04x %04x %02x%02x%02x%02x%02x%02x%02x %02x %x %x %x %04x %02x %04x %02x %x %02x %02x %02x %x\n",
      before,op,cpu.pc,cpu.sp,cpu.a,cpu.b,cpu.c,cpu.d,cpu.e,cpu.h,cpu.l,flags(&cpu),cpu.iff,cpu.halted,
      writes,write_address[0],write_value[0],write_address[1],write_value[1],outs,out_port,out_value,
      memory[cpu.pc],fully_initialized);
    count++;
  }
  fclose(trace); fclose(console);
  if (!done || !fully_initialized) { fputs("diagnostic did not finish\n",stderr); return 1; }
  printf("ORACLE PASSED: %s; %lu instructions; unmodified Intel oracle\n",argv[1],count);
  return 0;
}
