// Directed architectural checks derived from Intel 1979 sections 2.6/2.10
// and original die microcode (righto.com/2023/04/8086-microcode-string-operations.html).
static void require(bool value,const std::string &message) {
    if(!value) throw std::runtime_error(message);
}
static uint16_t word(Bench &b,uint32_t address) {
    return b.memory[address&0xfffff] | (uint16_t(b.memory[(address+1)&0xfffff])<<8);
}
static void put_word(Bench &b,uint32_t address,uint16_t value) {
    b.set(address,value); b.set(address+1,value>>8);
}
static void code(Bench &b,uint32_t address,std::initializer_list<uint8_t> bytes) {
    for(auto value:bytes) b.set(address++,value);
}
static void setup(Bench &b,std::initializer_list<uint8_t> bytes,uint16_t flags=0xf002) {
    b.reset(); Registers r{}; r[4]=0x8000; r[9]=0x1000; r[12]=0x100; r[13]=flags;
    b.load(r); code(b,0x10100,bytes);
    for(unsigned vector: {0,1,2,3,4,0x20}) {
        put_word(b,vector*4,0x400+vector*16); put_word(b,vector*4+2,0);
        code(b,0x400+vector*16,{0x43,0xcf}); // INC BX; IRET.
    }
}
static void step(Bench &b,uint16_t ip,uint16_t cs=0x1000) {
    const auto before=b.read(); const auto start=physical(before[9],before[12]);
    b.retire();
    require(b.dut.ip_o==ip && b.read()[9]==cs,"control exact post-instruction CS:IP");
    require(b.saw_fetch && b.first_fetch_address==start,"control exact next-executed instruction");
}
static void entry(Bench &b,unsigned vector,uint16_t return_ip,uint16_t saved_flags) {
    for(unsigned i=0;i<1000;++i) {
        b.tick((b.cycles%7)<3);
        require(!b.dut.fault_o,"interrupt entry fault");
        if(b.dut.redirect_o && b.read()[9]==0 && b.dut.ip_o==0x400+vector*16) {
            auto sp=b.read()[4];
            require(sp==0x7ffa && word(b,sp)==return_ip && word(b,sp+2)==0x1000 &&
                word(b,sp+4)==saved_flags,"interrupt stack vector="+std::to_string(vector)+
                " SP="+std::to_string(sp)+" IP="+std::to_string(word(b,sp))+
                " CS="+std::to_string(word(b,sp+2))+" FLAGS="+std::to_string(word(b,sp+4)));
            require(!(b.dut.flags_o&0x300),"entry must clear IF/TF"); return;
        }
    }
    throw std::runtime_error("interrupt entry watchdog");
}
static void control(Bench &b) {
    unsigned cases=0;
    // STI and IRET defer INTR through exactly one following instruction.
    setup(b,{0xfb,0x90,0x90,0xf4}); b.dut.intr_i=1;
    step(b,0x101); require(b.acknowledgements==0,"STI accepted IRQ too early");
    step(b,0x102); entry(b,0x20,0x102,0xf202);
    require(b.acknowledgements==2,"IRQ must have two acknowledge cycles");
    step(b,0x601,0); step(b,0x102); step(b,0x103);
    entry(b,0x20,0x103,0xf202); ++cases;
    // CLI immediately masks a pending request at its following boundary.
    setup(b,{0xfa,0x90,0xf4},0xf202); step(b,0x101); b.dut.intr_i=1;
    step(b,0x102); require(b.acknowledgements==0,"CLI did not mask INTR"); ++cases;
    // NMI edge capture while stalled, priority over INTR; no NMI-until-IRET block.
    setup(b,{0x90,0xf4},0xf202); b.dut.nmi_i=1; b.tick(true); b.dut.intr_i=1;
    entry(b,2,0x101,0xf202); require(b.acknowledgements==0,"INTR outranked NMI");
    b.dut.nmi_i=0; b.tick(); b.dut.nmi_i=1; step(b,0x421,0);
    for(unsigned i=0;i<1000 && !(b.dut.redirect_o && b.dut.ip_o==0x420);++i) b.tick();
    require(b.read()[4]==0x7ff4 && word(b,0x7ff4)==0x421,"nested NMI edge not accepted"); ++cases;
    // TF is sampled at instruction start: POPF itself does not trap.
    setup(b,{0x9d,0x90,0xf4}); put_word(b,0x8000,0xf102);
    step(b,0x101); step(b,0x102);
    // POPF consumed two stack bytes; place the expected interrupt frame base.
    for(unsigned i=0;i<1000 && !(b.dut.redirect_o && b.dut.ip_o==0x410);++i) b.tick();
    require(b.read()[4]==0x7ffc && word(b,0x7ffc)==0x102 &&
        word(b,0x8000)==0xf102,"single step saved wrong boundary"); ++cases;
    // MOV and POP of every documented segment register inhibit NMI/INTR/TF.
    for(uint8_t modrm:{0xc0,0xd0,0xd8}) {
        setup(b,{0x8e,modrm,0x90,0xf4},0xf302);
        step(b,0x102); b.dut.nmi_i=1; step(b,0x103);
        entry(b,2,0x103,0xf302); ++cases;
    }
    for(uint8_t opcode:{0x07,0x17,0x1f}) {
        setup(b,{opcode,0x90,0xf4},0xf302); put_word(b,0x8000,0);
        step(b,0x101); b.dut.nmi_i=1; step(b,0x102);
        for(unsigned i=0;i<1000 && !(b.dut.redirect_o && b.dut.ip_o==0x420);++i) b.tick();
        require(b.read()[4]==0x7ffc && word(b,0x7ffc)==0x102,"POP segment interrupt shadow"); ++cases;
    }
    // HLT only wakes for enabled INTR or NMI; WAIT retries its own opcode.
    setup(b,{0xf4,0x90}); step(b,0x101); b.dut.intr_i=1;
    for(unsigned i=0;i<20;++i) b.tick(); require(b.dut.halted_o,"masked INTR woke HLT");
    b.dut.nmi_i=1; entry(b,2,0x101,0xf002); ++cases;
    setup(b,{0x9b,0x90},0xf202); b.dut.test_n_i=1;
    for(unsigned i=0;i<50;++i) {b.tick(); require(!b.dut.retire_o,"busy WAIT retired");}
    b.dut.intr_i=1; entry(b,0x20,0x100,0xf202);
    b.dut.intr_i=0; step(b,0x601,0); step(b,0x100); b.dut.test_n_i=0;
    step(b,0x101); step(b,0x102); ++cases;
    // REP can be interrupted after one element. Original RPTI backs up two
    // bytes, so a leading segment override is deliberately lost on restart.
    for(bool multiple:{false,true}) {
        if(multiple) setup(b,{0x26,0xf3,0xa4,0x90},0xf202);
        else setup(b,{0xf3,0xa4,0x90},0xf202);
        auto r=b.read(); r[1]=3; r[6]=0x200; r[7]=0x300; r[8]=0x2000; r[11]=0x3000; b.load(r);
        code(b,0x20200,{0x11,0x12,0x13}); code(b,0x30200,{0x21,0x22,0x23});
        for(unsigned i=0;i<500 && b.writes.empty();++i) b.tick();
        b.dut.intr_i=1; entry(b,0x20,multiple ? 0x101:0x100,0xf202);
        require(b.read()[1]==2 && b.read()[6]==0x201 && b.read()[7]==0x301,"REP partial state");
        b.dut.intr_i=0; step(b,0x601,0); step(b,multiple ? 0x101:0x100);
        step(b,multiple ? 0x103:0x102);
        require(b.memory[0x20300]==(multiple ? 0x11:0x21) && b.memory[0x20301]==0x22 &&
            b.memory[0x20302]==0x23 && b.read()[1]==0,"REP exact continuation data"); ++cases;
    }
    // HOLD interrupts no locked instruction and freezes requests while granted.
    setup(b,{0xf0,0x87,0x06,0,0x20,0x90}); put_word(b,0x2000,0x1234);
    for(unsigned i=0;i<500 && !(b.dut.bus_req_o && !b.dut.bus_fetch_o);++i) b.tick();
    b.dut.hold_i=1;
    for(unsigned i=0;i<500 && !b.dut.retire_o;++i) {b.tick(); require(!b.dut.hlda_o,"HOLD split LOCK");}
    require(b.read()[0]==0x1234 && word(b,0x2000)==0,"LOCK XCHG effects");
    for(unsigned i=0;i<20 && !b.dut.hlda_o;++i) b.tick(); require(b.dut.hlda_o,"HOLD grant absent");
    auto held=b.read(); for(unsigned i=0;i<20;++i) {b.tick(); require(!b.dut.bus_req_o && b.read()==held,"held CPU changed");}
    b.dut.hold_i=0; step(b,0x106); ++cases;
    // Interrupt vector must be read before flags overwrite its own IVT words.
    setup(b,{0xcd,3}); auto r=b.read(); r[4]=18; b.load(r);
    step(b,0x430,0); require(b.read()[4]==12,"INT IVT-alias stack pointer"); ++cases;
    // FF /2 register target is not present in the hardware corpus.
    setup(b,{0xff,0xd0,0x90}); r=b.read(); r[0]=0x180; b.load(r); code(b,0x10180,{0xc3});
    step(b,0x180); require(word(b,0x7ffe)==0x102,"CALL register pushed wrong IP");
    step(b,0x102); step(b,0x103); ++cases;
    // Intel's original CL is eight bits, with no 80186 count mask.
    for(uint8_t operation:{0xc0,0xd0,0xe0,0xf8}) {
        setup(b,{0xd3,operation,0x90});r=b.read();r[0]=0x9234;r[1]=255;r[13]=0xf003;b.load(r);
        step(b,0x102);
        uint16_t expected=operation==0xc0 ? 0x491a:operation==0xd0 ? 0x9234:operation==0xe0 ? 0:0xffff;
        require(b.read()[0]==expected,"unmasked full-byte CL shift/rotate");step(b,0x103);++cases;
    }
    // ESC is an 8086 bus/effective-address operation, not 8087 arithmetic.
    for(uint8_t op=0xd8;op<=0xdf;++op)for(uint8_t group=0;group<8;++group){
        setup(b,{op,uint8_t(0x06|(group<<3)),0x01,0x20,0x90});put_word(b,0x2001,0x5aa5);
        auto before=b.read();step(b,0x104);
        require(b.esc_events==1 && b.escaped_opcode==uint8_t(((op&7)<<3)|group) &&
            b.escaped_address==0x2001 && b.data_reads==2 && b.writes.empty(),"ESC memory event/read contract");
        before[12]=0x104;require(b.read()==before,"ESC changed architectural state");step(b,0x105);++cases;
        setup(b,{op,uint8_t(0xc0|(group<<3)),0x90});step(b,0x102);
        require(b.esc_events==1 && b.data_reads==0 && b.writes.empty(),"ESC register bus contract");step(b,0x103);++cases;
    }
    // Physical string fixtures limit CX to 127. Check the complete 16-bit
    // repeat range independently, in both directions and both operand sizes.
    for(bool wide:{false,true})for(bool down:{false,true}){
        setup(b,{0xf3,uint8_t(wide ? 0xa5:0xa4),0x90},down ? 0xf402:0xf002);
        r=b.read();r[1]=65535;r[6]=r[7]=65535;r[8]=0x4000;r[11]=0x2000;b.load(r);
        auto source=[](uint16_t offset){return uint8_t(offset^(offset>>8));};
        for(unsigned offset=0;offset<65536;++offset)b.set(0x20000+offset,source(offset));
        bool finished=false;
        for(unsigned i=0;i<6000000 && !finished;++i){b.tick((b.cycles%7)<3);finished=b.dut.retire_o;}
        auto after=b.read();unsigned size=wide ? 2:1;
        uint16_t next=uint16_t(65535+(down ? -int(size*65535):int(size*65535)));
        require(finished && !b.dut.fault_o && after[1]==0 && after[6]==next && after[7]==next &&
            after[12]==0x102 && after[9]==0x1000,"full-count REP exact final state");
        require(b.ordered_writes.size()==size*65535,"full-count REP write count");
        for(unsigned i=0;i<65535;++i)for(unsigned byte=0;byte<size;++byte){
            uint16_t offset=uint16_t(65535+(down ? -int(size*i):int(size*i))+byte);
            auto [address,value]=b.ordered_writes[size*i+byte];
            require(address==0x40000u+offset && value==source(offset),"full-count REP ordered byte effect");
        }
        step(b,0x103);++cases;
    }
    std::cout<<"PASS: "<<cases<<" documented control, interrupt, REP, WAIT and LOCK scenarios\n";
}
