#include "Vxt_fixed_disk.h"
#include "verilated.h"
#include <array>
#include <iostream>
#include <stdexcept>
static void check(bool ok,const char *s){if(!ok)throw std::runtime_error(s);}
struct Bench{
 Vxt_fixed_disk d;
 Bench(){d.rst_n=0;tick();d.rst_n=1;tick();}
 void tick(){d.clk=0;d.eval();d.clk=1;d.eval();}
 void write(unsigned port,unsigned data){d.selected=1;d.io_write=1;d.port=port;d.data_i=data;tick();d.selected=0;d.io_write=0;tick();}
 unsigned read(unsigned port){d.selected=1;d.io_read=1;d.port=port;d.clk=0;d.eval();unsigned v=d.data_o;d.clk=1;d.eval();d.selected=0;d.io_read=0;tick();return v;}
 void command(const std::array<unsigned,6> &cmd){write(2,0);write(3,3);for(auto v:cmd)write(0,v);check(!(read(1)&1),"six-byte command REQ low");tick();}
 unsigned result(){check(!(read(1)&1),"result must expose initial REQ-low phase");check((read(1)&3)==3,"result ready/IOMODE");return read(0);}
};
int main(int argc,char **argv){Verilated::commandArgs(argc,argv);try{
 Bench b;
 b.command({0x0c,0,0,0,0,0});for(unsigned v:{1u,50u,4u,0u,0u,0u,0u,11u})b.write(0,v);
 check(b.result()==0,"INIT response");
 b.command({8,0,0,0,1,0});check(b.d.drq,"read DMA request");
 for(unsigned i=0;i<512;++i){check(b.d.media_address==i,"read byte address");b.d.dma_read=1;b.d.terminal_count=i==511;b.tick();}
 b.d.dma_read=0;b.d.terminal_count=0;b.tick();check(b.result()==0&&b.d.read_count==512,"DMA read completion");
 b.command({10,0,0,0,1,0});
 for(unsigned i=0;i<512;++i){b.d.data_i=i&255;b.d.dma_write=1;b.d.terminal_count=i==511;b.d.clk=0;b.d.eval();check(b.d.media_write&&b.d.media_address==i&&b.d.media_wdata==(i&255),"DMA write byte");b.d.clk=1;b.d.eval();}
 b.d.dma_write=0;b.d.terminal_count=0;b.tick();check(b.result()==0&&b.d.write_count==512,"DMA write completion");
 b.command({15,0,0,0,1,0});
 for(unsigned i=0;i<512;++i){check(b.d.media_address==0xfffe00+i,"sector SRAM address");b.d.dma_write=1;b.d.terminal_count=i==511;b.tick();}
 b.d.dma_write=0;b.d.terminal_count=0;b.tick();check(b.result()==0&&b.d.write_count==512,"WRITE BUFFER uses SRAM rather than disk");
 b.command({14,0,0,0,1,0});
 for(unsigned i=0;i<512;++i){check(b.d.media_address==0xfffe00+i,"READ BUFFER address");b.d.dma_read=1;b.d.terminal_count=i==511;b.tick();}
 b.d.dma_read=0;b.d.terminal_count=0;b.tick();check(b.result()==0&&b.d.read_count==512,"READ BUFFER uses SRAM rather than disk");
 b.command({0,0x20,0,0,0,0});check(b.result()==0x22,"absent drive status");
 b.command({3,0x20,0,0,0,0});check(!(b.read(1)&1),"sense initial REQ low");check((b.read(1)&3)==3,"sense response ready");check(b.read(0)==4,"sense not-ready");for(int i=0;i<4;++i)b.read(0);
 b.command({8,3,0x50,0x31,2,0});check(b.result()==2,"end-of-media bounds");
 b.command({6,3,0x7f,0x31,1,0});
 check(b.d.media_address>=10644992&&b.d.media_address<10653696,"format ignores sector field and stays on final track");
 while(b.d.media_write){check(b.d.media_address<10653696,"format media bounds");b.tick();}
 check(b.result()==0,"format completion");
 std::cout<<"PASS fixed-disk original DCB/INIT REQ phases, DMA read/write, absent drive sense and final-track bounds\n";
 }catch(const std::exception &e){std::cerr<<"FAIL "<<e.what()<<'\n';return 1;}}
