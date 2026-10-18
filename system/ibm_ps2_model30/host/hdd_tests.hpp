static void harddisk_tests(Machine &m,const std::string &path){
    auto code=Machine::read_file(path);
    m.harddisk.present=true;m.physical_drives=1;m.reset();
    const uint8_t vector[]={0xea,0,5,0,0};
    std::copy(std::begin(vector),std::end(vector),m.memory.begin()+0xffff0);
    std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
    for(unsigned i=0;i<2000000 && !m.board.halted;++i)m.tick();
    if(!m.board.halted || m.memory[0x400]!=0x5a)
        throw std::runtime_error("hard disk fixture stage="+std::to_string(m.memory[0x400])+" at "+m.location());
    unsigned next=code[code.size()-2]|(code.back()<<8);
    if(m.board.ip!=next || m.memory[next]!=0x90 || uint16_t(m.board.segs>>16)!=0)
        throw std::runtime_error("hard disk exact post-HLT PC/next opcode");
    if(m.board.dma_count!=2048 || m.harddisk.writes!=1036 || m.memory[0x401]!=2)
        throw std::runtime_error("hard disk DMA/media/IRQ count mismatch: DMA="+std::to_string(m.board.dma_count)+" writes="+std::to_string(m.harddisk.writes));
    for(unsigned i=0;i<1024;++i){
        if(m.harddisk.data[67*512+i]!=uint8_t(i) || m.memory[0x62301+i]!=uint8_t(i))
            throw std::runtime_error("hard disk payload/readback mismatch at "+std::to_string(i));
    }
    if(m.memory[0x62300]!=0 || m.memory[0x62701]!=0)
        throw std::runtime_error("hard disk DMA changed adjacent memory");
    std::cout<<"PASS: original DBA ports, type-26 sense, DMA3/page82 odd byte lanes, two-sector cylinder rollover, VERIFY, invalid-command recovery, READ ID, PIC IRQ5 and exact HLT PC; "
        <<m.board.cycle_count<<" clocks, "<<m.board.dma_count<<" DMA transfers\n";
}
