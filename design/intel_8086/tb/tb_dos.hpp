// External DOS service fixture, not an instruction emulator. The unchanged
// application, assembler, disassembler and debugger execute entirely in RTL.
template<class B> static void debug_software(B &b,const char *path) {
    std::ifstream input(path,std::ios::binary);
    std::vector<uint8_t> binary((std::istreambuf_iterator<char>(input)),{});
    if(binary.size()!=5999) throw std::runtime_error("original DEBUG binary length");
    b.reset();
    auto put16=[&](uint32_t a,uint16_t v){b.set(a,v);b.set(a+1,v>>8);};
    auto get16=[&](uint32_t a){return uint16_t(b.memory[a]|uint16_t(b.memory[(a+1)&0xfffff])<<8);};
    const uint8_t jump[]={0xea,0,6,0,0};
    for(unsigned i=0;i<5;++i) b.set(0xffff0+i,jump[i]);
    // Establish the COM loader's documented segment registers and stack.
    const uint8_t loader[]={0xb8,0,0x10,0x8e,0xd8,0x8e,0xc0,0x8e,0xd0,0xbc,0xfe,0xff,
                           0x50,0xb8,0,1,0x50,0xcb};
    for(unsigned i=0;i<sizeof(loader);++i) b.set(0x600+i,loader[i]);
    for(unsigned i=0;i<binary.size();++i) b.set(0x10100+i,binary[i]);
    b.set(0x10000,0xcd);b.set(0x10001,0x20);put16(0x10002,0x9000);
    b.set(0x10005,0x9a);put16(0x10006,0xfff0);put16(0x10008,0xf000);
    put16(0x1002c,0x800);b.set(0x10080,0);b.set(0x10081,13);
    for(unsigned base:{0x1005c,0x1006c})for(unsigned i=1;i<=11;++i)b.set(base+i,' ');
    for(unsigned vector:{0x20,0x21}) {put16(vector*4,vector==0x20 ? 0xf000:0xf010);put16(vector*4+2,0);}
    b.set(0xf000,0xcf);b.set(0xf010,0xcf);
    put16(0x40,0xf020);put16(0x42,0);b.set(0xf020,0xcf);
    std::string commands="r\re 100 b8 34 12 40 90\ru 100 104\rt\rt\rt\rr\rq\r";
    std::string output; size_t cursor=0; unsigned instructions=0,services=0; bool exited=false;
    for(;instructions<1000000 && !exited;++instructions) {
        b.retire(); auto r=b.read();
        if(r[9]!=0 || (r[12]!=0xf000 && r[12]!=0xf010 && r[12]!=0xf020)) continue;
        ++services;
        if(r[12]==0xf000) {exited=true;break;}
        if(r[12]==0xf020) {
            if(r[0]>>8!=15) throw std::runtime_error("unsupported external BIOS video call");
            r[0]=0x5003;r[3]&=255;b.host_registers(r);continue;
        }
        auto ah=r[0]>>8, al=r[0]&255;
        if(std::getenv("I8086_DOS_TRACE")) std::cerr<<"DOS AH="<<std::hex<<ah<<" AX="<<r[0]<<" DX="<<r[2]<<" DS="<<r[11]<<" return="<<get16(physical(r[10],r[4]))<<std::dec<<'\n';
        auto nextchar=[&](){if(cursor==commands.size()) throw std::runtime_error("DEBUG requested excess console input");return uint8_t(commands[cursor++]);};
        auto address=physical(r[11],r[2]);
        auto flags_address=physical(r[10],uint16_t(r[4]+4));
        auto cf=[&](bool carry){put16(flags_address,(get16(flags_address)&~1)|carry);};
        switch(ah) {
            case 0: exited=true;break;
            case 1: r[0]=(r[0]&0xff00)|nextchar();output+=char(r[0]);break;
            case 2: output+=char(r[2]);break;
            case 6: if((r[2]&255)!=255) output+=char(r[2]); else r[0]&=0xff00;break;
            case 7:case 8:r[0]=(r[0]&0xff00)|nextchar();break;
            case 9: {
                unsigned n=0;while(b.memory[address]!='$' && n++<65536) {output+=char(b.memory[address]);address=(address+1)&0xfffff;}
                if(n>=65536) throw std::runtime_error("unterminated DOS string");break;
            }
            case 10: {
                auto max=b.memory[address];unsigned n=0;
                while(true) {auto c=nextchar();output+=char(c);if(c==13) break;
                    if(n+1>=max) throw std::runtime_error("DOS input buffer overflow");b.set(address+2+n++,c);}
                b.set(address+1,n);b.set(address+2+n,13);output+='\n';break;
            }
            case 11:r[0]=(r[0]&0xff00)|(cursor<commands.size() ? 255:0);break;
            case 13:case 14:case 26:break;
            case 15:r[0]=(r[0]&0xff00)|255;break; // No command-line input file.
            case 0x19:r[0]&=0xff00;break;
            case 0x25:put16(al*4,r[2]);put16(al*4+2,r[11]);break;
            case 0x26:for(unsigned i=0;i<256;++i)b.set((uint32_t(r[2])<<4)+i,b.memory[0x10000+i]);break;
            case 0x29: {
                auto fcb=physical(r[8],r[7]);b.set(fcb,0);
                for(unsigned i=1;i<=11;++i)b.set(fcb+i,' ');
                r[0]&=0xff00;break;
            }
            case 0x35:r[3]=get16(al*4);r[8]=get16(al*4+2);break;
            case 48:r[0]=0x0101;r[3]=0;r[1]=0;break;
            case 74:case 73:cf(false);break;
            case 76:exited=true;break;
            default: throw std::runtime_error("unimplemented external DOS AH="+std::to_string(ah)+" at instruction "+std::to_string(instructions));
        }
        b.host_registers(r);
    }
    std::ofstream transcript("debug_transcript.log");transcript<<output;
    if(!exited || cursor!=commands.size() || output.find("AX=1234")==std::string::npos ||
       output.find("AX=1235")==std::string::npos || output.find("IP=0105")==std::string::npos ||
       output.find("B83412")==std::string::npos || output.find("MOV")==std::string::npos ||
       output.find("File not found")!=std::string::npos)
        throw std::runtime_error("historical DEBUG command/transcript/exit assertion; instructions="+
            std::to_string(instructions)+" input="+std::to_string(cursor)+" output="+output.substr(output.size()>500 ? output.size()-500:0));
    std::cout<<"PASS: unchanged Microsoft MS-DOS 1.25 DEBUG.COM, "<<instructions<<
        " RTL instructions, "<<services<<" external DOS calls; register/edit/disassemble/single-step/quit\n";
}
