#include "Vcia_software_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

static void run(const std::string& path) {
    std::ifstream input(path,std::ios::binary);
    if(!input) throw std::runtime_error("Cannot open original PRG: "+path);
    std::vector<std::uint8_t> image((std::istreambuf_iterator<char>(input)),{});
    if(image.size()<16 || image[0]!=1 || image[1]!=8) throw std::runtime_error("Unexpected PRG header");
    std::array<std::uint8_t,65536> ram{};
    std::copy(image.begin()+2,image.end(),ram.begin()+0x0801);
    unsigned entry=0;
    for(unsigned i=7;i<12;i++) {
        if(image[i]<'0' || image[i]>'9') throw std::runtime_error("Invalid BASIC SYS address");
        entry=entry*10+image[i]-'0';
    }
    if(entry!=0x080e || ram[entry]!=0xa9 || ram[entry+2]!=0x85 || ram[0x0843]!=0x8d ||
        ram[0x0844]!=0xff || ram[0x0845]!=0xd7 || ram[0x0846]!=0xa9)
        throw std::runtime_error("Original startup/checkpoint bytes changed");
    ram[0xfffc]=entry&255; ram[0xfffd]=entry>>8;
    // Actual RTS instructions execute; no CPU state/PC is teleported over calls.
    for(unsigned address : {0xff84u,0xff8au,0xffd2u}) ram[address]=0x60;
    Vcia_software_top dut;
    std::uint64_t cycles=0, reads=0, writes=0;
    unsigned boot_fetches=0;
    bool success=false;
    std::string console;
    auto require=[&](bool ok,const std::string& message) {
        if(!ok) {
            std::cerr<<path<<" cycle="<<cycles<<" PC="<<std::hex<<dut.pc_o<<" bus="<<dut.bus_addr
                     <<std::dec<<" output="<<console<<'\n';
            throw std::runtime_error(message);
        }
    };
    auto settle=[&]() {
        dut.eval();
        dut.memory_data_i = dut.bus_addr==0xd011 ? 0x80 : dut.bus_addr==0xd012 ? 0 : ram[dut.bus_addr];
        dut.eval();
    };
    auto tick=[&]() {
        dut.clk=1; settle();
        dut.clk=0; dut.eval(); ++cycles;
    };
    dut.clk=0; dut.rst_n=0; settle(); tick(); tick(); dut.rst_n=1;
    for(;cycles<10000000;) {
        dut.clk=1; settle();
        require(!dut.fault_o && !dut.jammed_o,"CPU fault/jam in original test");
        if(dut.fetch_o) {
            if(dut.bus_addr>=0xe000)
                require(dut.bus_addr==0xff84 || dut.bus_addr==0xff8a || dut.bus_addr==0xffd2,
                        "Unsupported KERNAL entry in isolated fixture");
            if(boot_fetches<2) {
                require(dut.bus_addr==entry+2*boot_fetches,"Exact startup instruction PC");
                require(ram[dut.bus_addr]==(boot_fetches==0 ? 0xa9 : 0x85),"Exact startup opcode");
                boot_fetches++;
            }
            if(dut.bus_addr==0xffd2) console+=char(dut.a_o);
            if(success) {
                require(dut.bus_addr==0x0846 && ram[dut.bus_addr]==0xa9,"Exact instruction after success store");
                require(reads>100 && writes>100,"Original software exercised CIA transactions");
                std::cout<<"MOS 6526 LORENZ PASS: "<<path<<" cycles="<<cycles<<" CIA reads="<<reads
                         <<" writes="<<writes<<" success PC=0843 next PC=0846\n";
                return;
            }
        }
        if((dut.bus_addr&0xff00)==0xdc00) {
            if(dut.bus_we) writes++; else reads++;
            if(std::getenv("CIA_TRACE")) std::cerr<<cycles<<" PC="<<std::hex<<dut.pc_o<<" addr="<<dut.bus_addr
                <<(dut.bus_we ? " W=" : " R=")<<unsigned(dut.bus_we ? dut.bus_data_o : dut.read_data_o)
                <<" TA="<<dut.ta_count_o<<" UF="<<unsigned(dut.ta_underflow_o)<<std::dec<<'\n';
        }
        if(dut.bus_we) {
            if(dut.bus_addr==0xd7ff) {
                require(dut.bus_data_o==0,"Original test reported FAILURE");
                require(dut.pc_o==0x0846 && boot_fetches==2,"Success mailbox exact post-instruction PC");
                success=true;
            }
            if((dut.bus_addr&0xff00)!=0xdc00) ram[dut.bus_addr]=dut.bus_data_o;
        }
        dut.clk=0; dut.eval(); ++cycles;
    }
    require(false,"Original CIA test timed out");
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc<2) throw std::runtime_error("Pass one or more original PRGs");
        for(int i=1;i<argc;i++) run(argv[i]);
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
