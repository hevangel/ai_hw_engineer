#include "Vibm_pc.h"
#include "Vibm_pc___024root.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <array>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <deque>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

// External RAM/ROM chips and diskette media only. Every CPU instruction,
// BIOS/DOS interrupt, PIC acknowledgement and disk DMA executes in RTL.
class Machine {
public:
    Vibm_pc board;
    std::vector<uint8_t> memory=std::vector<uint8_t>(1<<20,255);
    std::array<std::vector<uint8_t>,2> disks;
    std::array<unsigned,4> cylinders{};
    std::deque<uint8_t> keys;
    std::vector<uint8_t> font;
    bool running=false,powered=false,io_trace=false,old_active=false;
    unsigned old_step=0,rotation=0,sector=1,byte_offset=0,transfer_sector=0,transfer_cylinder=0;
    unsigned transfer_unit=0,spacing=0,key_spacing=0;
    bool transferring=false;
    uint64_t media_reads=0,media_writes=0;
    uint64_t last_speaker_rise=0;
    unsigned speaker_hz=0;
    bool old_speaker=false;
    uint8_t disk_protection=1;
    std::string directory;
    std::unique_ptr<VerilatedFstC> waveform;
    uint64_t waveform_time=0,capture_start=0,capture_cycles=0,capture_version=0;
    static constexpr uint64_t HALF_CLOCK_PS=104762; // nominal 4.772727 MHz
    static std::vector<uint8_t> read_file(const std::string &path){
        std::ifstream file(path,std::ios::binary);
        if(!file)throw std::runtime_error("missing image: "+path);
        return {(std::istreambuf_iterator<char>(file)),{}};
    }
    static unsigned index(unsigned address){
        return (address&0xf8000)==0xb8000 ? 0xb8000+(address&0x3fff):address;
    }
    Machine(const std::string &path):directory(path){
        auto bios=read_file(path+"/bios.bin"),basic=read_file(path+"/basic.bin");
        font=read_file(path+"/cga.bin");disks[0]=read_file(path+"/pcdos100.img");
        disks[1]=read_file(path+"/workdisk.img");
        if(bios.size()!=8192 || basic.size()!=32768 || disks[0].size()!=163840)
            throw std::runtime_error("historical image size");
        std::copy(bios.begin(),bios.end(),memory.begin()+0xfe000);
        std::copy(basic.begin(),basic.end(),memory.begin()+0xf6000);
        io_trace=std::getenv("IBM_PC_IO_TRACE");
        reset();
    }
    void reset(){
        std::fill(memory.begin(),memory.begin()+65536,0);
        std::fill(memory.begin()+0xb8000,memory.begin()+0xbc000,0);
        keys.clear();cylinders.fill(0);old_step=0;rotation=0;sector=1;candidate_pending=false;candidate_delay=0;
        byte_offset=0;spacing=0;key_spacing=0;transferring=false;old_active=false;
        media_reads=media_writes=0;post_errors=0;memory_writes.clear();
        last_speaker_rise=0;speaker_hz=0;old_speaker=false;
        board.rst_n=0;board.clk=0;board.key_valid=0;board.key_code=0;
        board.disk_present=3;board.disk_protected=disk_protection;
        board.disk_track0=15;board.media_index=0;board.media_header=0;
        board.media_valid=0;board.media_end=0;board.media_slot=0;board.media_data=0;
        board.media_c=0;board.media_h=0;board.media_r=1;board.media_n=2;board.mem_rdata=255;
        tick();tick();tick();tick();board.rst_n=1;board.eval();running=false;
    }
    void tick(){
        board.clk=0;board.eval();
        board.key_valid=0;
        if(key_spacing) --key_spacing;
        if(!key_spacing && !keys.empty() && board.key_ready){
            board.key_valid=1;board.key_code=keys.front();keys.pop_front();key_spacing=25000;
        }
        board.mem_rdata=memory[index(board.mem_addr)];
        board.media_index=0;board.media_header=0;board.media_valid=0;board.media_end=0;board.media_slot=0;
        unsigned step=board.disk_step;
        for(unsigned u=0;u<4;++u){
            if((step&~old_step)&(1<<u)){
                if(board.disk_direction&(1<<u))cylinders[u]=std::min(79u,cylinders[u]+1);
                else if(cylinders[u])--cylinders[u];
            }
        }
        old_step=step;board.disk_track0=0;
        for(unsigned u=0;u<4;++u)if(!cylinders[u])board.disk_track0|=1<<u;
        unsigned u=board.floppy_dor&3;
        bool motor=u<2 && (board.floppy_dor&(0x10<<u));
        bool active=board.media_active && motor && u<2 && !disks[u].empty();
        // ASSUMPTION A2: track IDs and 250-kbit/s decoded bytes, not flux.
        if(active){
            if(++rotation>=954544){rotation=0;sector=1;board.media_index=1;}
            if(!transferring && rotation%119318==0){
                board.media_header=1;board.media_c=cylinders[u];board.media_h=0;
                board.media_r=sector;board.media_n=2;
                transfer_sector=sector;transfer_cylinder=cylinders[u];transfer_unit=u;
                sector=sector==8 ? 1:sector+1;
            }
            if(board.sector_begin){
                transferring=true;byte_offset=0;spacing=0;
                transfer_unit=u;transfer_cylinder=cylinders[u];transfer_sector=board.sector_r;
            }
            // Read-sector entry follows an accepted header. This observes an
            // external header and waits for data timing, never CPU registers.
            if(board.media_header && !board.media_writing){
                candidate_pending=true;candidate_delay=2;
            }
        }
        if(candidate_pending && candidate_delay && --candidate_delay==0){
            // The media sends data after every physical header. The FDC
            // independently accepts or ignores IDs and associated bytes.
            transferring=true;byte_offset=0;spacing=0;candidate_pending=false;
        }
        if(transferring && active){
            if(++spacing>=153){
                spacing=0;
                unsigned a=(transfer_cylinder*8+transfer_sector-1)*512+byte_offset;
                if(byte_offset<512){
                    if(board.media_writing)board.media_slot=1;
                    else {board.media_valid=1;board.media_data=a<disks[transfer_unit].size() ? disks[transfer_unit][a]:255;++media_reads;}
                    ++byte_offset;
                }else{board.media_end=1;transferring=false;}
            }
        }
        if(!active)transferring=false;
        old_active=active;
        board.eval();
        if(waveform){waveform->dump(waveform_time);waveform_time+=HALF_CLOCK_PS;}
        if(io_trace && board.rootp->ibm_pc__DOT__dma_valid && board.rootp->ibm_pc__DOT__dma_channel==2){
            std::cerr<<board.cycle_count<<" DMA "<<std::hex<<board.mem_addr<<" "
                <<unsigned(board.rootp->ibm_pc__DOT__dma_iow_n ? board.mem_wdata:board.mem_rdata)
                <<" count="<<board.rootp->ibm_pc__DOT__dma__DOT__count_q[2]
                <<" phase="<<unsigned(board.rootp->ibm_pc__DOT__fdc__DOT__phase)<<std::dec<<'\n';
        }
        if(io_trace && board.bus_strobe && (board.bus_intack || board.bus_io &&
            (board.bus_write || board.bus_addr==0x3f5))){
            std::cerr<<board.cycle_count<<" "<<(board.bus_intack ? 'A':board.bus_write ? 'W':'R')
                <<" "<<std::hex<<board.bus_addr<<" "<<unsigned(board.bus_write ? board.bus_data:board.bus_read_data)
                <<" CS:IP="<<uint16_t(board.segs>>16)<<":"<<board.ip<<std::dec<<'\n';
        }
        if(board.mem_write){
            memory[index(board.mem_addr)]=board.mem_wdata;
            if(capture_writes)memory_writes.emplace_back(board.mem_addr,board.mem_wdata);
        }
        if(board.media_tx_valid && transfer_unit<2 && byte_offset){
            unsigned a=(transfer_cylinder*8+transfer_sector-1)*512+byte_offset-1;
            if(a<disks[transfer_unit].size() && !(board.disk_protected&(1<<transfer_unit))){
                disks[transfer_unit][a]=board.media_tx_data;++media_writes;
            }
        }
        board.clk=1;board.eval();
        if(waveform){waveform->dump(waveform_time);waveform_time+=HALF_CLOCK_PS;}
        if(board.speaker && !old_speaker){
            auto period=board.cycle_count-last_speaker_rise;
            if(last_speaker_rise && period)speaker_hz=unsigned(4772727/period);
            last_speaker_rise=board.cycle_count;
        }
        old_speaker=board.speaker;
        if(board.retired && uint16_t(board.segs>>16)==0xf000 && board.ip==0xe6ca){
            unsigned si=uint16_t(board.regs[3]),cx=board.regs[0]>>16;
            std::cerr<<"BIOS DIAGNOSTIC: ";
            for(unsigned i=0;i<std::min(36u,cx);++i)std::cerr<<char(memory[(0xf0000+si+i)&0xfffff]);
            std::cerr<<"\n";++post_errors;
        }
        if(board.fault)throw std::runtime_error("CPU fault at "+location());
    }
    bool candidate_pending=false;
    unsigned candidate_delay=0;
    unsigned post_errors=0;
    bool capture_writes=false;
    std::vector<std::pair<unsigned,uint8_t>> memory_writes;
    std::string location(){std::ostringstream s;s<<std::hex<<uint16_t(board.segs>>16)<<":"<<board.ip;return s.str();}
    void run(uint64_t cycles){for(uint64_t i=0;i<cycles;++i)tick();}
    void capture(unsigned cycles){
        if(!powered || cycles<1 || cycles>65536)throw std::runtime_error("invalid waveform capture");
        running=false;
        const char *configured=std::getenv("IBM_PC_FST_PATH");
        const std::string path=configured ? configured:directory+"/../cpu-waveform.fst";
        const std::string temporary=path+".next";
        waveform=std::make_unique<VerilatedFstC>();
        board.trace(waveform.get(),2);
        waveform->set_time_unit("1ps");waveform->set_time_resolution("1ps");
        waveform->open(temporary.c_str());
        if(!waveform->isOpen())throw std::runtime_error("cannot open waveform capture");
        waveform_time=0;
        auto start=uint64_t(board.cycle_count);
        run(cycles);
        board.clk=0;board.eval();waveform->dump(waveform_time);
        waveform->close();waveform.reset();
        if(std::rename(temporary.c_str(),path.c_str()))throw std::runtime_error("cannot publish waveform capture");
        capture_start=start;capture_cycles=cycles;++capture_version;
    }
    std::string text(){
        std::string out;unsigned columns=board.cga_mode&1 ? 80:40;
        board.crtc_debug_index=12;board.eval();unsigned start=board.crtc_debug_data<<8;
        board.crtc_debug_index=13;board.eval();start|=board.crtc_debug_data;
        for(unsigned row=0;row<25;++row){
            for(unsigned col=0;col<columns;++col){auto c=memory[0xb8000+((2*(start+row*columns+col))&0x3fff)];out+=c>=32 && c<127 ? char(c):' ';}
            out+='\n';
        }
        return out;
    }
    std::string state(){
        std::ostringstream s;s<<"{\"cycles\":"<<board.cycle_count<<",\"instructions\":"<<board.instruction_count
            <<",\"cs\":"<<uint16_t(board.segs>>16)<<",\"ip\":"<<board.ip<<",\"flags\":"<<board.flags
            <<",\"running\":"<<(running ? "true":"false")<<",\"powered\":"<<(powered ? "true":"false")
            <<",\"halted\":"<<(board.halted ? "true":"false")
            <<",\"fault\":"<<(board.fault ? "true":"false")<<",\"dma\":"<<board.dma_count
            <<",\"refresh\":"<<board.refresh_count<<",\"irqAcks\":"<<board.irq_count
            <<",\"mediaReads\":"<<media_reads<<",\"mediaWrites\":"<<media_writes<<",\"postErrors\":"<<post_errors
            <<",\"speakerHz\":"<<(board.speaker_enabled ? speaker_hz:0)
            <<",\"mode\":"<<unsigned(board.cga_mode)<<",\"palette\":"<<unsigned(board.cga_palette)
            <<",\"dor\":"<<unsigned(board.floppy_dor)<<",\"keysQueued\":"<<keys.size()<<",\"queue\":"<<unsigned(board.queue_count)
            <<",\"registers\":[";
        for(unsigned i=0;i<8;++i){if(i)s<<',';s<<((board.regs[i/2]>>(16*(i%2)))&65535);}
        s<<"],\"segments\":[";
        for(unsigned i=0;i<4;++i){if(i)s<<',';s<<((board.segs>>(16*i))&65535);}
        s<<"],\"crtc\":[";
        for(unsigned i=0;i<18;++i){if(i)s<<',';board.crtc_debug_index=i;board.eval();s<<unsigned(board.crtc_debug_data);}
        s<<"],\"captureStart\":"<<capture_start<<",\"captureCycles\":"<<capture_cycles
            <<",\"captureVersion\":"<<capture_version<<",\"vram\":\"";
        const char hex[]="0123456789abcdef";
        for(unsigned i=0;i<16384;++i){auto v=memory[0xb8000+i];s<<hex[v>>4]<<hex[v&15];}
        s<<"\"}";return s.str();
    }
};
#include "board_tests.hpp"

int main(int argc,char **argv){
    Verilated::commandArgs(argc,argv);
    Verilated::traceEverOn(true);
    try{
        if(argc<2)throw std::runtime_error("usage: simulator IMAGE_DIRECTORY [--boot CYCLES]");
        Machine m(argv[1]);
        if(argc>=4 && std::string(argv[2])=="--board-tests"){
            board_tests(m,argv[3]);return 0;
        }
        if(argc>=4 && std::string(argv[2])=="--disk-tests"){
            disk_tests(m,argv[3]);return 0;
        }
        if(argc>=3 && std::string(argv[2])=="--boot"){
            uint64_t cycles=argc>=4 ? std::stoull(argv[3]):100000000;
            for(uint64_t i=0;i<cycles;i+=1000000){m.run(std::min<uint64_t>(1000000,cycles-i));
                std::cerr<<m.board.cycle_count<<" cycles "<<m.location()<<" CX="<<(m.board.regs[0]>>16)
                    <<" ES="<<uint16_t(m.board.segs)<<" SI="<<uint16_t(m.board.regs[3])
                    <<" DMA="<<m.board.dma_count<<" reads="<<m.media_reads<<"\n";}
            std::cout<<m.text();std::cerr<<m.state().substr(0,400)<<"\n";return 0;
        }
        std::string line;
        while(std::getline(std::cin,line)){
            std::istringstream in(line);std::string command;uint64_t value=0;in>>command>>value;
            if(command=="QUIT")break;
            if(command=="RESET"){m.reset();m.powered=true;}
            else if(command=="AUTO"){m.running=true;m.powered=true;}
            else if(command=="OFF"){m.running=false;m.powered=false;}
            else if(command=="PAUSE")m.running=false;
            else if(command=="RUN")m.run(std::min<uint64_t>(value,5000000));
            else if(command=="CAPTURE")m.capture(unsigned(value));
            else if(command=="KEY" && value<=255)m.keys.push_back(value);
            else if((command=="MOUNT" || command=="SAVE") && value<2){
                std::string path;in>>path;
                if(path.empty())throw std::runtime_error("missing private disk path");
                if(command=="MOUNT"){
                    auto image=Machine::read_file(path);
                    if(image.size()!=163840)throw std::runtime_error("disk image must be PC160K (163840 bytes)");
                    m.disks[value]=std::move(image);m.disk_protection&=uint8_t(~(1<<value));
                    m.board.disk_protected=m.disk_protection;
                    m.transferring=false;m.candidate_pending=false;
                }else{
                    std::ofstream file(path,std::ios::binary);
                    file.write(reinterpret_cast<const char*>(m.disks[value].data()),m.disks[value].size());
                    if(!file)throw std::runtime_error("disk export failed");
                }
            }
            else if(command=="STEP"){
                m.running=false;m.powered=true;
                if(m.board.halted)m.tick();
                else{
                    bool done=false;
                    for(unsigned i=0;i<5000000;++i){m.tick();if(m.board.retired){done=true;break;}}
                    if(!done)throw std::runtime_error("instruction-step watchdog");
                }
            }else if(command=="TEXT"){std::cout<<m.text()<<"END_TEXT\n";continue;}
            else if(command!="STATE")throw std::runtime_error("invalid simulator command");
            std::cout<<m.state()<<std::endl;
        }
    }catch(const std::exception &e){std::cerr<<"ERROR: "<<e.what()<<'\n';return 1;}
}
