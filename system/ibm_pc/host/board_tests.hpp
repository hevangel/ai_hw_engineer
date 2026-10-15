static void check(bool ok,const std::string &message){if(!ok)throw std::runtime_error(message);}
static void test_boot(Machine &m,const std::vector<uint8_t> &code){
    m.reset();const uint8_t entry[]={0xea,0,5,0,0};
    std::copy(std::begin(entry),std::end(entry),m.memory.begin()+0xffff0);
    std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
}
static void step_to(Machine &m,unsigned ip){
    for(unsigned i=0;i<100000;++i){m.tick();if(m.board.retired){
        check(uint16_t(m.board.segs>>16)==0 && m.board.ip==ip,"directed exact CS:IP");return;}}
    throw std::runtime_error("directed retirement watchdog");
}
static void board_tests(Machine &m,const std::string &program){
    auto code=Machine::read_file(program);test_boot(m,code);m.capture_writes=true;m.keys.push_back(0x1e);
    for(unsigned i=0;i<100000 && !m.board.halted;++i)m.tick();
    check(m.board.halted && m.board.ip==0x500+code.size(),"board fixture exact final HLT");
    check(m.memory[0xfe000]=='5',"CPU write changed BIOS ROM");
    const std::vector<std::pair<unsigned,uint8_t>> expected={{0x2001,0x34},{0x2002,0x12},
        {0x2010,0x34},{0x2011,0x12},{0x2100,0x6f},{0x2101,0x1e},{0x2102,0}};
    check(m.memory_writes==expected,"board ordered byte writes / switches / keyboard acknowledgement");
    check(m.keys.empty(),"keyboard input was not consumed");
    check(m.cylinders[0]==0 && m.cylinders[1]==1,"DOR did not select the physical seek drive");
    m.capture_writes=false;
    test_boot(m,{0xb9,0xff,0,0xb8,1,0,0xd3,0xe0,0x90,0xeb,0xfd,0x90});
    step_to(m,0x500);step_to(m,0x503);step_to(m,0x506);
    for(unsigned i=0;i<1000 && !(m.board.ip==0x508 && m.board.queue_count==4);++i)m.tick();
    check(m.board.ip==0x508 && m.board.queue_count==4,"four-byte queue fill during full-CL shift");
    m.memory[0x508]=0xf4;
    step_to(m,0x508);step_to(m,0x509);check(!m.board.halted,"RAM write invalidated queued NOP");
    step_to(m,0x508);step_to(m,0x509);check(m.board.halted,"taken jump did not flush queue");
    const std::vector<uint8_t> tone={0xfa,0xb0,0x99,0xe6,0x63,0xb0,3,0xe6,0x61,
        0xb0,0xb6,0xe6,0x43,0xb0,0x98,0xe6,0x42,0xb0,0x0a,0xe6,0x42,0xf4};
    test_boot(m,tone);m.run(50000);
    check(m.board.halted && m.board.ip==0x500+tone.size(),"speaker fixture exact HLT");
    check(m.board.speaker_enabled && m.speaker_hz>=439 && m.speaker_hz<=441,"PIT channel 2 / PPI speaker 440 Hz");
    std::cout<<"PASS: byte bus, aligned/odd words, ROM protection, PIC aliases, switches, keyboard, four-byte stale/flushed queue and PIT speaker\n";
}
static void disk_tests(Machine &m,const std::string &program){
    auto original=m.disks[0],code=Machine::read_file(program);test_boot(m,code);
    for(unsigned i=0;i<10000000 && !m.board.halted;++i)m.tick();
    check(m.board.halted && m.board.ip==0x500+code.size(),"DMA format exact final HLT");
    check(m.memory[0x2200]==1 && m.memory[0x2201]==0 && m.memory[0x2202]==0,
        "DMA format normal ST0/ST1/ST2");
    check(m.media_writes==4096,"DMA format must fill all eight sectors, including last TC sector: "+std::to_string(m.media_writes));
    check(std::all_of(m.disks[1].begin(),m.disks[1].begin()+4096,[](uint8_t v){return v==0xe5;}),"DMA format bytes on drive B");
    check(m.disks[0]==original,"DMA format changed unselected drive A");
    check(m.memory[0x2210]==1 && m.memory[0x2211]==0 && m.memory[0x2212]==0,"DMA VERIFY normal result");
    check(m.board.dma_count==4128,"32 format IDs and 4096 verify pseudo-transfers");
    check(std::all_of(m.memory.begin()+0x3000,m.memory.begin()+0x4000,[](uint8_t v){return v==0;}),"VERIFY must not write RAM");
    std::cout<<"PASS: actual CPU/8237/FDC format and VERIFY of eight sectors, terminal count and physical drive B\n";
}
