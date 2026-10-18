#include "Vibm_ps2_model30.h"
#include "Vibm_ps2_model30___024root.h"
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

#include "hdd_media.hpp"

// External RAM/ROM chips and magnetic media only. Every CPU instruction,
// BIOS/DOS interrupt, PIC acknowledgement and disk DMA executes in RTL.
class Machine {
public:
    Vibm_ps2_model30 board;
    HardDiskMedia harddisk;
    uint8_t physical_drives=harddisk.present && !std::getenv("IBM_PS2_MODEL30_SECOND_FLOPPY") ? 1:3,disk_inserted=3;
    std::vector<uint8_t> memory=std::vector<uint8_t>(1<<20,255);
    std::array<std::vector<uint8_t>,2> disks;
    std::array<unsigned,4> cylinders{};
    std::deque<uint8_t> keys;
    std::vector<uint8_t> font;
    bool running=false,powered=false,io_trace=false,old_active=false;
    uint64_t trace_after=0;
    unsigned old_step=0,rotation=0,sector=1,byte_offset=0,transfer_sector=0,transfer_cylinder=0;
    unsigned transfer_unit=0,spacing=0,key_spacing=0;
    bool transferring=false;
    uint64_t media_reads=0,media_writes=0;
    uint64_t last_speaker_rise=0;
    unsigned speaker_hz=0;
    bool old_speaker=false;
    uint8_t disk_protection=1;
    uint8_t disk_changes=3;
    std::string directory;
    std::string nvram_path;
    std::unique_ptr<VerilatedFstC> waveform;
    uint64_t waveform_time=0,capture_start=0,capture_cycles=0,capture_version=0;
    static constexpr uint64_t HALF_CLOCK_PS=62500; // nominal 8 MHz
    static std::vector<uint8_t> read_file(const std::string &path){
        std::ifstream file(path,std::ios::binary);
        if(!file)throw std::runtime_error("missing image: "+path);
        return {(std::istreambuf_iterator<char>(file)),{}};
    }
    static unsigned index(unsigned address){return address;}
    uint64_t ticks=0;
    unsigned transfer_head=0;
    bool old_dma_valid=false;
    unsigned last_io_read_port=0xffffffff,last_io_read_data=0xffffffff;
    Machine(const std::string &path):directory(path){
        auto bios=read_file(path+"/bios.bin");
        font.resize(8192);disks[0]=read_file(path+"/boot.img");
        disks[1]=read_file(path+"/workdisk.img");
        if(bios.size()!=65536 || disks[0].size()!=737280 || disks[1].size()!=737280)
            throw std::runtime_error("historical image size");
        std::copy(bios.begin(),bios.end(),memory.begin()+0xf0000);
        std::fill(memory.begin(),memory.begin()+655360,0);
        std::fill(memory.begin()+0xa0000,memory.begin()+0xb0000,0);
        board.cold_rst_n=0;
        board.nv_write=0;board.nv_address=0;board.nv_data=0;
        io_trace=std::getenv("IBM_PS2_MODEL30_IO_TRACE");
        if(const char *after=std::getenv("IBM_PS2_MODEL30_TRACE_AFTER"))trace_after=std::stoull(after);
        reset();board.cold_rst_n=1;board.eval();
        if(const char *nvram=std::getenv("IBM_PS2_MODEL30_NVRAM_PATH")){
            nvram_path=nvram;
            if(std::ifstream(nvram_path,std::ios::binary)){
                auto bytes=read_file(nvram_path);
                if(bytes.size()!=32)throw std::runtime_error("RTC battery image must contain 32 bytes");
                board.rst_n=0;board.nv_write=1;
                for(unsigned i=0;i<32;++i){board.nv_address=i;board.nv_data=bytes[i];tick();}
                board.nv_write=0;board.rst_n=1;board.eval();
            }
        }
    }
    void save_nvram(){
        if(nvram_path.empty())return;
        std::array<uint8_t,32> bytes{};
        for(unsigned i=0;i<32;++i){board.nv_address=i;board.eval();bytes[i]=board.nv_read;}
        const std::string temporary=nvram_path+".next";
        {std::ofstream file(temporary,std::ios::binary);file.write(reinterpret_cast<const char*>(bytes.data()),bytes.size());
            if(!file)throw std::runtime_error("cannot save RTC battery image");}
        if(std::rename(temporary.c_str(),nvram_path.c_str()))throw std::runtime_error("cannot publish RTC battery image");
    }
    ~Machine(){try{save_nvram();harddisk.persist();}catch(const std::exception &e){std::cerr<<"RTC persistence: "<<e.what()<<'\n';}}
    void reset(){
        // Reset does not erase external RAM, move a physical head, or clear
        // the battery-backed RTC. Only a fresh machine initializes storage.
        keys.clear();old_step=0;rotation=0;sector=1;candidate_pending=false;candidate_delay=0;
        byte_offset=0;spacing=0;key_spacing=0;transferring=false;old_active=false;
        media_reads=media_writes=0;post_errors=0;memory_writes.clear();
        last_speaker_rise=0;speaker_hz=0;old_speaker=false;
        board.rst_n=0;board.clk=0;board.dma_clk=0;board.key_valid=0;board.key_code=0;board.mouse_valid=0;board.mouse_code=0;board.font_read=0;
        board.fixed_present=harddisk.present;board.hd_media_rdata=255;board.hd_check_valid=0;
        board.disk_present=physical_drives;board.disk_protected=disk_protection;board.disk_changed=disk_changes;
        board.disk_track0=15;board.media_index=0;board.media_header=0;
        board.media_valid=0;board.media_end=0;board.media_slot=0;board.media_data=0;
        board.media_c=0;board.media_h=board.media_head;board.media_r=1;board.media_n=2;board.mem_rdata=255;
        tick();tick();tick();tick();board.rst_n=1;board.eval();running=false;
    }
    void tick(){
        board.clk=0;board.eval();
        board.key_valid=0;
        if(key_spacing) --key_spacing;
        if(!key_spacing && !keys.empty() && board.key_ready){
            board.key_valid=1;board.key_code=keys.front();keys.pop_front();key_spacing=25000;
        }
        board.mem_rdata=memory[board.mem_addr&0xffffe]|(memory[(board.mem_addr&0xffffe)+1]<<8);
        board.font_read=memory[0xa0000+board.font_source];
        board.hd_media_rdata=harddisk.read(board.hd_media_sector,board.hd_media_address);
        board.hd_check_valid=harddisk.check_valid(board.hd_media_sector);
        board.media_index=0;board.media_header=0;board.media_valid=0;board.media_end=0;board.media_slot=0;
        unsigned step=board.disk_step;
        for(unsigned u=0;u<4;++u){
            if((step&~old_step)&(1<<u)){
                if(u<2)disk_changes&=uint8_t(~(1<<u));
                if(board.disk_direction&(1<<u))cylinders[u]=std::min(79u,cylinders[u]+1);
                else if(cylinders[u])--cylinders[u];
            }
        }
        old_step=step;board.disk_track0=0;board.disk_changed=disk_changes;
        for(unsigned u=0;u<4;++u)if(!cylinders[u])board.disk_track0|=1<<u;
        unsigned u=board.floppy_dor&3;
        bool motor=u<2 && (board.floppy_dor&(0x10<<u));
        bool active=board.media_active && motor && u<2 && !disks[u].empty() && (disk_inserted&(1<<u));
        // ASSUMPTION A2: track IDs and 250-kbit/s decoded bytes, not flux.
        if(active){
            if(++rotation>=1600000){rotation=0;sector=1;board.media_index=1;}
            if(board.floppy_250 && !transferring && rotation%177777==0){
                board.media_header=1;board.media_c=cylinders[u];board.media_h=board.media_head;
                board.media_r=sector;board.media_n=2;
                transfer_sector=sector;transfer_cylinder=cylinders[u];transfer_unit=u;transfer_head=board.media_head;
                sector=sector==9 ? 1:sector+1;
            }
            if(board.floppy_250 && board.sector_begin){
                transferring=true;byte_offset=0;spacing=0;
                transfer_unit=u;transfer_cylinder=cylinders[u];transfer_sector=board.sector_r;transfer_head=board.sector_h;
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
        if(transferring && active && board.floppy_250){
            if(++spacing>=256){
                spacing=0;
                unsigned a=((transfer_cylinder*2+transfer_head)*9+transfer_sector-1)*512+byte_offset;
                if(byte_offset<512){
                    if(board.media_writing)board.media_slot=1;
                    else {board.media_valid=1;board.media_data=a<disks[transfer_unit].size() ? disks[transfer_unit][a]:255;++media_reads;}
                    ++byte_offset;
                }else{board.media_end=1;transferring=false;}
            }
        }
        if(!active || !board.floppy_250){transferring=false;candidate_pending=false;}
        old_active=active;
        board.eval();
        if(waveform){waveform->dump(waveform_time);waveform_time+=HALF_CLOCK_PS;}
        if(io_trace && board.cycle_count>=trace_after && board.rootp->ibm_ps2_model30__DOT__dma_valid && board.rootp->ibm_ps2_model30__DOT__dma_channel==2){
            std::cerr<<board.cycle_count<<" DMA "<<std::hex<<board.mem_addr<<" "
                <<unsigned(board.rootp->ibm_ps2_model30__DOT__dma_iow_n ? board.mem_wdata:board.mem_rdata)
                <<" count="<<board.rootp->ibm_ps2_model30__DOT__dma__DOT__count_q[2]
                <<" phase="<<unsigned(board.rootp->ibm_ps2_model30__DOT__fdc__DOT__phase)<<std::dec<<'\n';
        }
        const bool diagnostic_read=board.bus_addr>=0x3f0 && board.bus_addr<=0x3f7 ||
            board.bus_addr>=0x60 && board.bus_addr<=0x6b || board.bus_addr==0xa0 || (board.bus_addr>=0x320 && board.bus_addr<=0x324);
        const bool read_changed=last_io_read_port!=board.bus_addr || last_io_read_data!=board.bus_read_data;
        if(io_trace && board.cycle_count>=trace_after && board.bus_strobe && (board.bus_intack || board.bus_io &&
            (board.bus_write || diagnostic_read && (read_changed || board.bus_addr==0x3f5)))){
            std::cerr<<board.cycle_count<<" "<<(board.bus_intack ? 'A':board.bus_write ? 'W':'R')
                <<" "<<std::hex<<board.bus_addr<<" "<<unsigned(board.bus_write ? board.bus_data:board.bus_read_data)
                <<" CS:IP="<<uint16_t(board.segs>>16)<<":"<<board.ip<<std::dec<<'\n';
        }
        if(board.bus_strobe && board.bus_io && !board.bus_write){last_io_read_port=board.bus_addr;last_io_read_data=board.bus_read_data;}
        if(board.mem_write){
            unsigned a=board.mem_addr&0xffffe;
            for(unsigned lane=0;lane<2;++lane)if(board.mem_write&(1<<lane)){
                memory[a+lane]=uint8_t(board.mem_wdata>>(8*lane));
                if(capture_writes)memory_writes.emplace_back(a+lane,memory[a+lane]);
            }
        }
        if(board.hd_media_read)++harddisk.reads;
        if(board.hd_media_write)harddisk.write(board.hd_media_sector,board.hd_media_address,board.hd_media_wdata);
        if(board.font_write)font[board.font_address]=board.font_data;
        if(board.media_tx_valid && transfer_unit<2 && byte_offset){
            unsigned a=((transfer_cylinder*2+transfer_head)*9+transfer_sector-1)*512+byte_offset-1;
            if(transfer_cylinder<80 && transfer_head<2 && transfer_sector>=1 && transfer_sector<=9 &&
                a<disks[transfer_unit].size() && !(board.disk_protected&(1<<transfer_unit))){
                disks[transfer_unit][a]=board.media_tx_data;++media_writes;
            }
        }
        board.clk=1;board.dma_clk=(ticks++&1)==0;board.eval();
        if(waveform){waveform->dump(waveform_time);waveform_time+=HALF_CLOCK_PS;}
        if(board.speaker && !old_speaker){
            auto period=board.cycle_count-last_speaker_rise;
            if(last_speaker_rise && period)speaker_hz=unsigned(8000000/period);
            last_speaker_rise=board.cycle_count;
        }
        old_speaker=board.speaker;
        if(board.retired && uint16_t(board.segs>>16)==0xf000 && board.ip==0x10a3){
            unsigned si=uint16_t(board.regs[3]);
            std::cerr<<"BIOS DIAGNOSTIC: ";
            for(unsigned i=0;i<100;++i){auto c=memory[0xf0000+((si+i)&65535)];std::cerr<<char(c);if(c==10)break;}
            std::cerr<<'\n';++post_errors;
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
        const char *configured=std::getenv("IBM_PS2_MODEL30_FST_PATH");
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
        save_nvram();harddisk.persist();
    }
    std::string text(){
        std::string out;unsigned columns=board.cga_mode&1 ? 80:40;
        board.crtc_debug_index=12;board.eval();unsigned start=board.crtc_debug_data<<8;
        board.crtc_debug_index=13;board.eval();start|=board.crtc_debug_data;
        for(unsigned row=0;row<25;++row){
            for(unsigned col=0;col<columns;++col){auto c=memory[0xa8000+((2*(start+row*columns+col))&0x7fff)];out+=c>=32 && c<127 ? char(c):' ';}
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
            <<",\"hardDiskPresent\":"<<(harddisk.present ? "true":"false")
            <<",\"hardDiskBusy\":"<<(board.hd_busy ? "true":"false")
            <<",\"hardDiskReads\":"<<harddisk.reads<<",\"hardDiskWrites\":"<<harddisk.writes
            <<",\"floppyDrives\":"<<unsigned(physical_drives)<<",\"diskInserted\":"<<unsigned(disk_inserted)
            <<",\"speakerHz\":"<<(board.speaker_enabled ? speaker_hz:0)
            <<",\"mode\":"<<unsigned(board.cga_mode)<<",\"palette\":"<<unsigned(board.cga_palette)
            <<",\"dor\":"<<unsigned(board.floppy_dor)<<",\"keysQueued\":"<<keys.size()<<",\"queue\":"<<unsigned(board.queue_count)
            <<",\"registers\":[";
        for(unsigned i=0;i<8;++i){if(i)s<<',';s<<((board.regs[i/2]>>(16*(i%2)))&65535);}
        s<<"],\"segments\":[";
        for(unsigned i=0;i<4;++i){if(i)s<<',';s<<((board.segs>>(16*i))&65535);}
        s<<"],\"crtc\":[";
        for(unsigned i=0;i<21;++i){if(i)s<<',';board.crtc_debug_index=i;board.eval();s<<unsigned(board.crtc_debug_data);}
        uint64_t ram_hash=14695981039346656037ull;
        for(unsigned i=0;i<655360;++i){ram_hash^=memory[i];ram_hash*=1099511628211ull;}
        s<<"],\"ramHash\":\""<<std::hex<<ram_hash<<std::dec<<"\",\"rtc\":[";
        for(unsigned i=0;i<32;++i){if(i)s<<',';s<<unsigned(board.rootp->ibm_ps2_model30__DOT__rtc__DOT__registers[i]);}
        s<<"],\"captureStart\":"<<capture_start<<",\"captureCycles\":"<<capture_cycles
            <<",\"captureVersion\":"<<capture_version<<",\"vram\":\"";
        const char hex[]="0123456789abcdef";
        for(unsigned i=0;i<65536;++i){auto v=memory[0xa0000+i];s<<hex[v>>4]<<hex[v&15];}
        s<<"\",\"bda\":\"";
        for(unsigned i=0x400;i<0x500;++i){auto v=memory[i];s<<hex[v>>4]<<hex[v&15];}
        s<<"\",\"graphicsMode\":"<<unsigned(board.graphics_mode)<<",\"scanSet\":"<<unsigned(board.scan_set)<<",\"font\":\"";
        for(auto v:font)s<<hex[v>>4]<<hex[v&15];
        s<<"\",\"dac\":[";
        for(unsigned i=0;i<768;++i){if(i)s<<',';board.dac_debug_index=i;board.eval();s<<unsigned(board.dac_debug_data);}
        s<<"]}";return s.str();
    }
};
#include "board_tests.hpp"
#include "hdd_tests.hpp"

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
        if(argc>=4 && std::string(argv[2])=="--harddisk-tests"){harddisk_tests(m,argv[3]);return 0;}
        if(argc>=3 && std::string(argv[2])=="--boot"){
            uint64_t cycles=argc>=4 ? std::stoull(argv[3]):100000000;
            for(uint64_t i=0;i<cycles;i+=1000000){m.run(std::min<uint64_t>(1000000,cycles-i));
                std::cerr<<m.board.cycle_count<<" cycles "<<m.location()<<" CX="<<(m.board.regs[0]>>16)
                    <<" ES="<<uint16_t(m.board.segs)<<" SI="<<uint16_t(m.board.regs[3])
                    <<" DMA="<<m.board.dma_count<<" reads="<<m.media_reads<<"\n";}
            std::cout<<m.text();std::cerr<<m.state().substr(0,400)<<"\n";return 0;
        }
        if(argc>=4 && std::string(argv[2])=="--fixture"){
            auto code=Machine::read_file(argv[3]);
            if(code.empty() || code.size()>0x4000)throw std::runtime_error("invalid external ROM fixture");
            const uint8_t vector[]={0xea,0,5,0,0};
            std::copy(std::begin(vector),std::end(vector),m.memory.begin()+0xffff0);
            std::copy(code.begin(),code.end(),m.memory.begin()+0x500);
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
            else if((command=="MOUNT" || command=="SAVE") && value<3){
                std::string path;in>>path;
                if(path.empty())throw std::runtime_error("missing private disk path");
                if(value==2){
                    if(command=="MOUNT"){
                        try{m.harddisk.mount(path);}catch(const std::exception &e){
                            std::cout<<"{\"error\":\""<<e.what()<<"\"}"<<std::endl;continue;
                        }
                    }
                    else m.harddisk.save(path,path.size()>=4 && path.substr(path.size()-4)==".m30");
                }else if(command=="MOUNT"){
                    auto image=Machine::read_file(path);
                    if(image.size()!=737280)throw std::runtime_error("disk image must be 720K (737280 bytes)");
                    m.disk_inserted|=uint8_t(1<<value);
                    m.disks[value]=std::move(image);m.disk_protection&=uint8_t(~(1<<value));
                    m.disk_changes|=uint8_t(1<<value);m.board.disk_changed=m.disk_changes;
                    m.board.disk_protected=m.disk_protection;
                    m.transferring=false;m.candidate_pending=false;
                }else{
                    std::ofstream file(path,std::ios::binary);
                    file.write(reinterpret_cast<const char*>(m.disks[value].data()),m.disks[value].size());
                    if(!file)throw std::runtime_error("disk export failed");
                }
            }
            else if(command=="EJECT" && value<2){
                m.disk_inserted&=uint8_t(~(1<<value));m.disk_changes|=uint8_t(1<<value);
                m.board.disk_changed=m.disk_changes;m.transferring=false;m.candidate_pending=false;
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
            if(command=="OFF" || command=="PAUSE" || command=="RESET"){m.save_nvram();m.harddisk.persist();}
            std::cout<<m.state()<<std::endl;
        }
    }catch(const std::exception &e){std::cerr<<"ERROR: "<<e.what()<<'\n';return 1;}
}
