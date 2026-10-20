#include "Vcia_software_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <filesystem>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

static void run(const std::string& path,const std::string& kernal_path) {
    std::ifstream input(path,std::ios::binary);
    if(!input) throw std::runtime_error("Cannot open original PRG: "+path);
    std::vector<std::uint8_t> image((std::istreambuf_iterator<char>(input)),{});
    if(image.size()<16 || image[0]!=1 || image[1]!=8) throw std::runtime_error("Unexpected PRG header");
    std::array<std::uint8_t,65536> ram{};
    std::vector<std::uint8_t> kernal;
    if(!kernal_path.empty()) {
        std::ifstream firmware(kernal_path,std::ios::binary);
        kernal.assign(std::istreambuf_iterator<char>(firmware),{});
        if(kernal.size()!=8192) throw std::runtime_error("Original KERNAL must be 8192 bytes");
    }
    std::copy(image.begin()+2,image.end(),ram.begin()+0x0801);
    unsigned entry=0;
    for(unsigned i=7;i<12;i++) {
        if(image[i]<'0' || image[i]>'9') throw std::runtime_error("Invalid BASIC SYS address");
        entry=entry*10+image[i]-'0';
    }
    if(entry!=0x080e || ram[entry]!=0xa9 || ram[entry+2]!=0x85 || ram[0x0843]!=0x8d ||
        ram[0x0844]!=0xff || ram[0x0845]!=0xd7 || ram[0x0846]!=0xa9)
        throw std::runtime_error("Original startup/checkpoint bytes changed");
    const unsigned reset_entry=kernal.empty() ? entry : 0x0200;
    ram[0xfffc]=reset_entry&255; ram[0xfffd]=reset_entry>>8;
    if(!kernal.empty()) {
        ram[0x0200]=0x20; ram[0x0201]=0x8a; ram[0x0202]=0xff;
        ram[0x0203]=0x4c; ram[0x0204]=entry&255; ram[0x0205]=entry>>8;
        ram[0x02a6]=1;
    }
    // Actual RTS instructions execute; no CPU state/PC is teleported over calls.
    if(kernal.empty()) for(unsigned address : {0xff84u,0xff8au,0xffd2u}) ram[address]=0x60;
    Vcia_software_top dut;
    dut.tod_input_i=0;
    dut.rdy_i=1;
    dut.reference_cia_i=0; dut.reference_irq_n_i=1; dut.reference_nmi_n_i=1;
    std::uint64_t cycles=0;
    std::array<std::uint64_t,2> reads{},writes{};
    const auto name=std::filesystem::path(path).stem().string();
    if(name.rfind("cia1",0)!=0 && name.rfind("cia2",0)!=0) throw std::runtime_error("Unknown CIA target");
    const unsigned target=name[3]-'1';
    unsigned boot_fetches=0;
    unsigned kernal_boot_stage=0;
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
        const unsigned address=dut.bus_addr;
        unsigned data=ram[address];
        if(!kernal.empty() && address>=0xe000 && address!=0xfffc && address!=0xfffd)
            data=address==0xffd2 ? 0x60 : kernal[address-0xe000];
        dut.memory_data_i = address==0xd011 ? 0x80 : address==0xd012 ? 0 : data;
        dut.eval();
    };
    auto tick=[&]() {
        dut.clk=1; settle();
        dut.clk=0; dut.eval(); ++cycles;
    };
    dut.clk=0; dut.rst_n=0; settle(); tick(); tick(); dut.rst_n=1;
    for(;cycles<100000000;) {
        dut.clk=1; settle();
        require(!dut.fault_o && !dut.jammed_o,"CPU fault/jam in original test");
        if(dut.fetch_o) {
            if(!kernal.empty()) {
                if(kernal_boot_stage<3) {
                    static constexpr unsigned addresses[]={0x0200,0xff8a,0xfd15};
                    static constexpr unsigned opcodes[]={0x20,0x4c,0xa2};
                    require(dut.bus_addr==addresses[kernal_boot_stage] && dut.read_data_o==opcodes[kernal_boot_stage],
                            "Exact reset/bootstrap/RESTOR instruction PC and opcode");
                    kernal_boot_stage++;
                } else if(kernal_boot_stage==3 && dut.bus_addr==0x0203) {
                    require(dut.read_data_o==0x4c,"RESTOR returns to the exact bootstrap JMP");
                    kernal_boot_stage=4;
                } else if(kernal_boot_stage==4) {
                    require(dut.bus_addr==entry && dut.read_data_o==0xa9,"Exact instruction after bootstrap JMP");
                    kernal_boot_stage=5;
                }
            }
            if(kernal.empty() && dut.bus_addr>=0xe000)
                require(dut.bus_addr==0xff84 || dut.bus_addr==0xff8a || dut.bus_addr==0xffd2,
                        "Unsupported KERNAL entry in isolated fixture");
            if(boot_fetches<2 && (kernal.empty() || dut.bus_addr==entry || boot_fetches==1)) {
                require(dut.bus_addr==entry+2*boot_fetches,"Exact startup instruction PC");
                require(ram[dut.bus_addr]==(boot_fetches==0 ? 0xa9 : 0x85),"Exact startup opcode");
                boot_fetches++;
            }
            if(dut.bus_addr==0xffd2) console+=char(dut.a_o);
            if(success) {
                require(dut.bus_addr==0x0846 && ram[dut.bus_addr]==0xa9,"Exact instruction after success store");
                require(kernal.empty() || kernal_boot_stage==5,"Original KERNAL bootstrap completed");
                require(reads[target]!=0 && writes[target]!=0,"Original software exercised the targeted CIA");
                std::cout<<"MOS 6526 LORENZ PASS: "<<path<<" environment="<<(kernal.empty()?"isolated":"901227-03")
                         <<" cycles="<<cycles<<" CIA"<<target+1<<" reads="<<reads[target]
                         <<" writes="<<writes[target]<<" success PC=0843 next PC=0846\n";
                return;
            }
        }
        if((dut.bus_addr&0xfe00)==0xdc00) {
            const unsigned chip=(dut.bus_addr>>8)&1;
            if(dut.bus_we) writes[chip]++; else reads[chip]++;
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
            if((dut.bus_addr&0xfe00)!=0xdc00 && (kernal.empty() || dut.bus_addr<0xe000))
                ram[dut.bus_addr]=dut.bus_data_o;
        }
        dut.clk=0; dut.eval(); ++cycles;
    }
    require(false,"Original CIA test timed out");
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc<2) throw std::runtime_error("Pass one or more original PRGs");
        std::string kernal_path;
        int first=1;
        if(std::string(argv[1])=="--kernal") {
            if(argc<4) throw std::runtime_error("--kernal requires firmware and original PRGs");
            kernal_path=argv[2]; first=3;
        }
        for(int i=first;i<argc;i++) run(argv[i],kernal_path);
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
