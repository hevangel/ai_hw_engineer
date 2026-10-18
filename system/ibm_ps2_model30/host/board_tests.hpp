static void board_tests(Machine &m,const std::string &path){
    const auto code=Machine::read_file(path);
    if(code.size()<6)throw std::runtime_error("board fixture size");
    m.harddisk.present=false;m.physical_drives=3;
    m.reset();
    // A synthetic external ROM fixture, with CPU state still supplied only
    // by the real reset vector. No architectural registers are injected.
    const uint8_t vector[]={0xea,0x00,0x05,0x00,0x00};
    std::copy(std::begin(vector),std::end(vector),m.memory.begin()+0xffff0);
    std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
    const unsigned remap=code[code.size()-6]|(code[code.size()-5]<<8);
    const unsigned remap_end=code[code.size()-4]|(code[code.size()-3]<<8);
    std::copy(code.begin()+remap-0x500,code.begin()+remap_end-0x500,m.memory.begin()+0xf8000);
    for(unsigned i=0;i<1000000 && !m.board.halted;++i)m.tick();
    if(!m.board.halted || m.memory[0x400]!=0x5a)
        throw std::runtime_error("board fixture failure stage="+std::to_string(m.memory[0x400])+" at "+m.location());
    const unsigned next=code[code.size()-2]|(code.back()<<8);
    if(m.board.ip!=next || uint16_t(m.board.segs>>16)!=0 || m.memory[next]!=0x90)
        throw std::runtime_error("board fixture exact post-HLT PC/next opcode");
    if(!m.board.refresh_count || m.board.fault)throw std::runtime_error("board refresh/fault");
    for(unsigned line=0;line<16;++line)if(m.font[3*16+line]!=0xa0+line)
        throw std::runtime_error("MCGA font scan-line plane load");
    if(m.board.scan_set!=1)throw std::runtime_error("keyboard scan-set selection");
    for(unsigned i=0;i<1000 && !m.board.key_ready;++i)m.tick();
    if(!m.board.key_ready)throw std::runtime_error("F6 must enable scanning after defaults");
    const auto ram_before=m.memory;
    const auto heads_before=m.cylinders;
    m.harddisk.present=false;m.physical_drives=3;
    m.reset();
    if(m.memory!=ram_before || m.cylinders!=heads_before ||
        m.board.rootp->ibm_ps2_model30__DOT__rtc__DOT__registers[9]!=0x87 ||
        m.board.ip!=0 || uint16_t(m.board.segs>>16)!=65535)
        throw std::runtime_error("reset must retain external RAM/heads/battery while resetting the CPU");
    std::cout<<"PASS: native/odd memory lanes, serialized word I/O, 4 MHz DMA registers, page readback, ROM protection, RAM remap/disable, MCGA DAC/modes/enable/font self-load, keyboard reset/ID/scan-set/ack, UART loopback/IRQ identification, RTC RAM, exact HLT PC and reset retention\n";
}
static void disk_tests(Machine &m,const std::string &path){
    const auto code=Machine::read_file(path),original_a=m.disks[0],original_b=m.disks[1];
    m.harddisk.present=false;m.physical_drives=3;
    m.reset();
    const uint8_t vector[]={0xea,0,5,0,0};
    std::copy(std::begin(vector),std::end(vector),m.memory.begin()+0xffff0);
    std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
    for(unsigned i=0;i<20000000 && !m.board.halted;++i)m.tick();
    if(!m.board.halted || m.board.ip!=0x500+code.size())
        throw std::runtime_error("disk fixture exact HLT PC at "+m.location());
    for(unsigned base:{0x2200u,0x2210u,0x2220u})
        if(m.memory[base]!=(base==0x2210u ? 1:5) || m.memory[base+1]!=0 || m.memory[base+2]!=0)
            throw std::runtime_error("disk normal ST0/ST1/ST2 at "+std::to_string(base));
    const uint8_t verify_id[]={0,1,1,2};
    if(!std::equal(std::begin(verify_id),std::end(verify_id),m.memory.begin()+0x2213))
        throw std::runtime_error("multi-track head-zero terminal count result CHRN");
    if(m.media_writes!=4608 || m.board.dma_count!=9252)
        throw std::runtime_error("disk byte/DMA counts writes="+std::to_string(m.media_writes)+" DMA="+std::to_string(m.board.dma_count));
    for(unsigned i=0;i<4608;++i)if(m.disks[1][4608+i]!=0xe5 || m.memory[0x64100+i]!=0xe5)
        throw std::runtime_error("head 1 format/readback bytes into nonzero DMA page");
    if(m.disks[0]!=original_a || !std::equal(m.disks[1].begin(),m.disks[1].begin()+4608,original_b.begin()) ||
        !std::equal(m.disks[1].begin()+9216,m.disks[1].end(),original_b.begin()+9216))
        throw std::runtime_error("format changed unselected drive/head/track");
    if(!std::all_of(m.memory.begin()+0x53000,m.memory.begin()+0x54200,[](uint8_t v){return v==0;}))
        throw std::runtime_error("DMA VERIFY wrote RAM");
    std::cout<<"PASS: CPU/4 MHz DMA/FDC nine-sector head-1 format, exact final-ID TC, VERIFY, physical drive B, nonzero page readback and unselected-media integrity; "
        <<m.board.cycle_count<<" clocks, "<<m.board.dma_count<<" DMA transfers, "<<m.media_writes<<" media writes\n";
}
