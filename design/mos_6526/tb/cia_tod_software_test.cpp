#include "Vcia_software_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

static void run(const std::string& path, unsigned store, unsigned samples) {
    std::ifstream input(path, std::ios::binary);
    std::vector<std::uint8_t> image((std::istreambuf_iterator<char>(input)), {});
    if(image.size()<512 || image[0]!=1 || image[1]!=8)
        throw std::runtime_error("Original TOD PRG header/length");
    std::array<std::uint8_t,65536> ram{};
    std::copy(image.begin()+2,image.end(),ram.begin()+0x0801);
    auto require=[](bool value,const char* message) {
        if(!value) throw std::runtime_error(message);
    };
    require(ram[0x080d]==0x4c && ram[0x080e]==0x20 && ram[0x080f]==8 && ram[0x0820]==0x78 &&
            ram[store]==0x8e && ram[store+1]==0xff && ram[store+2]==0xd7 &&
            ram[store+3]==0x4c && ram[store+4]==((store+3)&255) && ram[store+5]==((store+3)>>8),
            "Original TOD instruction checkpoints changed");
    ram[0xfffc]=0x0d; ram[0xfffd]=8;
    Vcia_software_top dut;
    dut.rdy_i=1; dut.reference_cia_i=0; dut.reference_irq_n_i=1; dut.reference_nmi_n_i=1;
    std::uint64_t cycles=0, tod_edges=0, tod_reads=0;
    unsigned startup=0, result=0;
    bool result_written=false;
    auto settle=[&]() {
        // Explicit nominal PAL test stimulus. No DMA; the original programs
        // measure elapsed frames, so TOD edges share that 19656-clock period.
        dut.tod_input_i=(cycles%19656)<9828;
        dut.eval();
        const unsigned address=dut.bus_addr, line=(cycles/63)%312;
        dut.memory_data_i=address==0xd011 ? ((ram[address]&127)|(line>=256?128:0)) :
                          address==0xd012 ? (line&255) : ram[address];
        dut.eval();
    };
    dut.clk=0; dut.rst_n=0;
    for(unsigned i=0;i<2;++i) {
        dut.clk=1; settle(); dut.clk=0; dut.eval(); ++cycles;
    }
    dut.rst_n=1;
    while(cycles<30000000) {
        dut.clk=1; settle();
        require(!dut.fault_o && !dut.jammed_o,"CPU fault/jam in original TOD software");
        if(dut.fetch_o) {
            if(startup<2) {
                require(dut.bus_addr==(startup?0x0820:0x080d) &&
                        dut.read_data_o==(startup?0x78:0x4c),"Exact TOD entry and next executed PC/opcode");
                ++startup;
            }
            if(result_written) {
                require(dut.bus_addr==store+3 && dut.read_data_o==0x4c,"Exact instruction after TOD result store");
                require(ram[6]==samples && tod_edges>100 && tod_reads>100,
                        "Original TOD sample count and live clock exercise");
                std::cout<<path<<" cycles="<<cycles<<" samples="<<unsigned(ram[6])
                         <<" TOD edges="<<tod_edges<<" reads="<<tod_reads<<" result="<<result<<'\n';
                require(result==0,"Original TOD comparison table reported FAILURE");
                std::cout<<"MOS 6526 TOD SOFTWARE PASS: "<<path<<'\n';
                return;
            }
        }
        if(cycles%19656==0) ++tod_edges;
        if(!dut.bus_we && dut.bus_addr>=0xdd08 && dut.bus_addr<=0xdd0b) ++tod_reads;
        if(dut.bus_we) {
            if(dut.bus_addr==0xd7ff) {
                require(dut.pc_o==store+3 && startup==2,"Exact TOD result-store post-instruction PC");
                result_written=true; result=dut.bus_data_o;
            }
            if((dut.bus_addr&0xfe00)!=0xdc00) ram[dut.bus_addr]=dut.bus_data_o;
        }
        dut.clk=0; dut.eval(); ++cycles;
    }
    throw std::runtime_error("Original TOD software timed out");
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc!=3) throw std::runtime_error("Pass original read-latch.prg and write-stop.prg");
        run(argv[1],0x08c0,21);
        run(argv[2],0x0938,45);
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
