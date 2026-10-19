#include "Vmos_6502_cycle.h"
#include "verilated.h"
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <string>
#include <vector>

// Firmware-level bus harness, not the physical motherboard. All executed
// instructions come from the unchanged external Apple II ROM and authored RTL.
// Tape input follows the published format independently of recorded output.
static Vmos_6502_cycle cpu;
static std::array<uint8_t,65536> memory;
static std::deque<uint8_t> keyboard;
static uint64_t cycles;
static double time_us;
static bool read_test, started, tape_level;
static unsigned speaker_edges, test;
static std::string output;
struct Edge { uint64_t cycle; double us; };
static std::vector<Edge> edges;
static std::vector<double> input_edges;
static size_t input_index;
static const std::array<uint8_t,6> payload={0x00,0xff,0x55,0xaa,0xa5,0x5a};
static void require(bool ok,const char* message) {
    if(!ok) { std::fprintf(stderr,"FAIL cassette command case %u PC=%04x cycles=%llu: %s\n",
        test,cpu.pc_o,(unsigned long long)cycles,message); std::exit(1); }
}
static void tick() {
    cpu.clk=0;cpu.eval();
    while(input_index<input_edges.size() && time_us>=input_edges[input_index]) {
        tape_level=!tape_level; ++input_index;
    }
    unsigned address=cpu.bus_addr;
    uint8_t value=memory[address];
    if(address>=0xc000 && address<0xc010)
        value=keyboard.empty()?0:uint8_t(keyboard.front()|0x80);
    if(address>=0xc060 && address<0xc070) value=tape_level?0x80:0;
    cpu.bus_data_i=value;cpu.eval();
    if(cpu.rst_n) {
        if(cpu.fetch_o) {
            require(!cpu.fault_o,"unsupported opcode");
            if(cpu.pc_o==(read_test?0xfefd:0xfecd)) started=true;
            if(cpu.pc_o==0xfded) output+=char(cpu.a_o&0x7f);
        }
        if(cpu.bus_we && address<0xc000) memory[address]=cpu.bus_data_o;
        if(address>=0xc010 && address<0xc020 && !keyboard.empty()) keyboard.pop_front();
        if(address>=0xc020 && address<0xc030 && started) edges.push_back({cycles,time_us});
        if(address>=0xc030 && address<0xc040) ++speaker_edges;
    }
    cpu.clk=1;cpu.eval(); ++cycles;
    // Nominal revision-0 CPU timing: 14 master periods, extended once per 65.
    time_us+=(14+(cycles%65==0?2:0))*0.069842;
}
static void reset() {
    FILE* f=std::fopen("work/Apple2.rom","rb");require(f,"ROM missing");
    memory.fill(0);require(std::fread(memory.data()+0xd000,1,12288,f)==12288,"ROM size");std::fclose(f);
    keyboard.clear();edges.clear();input_edges.clear();output.clear();
    cycles=0;time_us=0;input_index=0;speaker_edges=0;started=false;
    cpu.res_n=cpu.irq_n=cpu.nmi_n=cpu.rdy=cpu.so_n=1;
    cpu.rst_n=0;tick();cpu.rst_n=1;
    for(unsigned i=0;i<2000000;i++) {
        if(cpu.bus_addr==0xc000 && cycles>1000) {speaker_edges=0;output.clear();return;}
        tick();
    }
    require(false,"Monitor boot timeout");
}
static void command(const std::string& text) { for(unsigned char c:text) keyboard.push_back(c); }
static void finish_command() {
    for(unsigned i=0;i<30000000;i++) {
        if(started && keyboard.empty() && cpu.bus_addr==0xc000) return;
        tick();require(!cpu.fault_o,"firmware fault");
    }
    require(false,"complete Monitor cassette command timeout");
}
static uint8_t checksum() { uint8_t v=0xff;for(auto b:payload)v^=b;return v; }
static void tape(double speed,bool bad) {
    double t=time_us;
    for(unsigned i=0;i<12000;i++) {t+=650*speed;input_edges.push_back(t);}
    t+=200*speed;input_edges.push_back(t);
    t+=250*speed;input_edges.push_back(t);
    std::vector<uint8_t> bytes(payload.begin(),payload.end());bytes.push_back(checksum()^(bad?1:0));
    for(auto b:bytes) for(int bit=7;bit>=0;bit--) for(int half=0;half<2;half++) {
        t+=((b>>bit)&1?500:250)*speed; input_edges.push_back(t);
    }
}
static void write_command() {
    read_test=false;reset();
    for(unsigned i=0;i<payload.size();i++) memory[0x2fd+i]=payload[i];
    command("2FD.302W\r");finish_command();
    // The Monitor parser enters HEADR with X=1. The first block is one
    // half-cycle, then 64 blocks of 256: 16385 long edges, 2 sync, 112 data.
    require(edges.size()==16499,"exact full WRITE edge count");
    require(speaker_edges>0,"completion bell");
    std::printf("WRITE edges=%zu elapsed=%.6f seconds\n",edges.size(),time_us/1e6);
    const size_t data_start=edges.size()-112;
    require(edges[data_start].us>10e6,"leader duration");
    for(size_t i=1;i<data_start-2;i++)
        require(edges[i].cycle-edges[i-1].cycle==((i-1)%256==0?656:652),
                "exact original HEADR loop cycles");
    require(edges[data_start-2].cycle-edges[data_start-3].cycle==195,"first sync half");
    require(edges[data_start-1].cycle-edges[data_start-2].cycle==250,"second sync half");
    // HEADR return, FED2-FEDB setup, WRBYTE and Y=$27 zero delay:
    // 252 cycles from the final sync transition to the first data transition.
    require(edges[data_start].cycle-edges[data_start-1].cycle==252,
            "exact sync-to-first-data instruction cycles");
    std::vector<uint8_t> expected(payload.begin(),payload.end());expected.push_back(checksum());
    for(unsigned i=0;i<56;i++) {
        double half=edges[data_start+i*2+1].us-edges[data_start+i*2].us;
        require((half>375)==bool((expected[i/8]>>(7-i%8))&1),"full WRITE bytes/checksum");
    }
    for(unsigned i=1;i<112;i++) {
        unsigned count=i%2?250:253;
        // NXTA1 FCC4 falls through on low-byte wrap: one fewer branch
        // cycle plus five cycles for INC A1H, hence four extra cycles.
        if(i%16==0) count=i==96?258:249+(i==48?4:0);
        count+=250*((expected[i/16]>>(7-(i%16)/2))&1);
        require(edges[data_start+i].cycle-edges[data_start+i-1].cycle==count,
                "exact WRITE data cycles including pointer carry");
    }
    require(output.find("ERR")==std::string::npos,"WRITE unexpected error");
    std::puts("PASS full original Monitor WRITE, leader, sync, page crossing, bytes/checksum and bell");
}
static void read_command(bool polarity,double speed,bool bad) {
    read_test=true;reset();tape_level=polarity;
    for(unsigned i=0;i<payload.size();i++) memory[0x2fd+i]=0x3c;
    command("2FD.302R\r");tape(speed,bad);finish_command();
    for(unsigned i=0;i<payload.size();i++) require(memory[0x2fd+i]==payload[i],"full READ inclusive page-crossing range");
    require((output.find("ERR")!=std::string::npos)==bad,"checksum error reporting");
    require(speaker_edges>0,"READ bell");
    require(input_index>12000,"READ leader and sync acquisition");
    std::printf("PASS full original READ polarity=%u speed=%.2f checksum=%s elapsed=%.6fs\n",
        polarity,speed,bad?"bad/ERR":"good",time_us/1e6);
}
int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);write_command();
    for(bool polarity:{false,true}) for(double speed:{0.92,1.0,1.08}) {
        ++test;read_command(polarity,speed,false);
    }
    ++test;read_command(false,1.0,true);
    ++test;read_command(true,1.0,true);
    std::puts("PASS complete historical cassette command firmware layer (9 cases)");
}
