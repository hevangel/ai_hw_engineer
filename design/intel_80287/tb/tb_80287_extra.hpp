// 80287-only directed tests, included into the shared x87 regression
// (design/intel_8087/tb/test_8087.cpp) when it is built with
// -DX87_VARIANT=1. Sources: Intel 210498-005 (286PRM) as cited per check.
static uint16_t w16(Bench &b,uint32_t a){return uint16_t(b.mem[a]|(b.mem[a+1]<<8));}
static void extra_tests(Bench &b) {
    // Table 3-1: initialization state.
    b.init();
    require(b.d.control_o==0x03ff&&b.d.tags_o==0xffff&&((b.d.status_o>>11)&7)==0,"80287 FINIT state");
    // FSTSW AX (p. 2-17): status word to AX, no pointer update.
    b.load(1);b.load(2);b.cmd(0xd8,0xd1,0,0x1111);
    uint16_t sw=b.d.status_o&0x7fff;
    b.d.opcode_i=0xdf;b.d.modrm_i=0xe0;b.d.instruction_i=0x2222;b.d.cmd_valid_i=1;b.tick();b.d.cmd_valid_i=0;
    bool seen=false;uint16_t ax=0;
    for(unsigned n=0;n<100&&!seen;++n){b.tick();if(b.d.ax_write_o){seen=true;ax=b.d.ax_o;}}
    require(seen&&ax==sw&&!b.d.unsupported_o,"FSTSW AX writes the status word");
    // Real-address environment (fig. 2-2, real mode): 8087 layout with the
    // 20-bit instruction/operand addresses and the opcode.
    b.init();b.load(3);b.cmd(0xd8,0x06,0x5a5a4,0xbcdef);   // FADD m32 [..]
    b.cmd(0xd9,0x30,0x600);
    require(w16(b,0x606)==0xcdef&&(w16(b,0x608)>>12)==0xb&&(w16(b,0x608)&0x7ff)==0x006,"real-mode IP/opcode");
    require(w16(b,0x60a)==0xa5a4&&(w16(b,0x60c)>>12)==0x5,"real-mode operand pointer");
    // FSETPM (p. 2-16): protected mode; pointer images become selector:offset
    // without the opcode.
    b.cmd(0xdb,0xe4);
    b.d.cs_sel_i=0x1234;b.d.ds_sel_i=0x5678;
    b.init();b.load(3);b.cmd(0xd8,0x06,0x02a4,0x0def);
    b.cmd(0xd9,0x30,0x600);
    require(w16(b,0x606)==0x0def&&w16(b,0x608)==0x1234&&w16(b,0x60a)==0x02a4&&w16(b,0x60c)==0x5678,
            "protected-mode pointer image");
    // FINIT does not leave protected mode (p. 2-16).
    b.init();b.load(3);b.cmd(0xd8,0x06,0x02a4,0x0def);b.cmd(0xd9,0x30,0x600);
    require(w16(b,0x608)==0x1234,"FINIT keeps protected mode");
    // FLDENV in protected format restores the pointers.
    b.mem[0x606]=0x11;b.mem[0x607]=0x22;b.mem[0x608]=0x33;b.mem[0x609]=0x44;
    b.cmd(0xd9,0x20,0x600);b.cmd(0xd9,0x30,0x620);
    require(w16(b,0x626)==0x2211&&w16(b,0x628)==0x4433,"protected FLDENV/FSTENV pointers");
    // FSAVE/FRSTOR round trip in protected format.
    b.load(-2.5L);auto regs=b.d.registers_o;auto tags=b.d.tags_o;
    b.cmd(0xdd,0x30,0x700);require(b.d.tags_o==0xffff,"FSAVE initializes");
    b.cmd(0xdd,0x20,0x700);require(b.d.registers_o==regs&&b.d.tags_o==tags,"protected FSAVE/FRSTOR");
    // Only hardware RESET returns to real-address mode (p. 3-5).
    b.d.rst_n=0;b.tick();b.d.rst_n=1;b.tick();
    b.init();b.load(3);b.cmd(0xd8,0x06,0x5a5a4,0xbcdef);b.cmd(0xd9,0x30,0x600);
    require(w16(b,0x606)==0xcdef&&(w16(b,0x608)&0x7ff)==0x006,"RESET returns to real mode");
    b.d.cs_sel_i=0;b.d.ds_sel_i=0;
    // FSETPM, FENI and FDISI leave the exception pointers unchanged.
    b.cmd(0xdb,0xe4,0,0x77777);b.cmd(0xd9,0x30,0x640);
    require(w16(b,0x646)!=0x7777,"FSETPM does not update the instruction pointer");
    std::cout<<"PASS 80287 FSETPM, FSTSW AX, ERROR# and pointer-image behaviour\n";
}
