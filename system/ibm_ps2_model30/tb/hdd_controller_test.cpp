#include "Vmodel30_fixed_disk.h"
#include "verilated.h"
#include <array>
#include <vector>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <algorithm>
// Drive-level stimulus. The full-system fixture separately exercises the
// 8086, planar, 8237 and 8259. These tests inject physical media errors.
class Test {
public:
    Vmodel30_fixed_disk chip;
    std::array<std::array<uint8_t,523>,24> media{};
    std::array<bool,24> checks{};
    unsigned assertions=0;
    std::string phase="initial";
    void require(bool value,const char *message){++assertions;if(!value)throw std::runtime_error(phase+": "+message);}
    Test(){
        chip.present=1;chip.dma_dack_n=chip.dma_ior_n=chip.dma_iow_n=1;
        for(unsigned i=0;i<24;++i){media[i][512]=((i/3)%2)<<4;media[i][513]=i/6;media[i][514]=i%3+1;media[i][515]=2;}
        chip.rst_n=chip.cold_rst_n=0;tick();tick();chip.rst_n=chip.cold_rst_n=1;tick();
    }
    void tick(){
        chip.clk=0;chip.eval();
        unsigned sector=chip.media_sector,offset=chip.media_address;
        chip.media_rdata=sector<24 && offset<523 ? media[sector][offset]:255;
        chip.media_check_valid=sector<24 && checks[sector];chip.eval();
        if(chip.media_write){require(sector<24 && offset<523,"media address bounds");media[sector][offset]=chip.media_wdata;if(offset==522)checks[sector]=true;}
        chip.clk=1;chip.eval();
    }
    void clocks(unsigned n){while(n--)tick();}
    void out(unsigned port,uint8_t value){chip.selected=1;chip.writing=1;chip.address=port;chip.wdata=value;tick();chip.selected=chip.writing=0;tick();}
    uint8_t in(unsigned port){chip.selected=chip.reading=1;chip.address=port;chip.clk=0;chip.eval();auto value=chip.rdata;tick();chip.selected=chip.reading=0;tick();return value;}
    void ccb(uint8_t command,unsigned c=0,unsigned h=0,unsigned r=1,unsigned count=1){out(4,0x80);for(auto value:{command,uint8_t(h<<4|c>>8),uint8_t(c),uint8_t(r),uint8_t(2),uint8_t(count)})out(0,value);}
    void ready(){out(4,0x10);}
    void wait_data(bool output){for(unsigned i=0;i<30000;++i){uint8_t status=in(2);if((status&0x19)==(output?0x19:0x11))return;if(!chip.busy){auto result=in(4);auto ssb=sense();throw std::runtime_error(phase+": command failed before data phase ISR="+std::to_string(result)+" SSB1="+std::to_string(ssb[1])+" C="+std::to_string(ssb[3])+" H="+std::to_string(ssb[4])+" R="+std::to_string(ssb[5]));}}throw std::runtime_error("data request timeout");}
    uint8_t done(){for(unsigned i=0;i<50000;++i){if(!chip.busy)return in(4);tick();}throw std::runtime_error("command completion timeout");}
    std::vector<uint8_t> sense(){out(4,0x20);std::vector<uint8_t> result;for(unsigned i=0;i<14;++i)result.push_back(in(0));return result;}
    void write(const std::vector<uint8_t>& data,uint8_t command=0x95){ccb(command);ready();wait_data(false);for(auto value:data)out(0,value);require(done()==0,"write command status");}
    std::vector<uint8_t> read(uint8_t command=0x15,unsigned size=512,uint8_t expected_status=0){ccb(command);ready();wait_data(true);std::vector<uint8_t> result;for(unsigned i=0;i<size;++i)result.push_back(in(0));require(done()==expected_status,"read command status");return result;}
    void specify(uint8_t control){out(4,0x40);out(0,control);for(unsigned i=1;i<14;++i)out(0,0);require(done()==0,"specify status");}
};
int main(int argc,char **argv){
    Verilated::commandArgs(argc,argv);
    try{
        Test t;
        std::ifstream vectors(argv[1]);unsigned pattern,crc;uint64_t ecc;unsigned count=0;
        while(vectors>>std::dec>>pattern>>std::hex>>ecc>>crc){
            t.phase="check vector "+std::to_string(pattern);
            std::vector<uint8_t> data(512);
            for(unsigned i=0;i<512;++i)data[i]=pattern==0?0:pattern==1?255:pattern==2?85:pattern==3?170:pattern==4?uint8_t(i):uint8_t((i*73+19)^(i>>1));
            t.write(data);
            auto raw=t.read(0x35,518);
            t.require(std::equal(data.begin(),data.end(),raw.begin()),"extended read payload");
            uint64_t check=0;for(unsigned i=512;i<518;++i)check=check<<8|raw[i];
            t.require(check==ecc,"external ECC48 vector mismatch");
            t.require(t.read()==data,"normal ECC read");
            t.write(data,0x94);raw=t.read(0x35,518);
            t.require(raw[512]==(crc>>8) && raw[513]==(crc&255) && raw[514]==0 && raw[515]==0 && raw[516]==0 && raw[517]==0,"external CRC16 vector mismatch");
            t.require(t.read(0x14)==data,"CRC read");++count;
        }
        t.require(count==6,"six independent check vectors required");
        std::vector<uint8_t> data(512);for(unsigned i=0;i<512;++i)data[i]=uint8_t(i*73+19);
        // Burst starts include byte boundaries and the final data/check boundary.
        for(unsigned start:{0u,7u,8u,127u,2047u,4088u,4095u,4136u}){
            for(unsigned width:{1u,2u,8u,16u}){
                if(start+width>4144)continue;
                t.phase="burst "+std::to_string(start)+" width "+std::to_string(width);
                t.write(data);
                for(unsigned bit=start;bit<start+width;++bit){unsigned offset=bit/8;offset=offset<512?offset:offset+5;t.media[0][offset]^=uint8_t(0x80>>(bit%8));}
                auto repaired=t.read(0x15,512,2);
                t.require(repaired==data,"correctable burst payload");
                auto status=t.sense();t.require(status[9]==1,"corrected-sector count");
            }
        }
        t.phase="disabled recovery";
        t.write(data);t.specify(0);t.media[0][5]^=1;
        t.ccb(0x15);t.ready();t.require(t.done()==0x82,"recovery disabled must report CRC/ECC failure");
        t.require(t.sense()[10]==0,"recovery disabled retry count");
        t.phase="uncorrectable error";t.specify(0x82);t.write(data);t.media[0][0]^=0x80;t.media[0][20]^=1;t.media[0][100]^=4;
        t.ccb(0x15);t.ready();t.require(t.done()==0x82,"uncorrectable error status");
        t.require(t.sense()[10]==2,"bounded retry count");
        // WRITE EXTENDED must preserve all six externally supplied check bytes.
        t.phase="extended checks";auto extended=data;extended.insert(extended.end(),{1,2,3,4,5,6});t.write(extended,0xb5);
        t.require(t.read(0x35,518)==extended,"extended raw check preservation");
        // Nonstandard interleaved IDs, physical slot fill and defective marker.
        t.phase="custom format";t.ccb(0xf5,1,1,1,3);t.ready();t.wait_data(false);
        for(auto value:{0x10,1,3,2,0xa3,0x10,1,1,2,0xa1,0x14,1,2,2,0xa2,0})t.out(0,value);
        t.require(t.done()==0,"format track status");
        for(unsigned i=0;i<3;++i)t.require(t.media[9+i][514]==(i==0?3:i==1?1:2),"interleaved IDs retained");
        t.ccb(0x15,1,1,1);t.ready();t.wait_data(true);
        for(unsigned i=0;i<512;++i)t.require(t.in(0)==0xa1,"formatted ID lookup/data fill");t.require(t.done()==0,"formatted read status");
        t.ccb(0x15,1,1,2);t.ready();t.require(t.done()==0x80,"defective track rejects transfer");
        t.require((t.sense()[2]&0x10)!=0,"defective track sense flag");
        t.ccb(0x15,4);t.ready();t.require(t.done()==0x80,"out of range cylinder");
        t.ccb(0x15,0,0,1,0);t.ready();t.require(t.done()==0x40,"zero count rejected");
        t.phase="abort/reset";t.write(data);
        t.ccb(0x15);t.ready();t.wait_data(true);t.out(4,1);t.require(!t.chip.busy,"abort releases controller");
        t.out(2,0x82);t.clocks(1000);t.out(2,2);t.require(!t.chip.busy && t.in(4)==0,"reset clears prior error state");
        t.phase="no-data sector buffer";t.write(data);
        t.ccb(0x1d);t.require(t.done()==0,"ND read completion");
        t.ccb(0x9d,0,0,2);t.require(t.done()==0,"ND write completion");
        t.ccb(0x15,0,0,2);t.ready();t.wait_data(true);
        for(auto value:data)t.require(t.in(0)==value,"ND buffer copy payload");t.require(t.done()==0,"ND copy read completion");
        t.phase="DMA control blocks";t.out(2,1);t.out(4,0x90);
        for(auto value:{0x55,0,0,1,2,1}){
            t.require(t.chip.drq,"CCB DMA request");
            t.chip.dma_dack_n=t.chip.dma_iow_n=0;t.chip.dma_wdata=value;t.tick();
            t.chip.dma_dack_n=t.chip.dma_iow_n=1;t.tick();
        }
        t.require(t.done()==0,"DMA CCB completion");t.out(4,0x30);
        for(unsigned i=0;i<14;++i){
            t.require(t.chip.drq,"SSB DMA request");t.chip.dma_dack_n=t.chip.dma_ior_n=0;t.tick();
            if(i==12)t.require(t.chip.dma_rdata==26,"DMA sense type");
            t.chip.dma_dack_n=t.chip.dma_ior_n=1;t.tick();
        }
        t.require(!t.chip.drq,"SSB DMA stream terminates");
        t.phase="short DMA terminal count";t.ccb(0x15);t.ready();t.wait_data(true);
        for(unsigned i=0;i<16;++i){t.chip.dma_dack_n=t.chip.dma_ior_n=0;t.tick();t.chip.dma_dack_n=t.chip.dma_ior_n=1;t.tick();}
        t.chip.terminal_count=1;t.tick();t.chip.terminal_count=0;t.tick();
        t.require(t.done()==0x80 && !t.chip.drq,"short DMA reports error and drops DRQ");t.out(2,0);
        // Exercise every track through the hardware FORMAT DRIVE command.
        t.phase="drive format";t.ccb(0xd5,0,0,1,3);t.ready();t.wait_data(false);
        for(auto value:{0,0,1,2,0xe5,0,0,2,2,0xe5,0,0,3,2,0xe5,0})t.out(0,value);
        t.require(t.done()==0,"format drive completion");
        for(unsigned i=0;i<24;++i){t.require(t.media[i][512]==(((i/3)%2)<<4) && t.media[i][513]==i/6 && t.media[i][514]==i%3+1,"format drive ID geometry");for(unsigned b=0;b<512;++b)t.require(t.media[i][b]==0xe5,"format drive all payloads");}
        std::cout<<"PASS: DBA ECC48/CRC16 independent vectors, burst correction, retries, extended checks, custom/defective IDs, whole-drive format, range/count errors, abort/reset; "<<t.assertions<<" checks\n";
    }catch(const std::exception &e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}
}
