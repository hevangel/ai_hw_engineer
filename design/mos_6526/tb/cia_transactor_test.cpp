#include "Vcia_software_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#define CHIPS_IMPL
#include "m6526.h"
extern "C" {
void *initAndResetChip(void); void destroyChip(void *); void oracle_cycle(void *);
void oracle_pins(void *,int,int,int); int oracle_sync(void *);
void oracle_read_data(void *,unsigned char);
unsigned short readAddressBus(void *); unsigned char readDataBus(void *); unsigned int readRW(void *);
extern unsigned char memory[65536];
}
static std::vector<unsigned char> binary(const char *path) {
    std::ifstream file(path,std::ios::binary);
    if(!file) throw std::runtime_error(std::string("Cannot open ")+path);
    return std::vector<unsigned char>((std::istreambuf_iterator<char>(file)),{});
}
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if(argc!=6) throw std::runtime_error("Pass KERNAL, BASIC ROM, original BASIC source, rtl/reference/netlist, loss profile");
        const auto rom=binary(argv[1]), basic_rom=binary(argv[2]);
        if(rom.size()!=8192 || basic_rom.size()!=8192) throw std::runtime_error("Original ROM size");
        const std::string mode=argv[4];
        if(mode!="rtl" && mode!="reference" && mode!="netlist") throw std::runtime_error("Unknown test mode");
        const bool reference=mode=="reference", netlist=mode=="netlist", affected=std::string(argv[5])=="1";
        if(reference && !affected) throw std::runtime_error("Unchanged external CIA implements the affected profile");
        std::ifstream basic(argv[3]); std::string line;
        std::vector<unsigned char> payload;
        unsigned sum=0;
        while(std::getline(basic,line)) {
            const auto position=line.find(" data "); if(position==std::string::npos) continue;
            line=line.substr(position+6); std::replace(line.begin(),line.end(),',',' ');
            std::istringstream numbers(line); unsigned byte;
            while(numbers>>byte) {
                if(byte>255) throw std::runtime_error("Original DATA byte range");
                payload.push_back(byte); sum+=byte;
            }
        }
        if(payload.size()!=104 || sum!=11949) throw std::runtime_error("Original DATA checksum/length");
        for(unsigned timer=0;timer<2;timer++) {
            Vcia_software_top dut;
            dut.rdy_i=1; dut.reference_cia_i=reference; dut.reference_irq_n_i=1; dut.reference_nmi_n_i=1;
            std::array<unsigned char,65536> ram{};
            std::copy(payload.begin(),payload.end(),ram.begin()+0x3200);
            // Original RESTOR/IOINIT, original SYS payload, then actual BASIC WAIT.
            const unsigned char boot[]={0x20,0x8a,0xff,0x20,0x84,0xff,0x20,0x00,0x32,0xa0,0x00,0x4c,0x40,0xb8};
            const unsigned char preboot[]={0xa2,0xfd,0x9a,0xa9,0x00,0xa0,0x00,0x18,0xd8,0xb8,0x78,0x4c,0x00,0x02};
            std::copy(std::begin(boot),std::end(boot),ram.begin()+0x0200);
            std::copy(std::begin(preboot),std::end(preboot),ram.begin()+0x0300);
            ram[0x02a6]=1; ram[0xfb]=timer ? 255:0;
            // Parsed arguments of the original WAIT 198,7 (documented ROM ABI).
            ram[0x14]=0xc6; ram[0x15]=0; ram[0x49]=7; ram[0x4a]=0;
            m6526_t chips[2]; m6526_init(&chips[0]); m6526_init(&chips[1]);
            unsigned reference_data=0,stars=0,nmis=0,loss_reads=0,adjacent=0,last_read=0,stalls=0;
            unsigned boot_index=0,payload_exit=0,compared=0;
            bool exit_jump=false;
            void *gold=nullptr;
            const unsigned limit=netlist ? 500000 : 1000000;
            auto require=[&](bool condition,const char *message) {
                if(!condition) {
                    std::cerr<<mode<<" profile="<<affected<<" timer="<<timer<<" PC="<<std::hex<<dut.pc_o
                             <<" bus="<<dut.bus_addr<<std::dec<<'\n';
                    throw std::runtime_error(message);
                }
            };
            auto settle=[&] {
                dut.eval(); const unsigned address=dut.bus_addr;
                unsigned data=ram[address];
                if(address>=0xe000) data=rom[address-0xe000];
                if(address>=0xa000 && address<0xc000) data=basic_rom[address-0xa000];
                if(address==0xfffc) data=0;
                if(address==0xfffd) data=3;
                if(address==0xffd2) data=0x60;
                if(address==0xd011) data=0x80;
                if(address==0xd012) data=0;
                if(reference && (address&0xfe00)==0xdc00) data=reference_data;
                dut.memory_data_i=data; dut.eval();
            };
            dut.clk=0; dut.rst_n=0; settle();
            for(unsigned i=0;i<2;i++) { dut.clk=1;settle();dut.clk=0;dut.eval(); }
            dut.rst_n=1;
            for(unsigned cycle=0;cycle<limit;cycle++) {
                // Legal RDY read holds sweep the missing board/DMA phase. No
                // payload/handler byte changes, skips or forced CPU state.
                dut.rdy_i=!(cycle%127==0 && dut.bus_addr>=0xb83e && dut.bus_addr<=0xb848);
                stalls+=!dut.rdy_i;
                dut.clk=1;dut.eval();
                if(reference) {
                    for(unsigned index=0;index<2;index++) {
                        uint64_t pins=0; M6526_SET_PAB(pins,255,255);
                        if((dut.bus_addr>>8)==(0xdc+index)) {
                            pins|=M6526_CS|(dut.bus_addr&15);
                            if(!dut.bus_we) pins|=M6526_RW;
                            else M6526_SET_DATA(pins,uint64_t(dut.bus_data_o));
                        }
                        pins=m6526_tick(&chips[index],pins);
                        if((dut.bus_addr>>8)==(0xdc+index)) reference_data=M6526_GET_DATA(pins);
                        if(index==0) dut.reference_irq_n_i=!(pins&M6526_IRQ);
                        else dut.reference_nmi_n_i=!(pins&M6526_IRQ);
                    }
                }
                settle(); require(!dut.fault_o && !dut.jammed_o,"Original software CPU fault/jam");
                if(netlist && !gold && dut.fetch_o && dut.bus_addr==0x0200) {
                    std::copy(ram.begin(),ram.end(),memory);
                    std::copy(rom.begin(),rom.end(),memory+0xe000);
                    std::copy(basic_rom.begin(),basic_rom.end(),memory+0xa000);
                    memory[0xfffc]=0; memory[0xfffd]=3; memory[0xffd2]=0x60;
                    gold=initAndResetChip(); unsigned startup=0;
                    while(!oracle_sync(gold) || readAddressBus(gold)!=0x0200) {
                        oracle_cycle(gold); require(++startup<100,"Independent transistor bootstrap");
                    }
                }
                if(gold) {
                    oracle_pins(gold,dut.rdy_i,dut.irq_n_o,dut.nmi_n_o);
                    require(readAddressBus(gold)==dut.bus_addr && bool(!readRW(gold))==bool(dut.bus_we) &&
                            (!dut.bus_we || readDataBus(gold)==dut.bus_data_o),"Independent transistor CPU bus mismatch");
                    if(!dut.bus_we) { memory[dut.bus_addr]=dut.read_data_o; oracle_read_data(gold,dut.read_data_o); }
                }
                if(dut.fetch_o) {
                    if(boot_index<12) {
                        static constexpr unsigned addresses[]={0x300,0x302,0x303,0x305,0x307,0x308,0x309,0x30a,0x30b,0x200,0xff8a,0xfd15};
                        static constexpr unsigned opcodes[]={0xa2,0x9a,0xa9,0xa0,0x18,0xd8,0xb8,0x78,0x4c,0x20,0x4c,0xa2};
                        require(dut.bus_addr==addresses[boot_index] && dut.read_data_o==opcodes[boot_index],"Exact reset/ROM bootstrap instruction");
                        boot_index++;
                    }
                    if(exit_jump) { require(dut.bus_addr==0xfebc && dut.read_data_o==0x68,"Exact original NMI exit JMP target"); exit_jump=false; }
                    if(dut.bus_addr==0x3265) exit_jump=true;
                    if(payload_exit>0 && payload_exit<4) {
                        static constexpr unsigned addresses[]={0,0x0209,0x020b,0xb840};
                        static constexpr unsigned opcodes[]={0,0xa0,0x4c,0xb1};
                        require(dut.bus_addr==addresses[payload_exit] && dut.read_data_o==opcodes[payload_exit],"Exact payload return and next WAIT instructions");
                        payload_exit++;
                    }
                    if(dut.bus_addr==0x3247 && payload_exit==0) { require(dut.read_data_o==0x60,"Original payload RTS"); payload_exit=1; }
                    if(dut.bus_addr==0x3248) { require(dut.read_data_o==0x48,"Original NMI entry opcode"); nmis++; }
                    if(dut.bus_addr==0xffd2) { require(dut.a_o==42,"Only original error stars reach console"); stars++; }
                }
                if(dut.tb2_event_o && cycle==last_read+1) adjacent++;
                if(dut.tb2_read_loss_o) loss_reads++;
                if(dut.bus_addr==0xdd0d && !dut.bus_we) last_read=cycle;
                if(dut.bus_we && dut.bus_addr<0xe000 && (dut.bus_addr&0xfe00)!=0xdc00)
                    ram[dut.bus_addr]=dut.bus_data_o;
                dut.clk=0;dut.eval();
                if(gold) { oracle_cycle(gold); compared++; }
            }
            if(gold) destroyChip(gold);
            require(boot_index==12 && payload_exit==4 && stalls>0 && nmis>500,"Complete original software exercise");
            require((affected && timer==1) ? stars>0 : stars==0,"Original Transactor affected/unaffected detector result");
            if(!reference && timer==1) {
                require(adjacent>0,"Read/underflow race actually exercised");
                require(affected ? loss_reads>0 : loss_reads==0,"Profile-specific read-loss witness");
            }
            std::cout<<"MOS 6526 TRANSACTOR PASS: mode="<<mode<<" affected="<<affected<<" timer="<<(timer?'B':'A')
                     <<" clocks="<<limit<<" stars="<<stars<<" NMIs="<<nmis<<" RDY holds="<<stalls
                     <<" loss reads="<<loss_reads<<" transistor cycles="<<compared<<'\n';
        }
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
