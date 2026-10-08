// Uses the immutable external Intel emulator without semantic adaptations.
#define main diagnostic_main
#include "oracle_trace.c"
#undef main

static uint8_t initial_memory[65536];
static uint32_t rng=0x80801974;
static uint8_t random_byte(void) {
  rng^=rng<<13; rng^=rng>>17; rng^=rng<<5; return (uint8_t)rng;
}
static int documented(unsigned op) {
  switch (op) {
    case 0x08:case 0x10:case 0x18:case 0x20:case 0x28:case 0x30:case 0x38:
    case 0xcb:case 0xd9:case 0xdd:case 0xed:case 0xfd:return 0;
    default:return 1;
  }
}
static void sentinel(uint16_t addr, uint8_t marker) {
  memory[addr]=0x3e; memory[(uint16_t)(addr+1)]=marker;
}
static void record(FILE *trace, i8080 *cpu, unsigned initialized) {
  uint16_t before=cpu->pc; uint8_t op=memory[before];
  writes=0; outs=0; memset(write_address,0,sizeof write_address); memset(write_value,0,sizeof write_value);
  out_port=0; out_value=0;
  i8080_step(cpu);
  fprintf(trace,"%04x %02x %04x %04x %02x%02x%02x%02x%02x%02x%02x %02x %x %x %x %04x %02x %04x %02x %x %02x %02x %02x %x\n",
    before,op,cpu->pc,cpu->sp,cpu->a,cpu->b,cpu->c,cpu->d,cpu->e,cpu->h,cpu->l,flags(cpu),cpu->iff,cpu->halted,
    writes,write_address[0],write_value[0],write_address[1],write_value[1],outs,out_port,out_value,memory[cpu->pc],initialized);
}
int main(int argc, char **argv) {
  if (argc!=2) { fputs("usage: oracle_units output.bundle\n",stderr); return 2; }
  FILE *bundle=fopen(argv[1],"w"); console=tmpfile();
  if (!bundle || !console) { perror("unit output"); return 1; }
  unsigned cases=0;
  for (unsigned op=0;op<256;op++) if (documented(op)) {
    for (unsigned variant=0;variant<32;variant++) {
      // Poison unused locations with HLT; exact PCs reject stray landings.
      memset(memory,0x76,sizeof memory);
      uint16_t bc=(uint16_t)(0x2000+((unsigned)random_byte()<<4)+random_byte());
      uint16_t de=(uint16_t)(0x4000+((unsigned)random_byte()<<4)+random_byte());
      uint16_t hl=(uint16_t)(0x6000+((unsigned)random_byte()<<4)+random_byte());
      uint16_t test_sp=variant<4 ? (uint16_t)(0xffff-variant) : 0x9002;
      uint8_t boot[]={0x31,0x00,0x90,0xf1,0x01,bc&255,bc>>8,
                     0x11,de&255,de>>8,0x21,hl&255,hl>>8,
                     0x31,test_sp&255,test_sp>>8,0xc3,0x00,0x01};
      memory[0]=0xc3; memory[1]=0x80; memory[2]=0;
      memcpy(memory+0x80,boot,sizeof boot);
      memory[0x9000]=(uint8_t)(((variant&16)<<3)|((variant&8)<<3)|((variant&4)<<2)|((variant&2)<<1)|2|(variant&1));
      memory[0x9001]=random_byte();
      memory[bc]=random_byte(); memory[de]=random_byte(); memory[hl]=random_byte();
      if (test_sp==0x9002) { memory[test_sp]=0x40; memory[test_sp+1]=0x50; }
      else {
        memory[test_sp]=0x40;
        if ((uint16_t)(test_sp+1)!=0) memory[(uint16_t)(test_sp+1)]=0x50;
      }
      uint8_t low=(uint8_t)(0x80+variant*3);
      uint16_t direct=(uint16_t)(0x5000|low);
      memory[0x100]=(uint8_t)op; memory[0x101]=low; memory[0x102]=0x50;
      unsigned length=1;
      if ((op&0xcf)==0x01 || op==0x22 || op==0x2a || op==0x32 || op==0x3a ||
          (op&0xc7)==0xc2 || (op&0xc7)==0xc4 || op==0xc3 || op==0xcd) length=3;
      else if ((op&0xc7)==0x06 || (op&0xc7)==0xc6 || op==0xd3 || op==0xdb) length=2;
      sentinel((uint16_t)(0x100+length),(uint8_t)(0xe0+variant));
      memory[direct]=random_byte(); memory[(uint16_t)(direct+1)]=random_byte();
      if ((op&0xc7)==0xc2 || (op&0xc7)==0xc4 || op==0xc3 || op==0xcd)
        sentinel(direct,(uint8_t)(0xa0+variant));
      if (op==0xe9) sentinel(hl,(uint8_t)(0xb0+variant));
      if (op==0xc9 || (op&0xc7)==0xc0) sentinel(0x5040,(uint8_t)(0xc0+variant));
      // RST0 lands on the reset JMP; all other vectors are outside bootstrap.
      if ((op&0xc7)==0xc7 && (op&0x38)!=0) sentinel((uint16_t)(op&0x38),(uint8_t)(0xd0+variant));
      if ((op==0x22 || op==0x2a) && variant==0) {
        memory[0x101]=0xff; memory[0x102]=0xff; memory[0xffff]=random_byte();
      }
      memcpy(initial_memory,memory,sizeof memory);
      i8080 cpu; i8080_init(&cpu); cpu.userdata=&cpu;
      cpu.read_byte=rb; cpu.write_byte=wb; cpu.port_in=port_in; cpu.port_out=port_out;
      FILE *trace=tmpfile(); if (!trace) { perror("unit trace"); return 1; }
      unsigned rows=0;
      while (cpu.pc!=0x100 && rows<20) { record(trace,&cpu,0); rows++; }
      if (cpu.pc!=0x100) { fputs("bootstrap did not reach tested instruction\n",stderr); return 1; }
      record(trace,&cpu,1); rows++;
      if (!cpu.halted) { record(trace,&cpu,1); rows++; } // Actual next instruction, never skipped.
      unsigned patches=0;
      for (unsigned addr=0;addr<65536;addr++) patches+=(initial_memory[addr]!=0x76);
      fprintf(bundle,"%u %02x %u %u %u\n",cases,op,variant,patches,rows);
      for (unsigned addr=0;addr<65536;addr++) if (initial_memory[addr]!=0x76)
        fprintf(bundle,"%04x %02x\n",addr,initial_memory[addr]);
      rewind(trace); int ch; while ((ch=fgetc(trace))!=EOF) fputc(ch,bundle); fclose(trace);
      cases++;
    }
  }
  fclose(bundle); fclose(console);
  if (cases!=7808) { fputs("missing documented opcodes\n",stderr); return 1; }
  printf("ORACLE PASSED: %u cases, all 244 documented opcodes and 32 flag combinations\n",cases);
  return 0;
}
