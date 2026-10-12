static uint32_t number(std::istream &in,unsigned bytes) {
    uint32_t value=0;
    for(unsigned i=0;i<bytes;++i) {
        int c=in.get(); if(c<0) throw std::runtime_error("truncated fixture");
        value|=uint32_t(c)<<(8*i);
    }
    return value;
}
static Registers registers(std::istream &in) {
    Registers r{}; for(auto &v:r) v=number(in,2); return r;
}
static std::vector<std::pair<uint32_t,uint8_t>> pairs(std::istream &in) {
    std::vector<std::pair<uint32_t,uint8_t>> result;
    auto n=number(in,4);
    for(uint32_t i=0;i<n;++i) {auto a=number(in,4); auto v=number(in,1); result.emplace_back(a,v);}
    return result;
}
static std::unordered_map<uint32_t,uint8_t> ram(std::istream &in) {
    auto data=pairs(in); return {data.begin(),data.end()};
}
static void compare(const Registers &actual,const Registers &expected,uint16_t mask) {
    static const char *names[]={"AX","CX","DX","BX","SP","BP","SI","DI","ES","CS","SS","DS","IP","FLAGS"};
    for(unsigned i=0;i<14;++i) {
        auto difference=actual[i]^expected[i]; if(i==13) difference&=mask;
        if(difference) throw std::runtime_error(std::string(names[i])+" actual="+
            std::to_string(actual[i])+" expected="+std::to_string(expected[i]));
    }
}
static void next_nop(Bench &b,const Registers &expected) {
    auto prior_flags=b.dut.flags_o;
    auto address=physical(expected[9],expected[12]);
    b.set(address,0x90); b.writes.clear(); b.ordered_writes.clear(); b.retire();
    auto after=expected; after[12]++; after[13]=prior_flags;
    compare(b.read(),after,65535);
    if(!b.saw_fetch || b.fetch_address!=address || b.fetch_byte!=0x90 || !b.writes.empty())
        throw std::runtime_error("next executed instruction was not the exact target NOP");
}
static void vectors(Bench &b,const char *path) {
    std::ifstream input(path,std::ios::binary); if(!input) throw std::runtime_error("missing vector file");
    std::string magic(8,'\0'); input.read(magic.data(),8);
    if(magic!=std::string("8086V4\0\0",8)) throw std::runtime_error("bad vector header");
    unsigned count=0; std::string label;
    try {
        while(input.peek()!=EOF) {
            auto n=number(input,2); label.resize(n); input.read(label.data(),n);
            auto initial=registers(input),expected=registers(input); auto mask=number(input,2);
            auto initial_ram=ram(input),expected_ram=ram(input);
            auto expected_writes=pairs(input);
            auto byte_masks=ram(input);
            auto initial_queue=pairs(input);
            const char *filter=std::getenv("I8086_VECTOR_PREFIX");
            if(filter && label.rfind(filter,0)!=0) continue;
            for(auto [a,v]:initial_ram) if(!expected_ram.count(a)) expected_ram[a]=v;
            b.reset(); b.load(initial);
            b.seed_queue(initial_queue);
            for(auto [a,v]:initial_ram) b.set(a,v);
            b.retire(); compare(b.read(),expected,mask);
            for(auto [a,v]:expected_ram) if(((b.memory[a]^v)&(byte_masks.count(a) ? byte_masks[a]:255))!=0)
                throw std::runtime_error("memory mismatch at "+std::to_string(a));
            for(auto [a,v]:b.writes) if(!expected_ram.count(a) ||
                ((expected_ram[a]^v)&(byte_masks.count(a) ? byte_masks[a]:255))!=0)
                throw std::runtime_error("unlisted/incorrect write at "+std::to_string(a));
            bool write_match=b.ordered_writes.size()==expected_writes.size();
            for(size_t i=0;write_match && i<expected_writes.size();++i) {
                auto [a,v]=expected_writes[i]; auto [actual_a,actual_v]=b.ordered_writes[i];
                write_match=a==actual_a && ((v^actual_v)&(byte_masks.count(a) ? byte_masks[a]:255))==0;
            }
            if(!write_match)
                throw std::runtime_error("ordered byte writes differ from the hardware bus trace");
            if(!b.dut.halted_o) next_nop(b,expected);
            else { b.tick(); if(b.request() || b.dut.retire_o) throw std::runtime_error("HLT did not stay idle"); }
            ++count;
        }
    } catch(const std::exception &error) {
        throw std::runtime_error(label+": "+error.what());
    }
    if(!count) throw std::runtime_error("empty fixture run");
    std::cout<<"PASS: "<<count<<" physical-chip vectors, exact state/memory/next instruction\n";
}
