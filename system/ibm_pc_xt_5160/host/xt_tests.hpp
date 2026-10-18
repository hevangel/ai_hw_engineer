static void xt_fpu_tests(Machine &m,const std::string &path){
    auto code=Machine::read_file(path);m.reset();
    const uint8_t jump[]={0xea,0,5,0,0};std::copy(std::begin(jump),std::end(jump),m.memory.begin()+0xffff0);
    std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
    for(unsigned i=0;i<3000000&&!m.board.halted;++i)m.tick();
    if(!m.board.halted||m.board.ip!=0x500+code.size())throw std::runtime_error("8087 CPU fixture exact final PC");
    uint32_t result=0;std::copy(m.memory.begin()+0x2000,m.memory.begin()+0x2004,reinterpret_cast<uint8_t*>(&result));
    if(result!=42||m.board.fpu_commands<5)throw std::runtime_error("CPU-issued 8087 calculation failed");
    std::cout<<"PASS actual 8088 ESC/WAIT, 8087 arithmetic, coprocessor memory arbitration and exact final PC\n";
}
