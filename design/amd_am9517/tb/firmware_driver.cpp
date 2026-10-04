#include "Vtb_firmware.h"
#include "verilated.h"
#include <array>
#include <deque>
#include <vector>
#include <fstream>
#include <sstream>
#include <string>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
extern "C" {
#include "i8080.h"
}
static uint64_t checks=0,cases=0,instructions=0,transfers=0,reads=0,writes=0;
static void check(bool ok,const char* why){++checks;if(!ok){std::fprintf(stderr,"FAIL original firmware case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
struct Context{std::array<uint8_t,65536> rtl{},oracle{};std::deque<std::pair<uint8_t,uint8_t>> inputs,outputs;std::vector<uint16_t> changed;};
static uint8_t mem_read(void* p,uint16_t a){return static_cast<Context*>(p)->oracle[a];}
static void mem_write(void* p,uint16_t a,uint8_t v){auto& c=*static_cast<Context*>(p);c.oracle[a]=v;c.changed.push_back(a);}
static uint8_t io_read(void* p,uint8_t port){auto& q=static_cast<Context*>(p)->inputs;check(!q.empty()&&q.front().first==port,"independent exact input-port sequence");auto v=q.front().second;q.pop_front();return v;}
static void io_write(void* p,uint8_t port,uint8_t value){auto& q=static_cast<Context*>(p)->outputs;check(!q.empty()&&q.front()==std::make_pair(port,value),"independent exact output-port sequence/data");q.pop_front();}
static uint8_t flags(const i8080& c){return (c.sf<<7)|(c.zf<<6)|(c.hf<<4)|(c.pf<<2)|2|c.cf;}
static uint64_t regs(const i8080& c){return (uint64_t(c.a)<<48)|(uint64_t(c.b)<<40)|(uint64_t(c.c)<<32)|(uint64_t(c.d)<<24)|(uint64_t(c.e)<<16)|(uint64_t(c.h)<<8)|c.l;}
static std::array<uint8_t,65536> load(const char* filename,unsigned length){std::array<uint8_t,65536> mem{};std::ifstream file(filename);check(bool(file),"original object file opens");std::string line;unsigned count=0;while(std::getline(file,line)){std::istringstream row(line);unsigned address,value;row>>std::hex>>address;while(row>>std::hex>>value){mem[address++]=uint8_t(value);++count;}}check(count==length,"exact original object byte count");return mem;}
static void run(const std::array<uint8_t,65536>& original,bool simple,unsigned channel,unsigned length,uint16_t address,unsigned mode,unsigned command,unsigned variant){
 ++cases;Context c;c.rtl=original;std::vector<uint8_t> caller={0x31,0x00,0x90};
 if(!simple){const uint8_t setup[]={0x3e,0,0xd3,0x0d,0x3e,uint8_t(command),0xd3,8};caller.insert(caller.end(),std::begin(setup),std::end(setup));}
 caller.insert(caller.end(),{0xcd,0x00,0x30});
 if(!simple)caller.insert(caller.end(),{uint8_t(mode|channel),uint8_t(address),uint8_t(address>>8),uint8_t(length-1),uint8_t((length-1)>>8)});
 // Check programmed state through CPU reads before beginning DMA. The actual
 // historical routines remain immutable and their inline return PC is exact.
 caller.insert(caller.end(),{0x3e,0,0xd3,12});
 for(unsigned i=0;i<4;++i)caller.insert(caller.end(),{0xdb,uint8_t(channel*2+i/2),0x32,uint8_t(i),0x22});
 caller.push_back(0x76);uint16_t halt_pc=uint16_t(0x100+caller.size());
 for(unsigned i=0;i<caller.size();++i)c.rtl[0x100+i]=caller[i];c.rtl[0]=0xc3;c.rtl[1]=0;c.rtl[2]=1;c.oracle=c.rtl;

 Vtb_firmware d;i8080 cpu;i8080_init(&cpu);cpu.userdata=&c;cpu.read_byte=mem_read;cpu.write_byte=mem_write;cpu.port_in=io_read;cpu.port_out=io_write;
 d.reset_n_i=0;d.ram_ready_i=1;d.dma_ready_i=1;d.dreq_i=0;d.clk_i=0;d.eval();d.clk_i=1;d.eval();d.reset_n_i=1;unsigned shadow=0,completed=0;bool programmed=false,requested=false,released=false;
 for(unsigned cycle=0;cycle<1000000;++cycle){
  d.clk_i=0;d.eval();d.ram_ready_i=(cycle%13)!=4;d.ram_data_i=c.rtl[d.address_o];
  d.dma_ready_i=(cycle%(3+variant%7))!=1;
  d.dma_memory_data_i=((mode>>2)&3)==1?uint8_t(0x30+channel*7+completed):c.rtl[d.dma_address_o];
  unsigned idle=(shadow&64)?15:0;
  d.dreq_i=requested&&!released?uint8_t(idle^(1u<<channel)):uint8_t(idle);d.eval();
  check(!d.fault_o,"no CPU decode/control fault");
  if(d.req_o&&d.status_o==0xa2){check(d.address_o==cpu.pc,"exact next fetched PC");check(d.ram_data_i==c.oracle[cpu.pc],"exact next instruction byte");}
  if(requested){unsigned ack=(shadow&128)?d.dack_o:(d.dack_o^15);if(ack){check(ack==(1u<<channel),"exact selected historical-program channel");released=true;}}
  if(d.req_o&&(d.io_o||d.ram_ready_i)){
   if(d.io_o){check(uint8_t(d.address_o)<=15,"original AMD register ports");if(d.write_o){c.outputs.emplace_back(uint8_t(d.address_o),d.write_data_o);++writes;if(uint8_t(d.address_o)==8)shadow=d.write_data_o;if(uint8_t(d.address_o)==13)shadow=0;}
    else{check(d.dma_data_oe_o,"valid register read drives data");c.inputs.emplace_back(uint8_t(d.address_o),d.read_data_o);++reads;}}
   else if(d.write_o)c.rtl[d.address_o]=d.write_data_o;
  }
  if(d.dma_valid_o){
   check(requested&&programmed&&d.hlda_o&&d.dma_hrq_o&&d.dma_aen_o,"DMA only after original setup and actual CPU hold grant");
   check(completed<length&&d.dma_channel_o==channel,"exact DMA count/channel");uint16_t expected_address=uint16_t(address+((mode&32)?-int(completed):int(completed)));
   check(d.dma_address_o==expected_address,"independent exact DMA address sequence");unsigned strobes=(d.dma_memr_n_o<<3)|(d.dma_memw_n_o<<2)|(d.dma_ior_n_o<<1)|d.dma_iow_n_o;
   unsigned direction=(mode>>2)&3;check(strobes==(direction==0?15:direction==1?9:6),"independent DMA transfer strobes");
   check(bool(!d.dma_eop_n_o)==(completed==length-1),"terminal output only on final programmed transfer");
   if(direction==1){uint8_t value=uint8_t(0x30+channel*7+completed);check(d.dma_memory_data_i==value,"peripheral data path");c.rtl[d.dma_address_o]=d.dma_memory_data_i;}
   else if(direction==2)check(d.dma_memory_data_i==uint8_t(0xa5^completed^(variant*3)),"original setup memory-to-peripheral data");
   ++completed;++transfers;
  }
  d.clk_i=1;d.eval();
  if(d.retire_o){uint16_t pc=cpu.pc;uint8_t opcode=c.oracle[pc];i8080_step(&cpu);
   // AMD Am9080A manufacturer ANA/ANI semantics clear AC. This narrow adapter
   // is independently sourced in amd_am9080/spec/spec.md, not derived from RTL.
   if(opcode==0xe6||(opcode&0xf8)==0xa0)cpu.hf=0;
   ++instructions;if(d.pc_o!=cpu.pc||d.sp_o!=cpu.sp||d.regs_o!=regs(cpu)||d.flags_o!=flags(cpu)){std::fprintf(stderr,"original PC=%04x rtl PC=%04x iss PC=%04x rtl flags=%02x iss flags=%02x\n",pc,d.pc_o,cpu.pc,d.flags_o,flags(cpu));check(false,"independent exact retirement state/PC");}
   check(d.inte_o==cpu.iff&&d.halted_o==cpu.halted,"independent CPU control state");for(auto a:c.changed)check(c.rtl[a]==c.oracle[a],"independent CPU memory effects");c.changed.clear();check(c.inputs.empty()&&c.outputs.empty(),"each exact instruction I/O consumed");
  }
  if(d.halted_o&&!programmed){check(cpu.halted&&cpu.pc==halt_pc,"exact return after inline parameters and caller HALT");
   check(c.rtl[0x2200]==uint8_t(address)&&c.rtl[0x2201]==uint8_t(address>>8),"original setup exact address readback");check(c.rtl[0x2202]==uint8_t(length-1)&&c.rtl[0x2203]==uint8_t((length-1)>>8),"original setup exact count readback"); for(unsigned i=0;i<length;++i){uint16_t a=uint16_t(address+((mode&32)?-int(i):int(i)));c.rtl[a]=uint8_t(0xa5^i^(variant*3));c.oracle[a]=c.rtl[a];}
   programmed=true;requested=true;}
  if(programmed&&completed==length&&!d.dma_hrq_o&&!d.hlda_o){check(released,"request removed after native acknowledgment");d.final();return;}
 }
 check(false,"original software/DMA watchdog");
}
int main(int argc,char** argv){Verilated::commandArgs(argc,argv);check(argc>=3,"original program paths");auto stup=load(argv[1],33),sdma=load(argv[2],132);
 for(unsigned variant=0;variant<8;++variant)run(stup,true,2,8,0x0f00,0x98,0x62,variant);
 unsigned variant=0;for(unsigned channel=0;channel<4;++channel)for(unsigned direction=0;direction<3;++direction)for(unsigned dec=0;dec<2;++dec)for(unsigned autoinit=0;autoinit<2;++autoinit)for(unsigned timing=0;timing<3;++timing){unsigned n=variant++,length=1+n%16;unsigned mode=0x80|(direction<<2)|(dec<<5)|(autoinit<<4),command=(timing==1?8:timing==2?32:0)|((n%4)<<6);run(sdma,false,channel,length,dec?0x0005:0xfff8,mode,command,n);}
 std::printf("TEST PASSED: original Am9517 STUP/SDMA %llu cases, %llu independent exact-PC instructions, %llu DMA transfers, %llu reads/%llu writes, %llu checks\n",(unsigned long long)cases,(unsigned long long)instructions,(unsigned long long)transfers,(unsigned long long)reads,(unsigned long long)writes,(unsigned long long)checks);
}
