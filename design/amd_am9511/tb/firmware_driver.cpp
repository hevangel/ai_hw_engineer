#include "Vtb_top.h"
#include "verilated.h"
#include <boost/multiprecision/cpp_bin_float.hpp>
#include <array>
#include <deque>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
extern "C" {
#include "i8080.h"
}
using Wide=boost::multiprecision::number<boost::multiprecision::cpp_bin_float<100>>;
static uint64_t checks=0,cases=0,instructions=0,io_reads=0,io_writes=0;
static void check(bool v,const char* why){++checks;if(!v){std::fprintf(stderr,"FAIL firmware case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static uint32_t packed(Wide x){if(x==0)return 0;bool neg=x<0;if(neg)x=-x;int e;Wide f=boost::multiprecision::ldexp(boost::multiprecision::frexp(x,&e),24),down=floor(f);uint32_t m=down.convert_to<uint32_t>();Wide tail=f-down;if(tail>Wide(0.5)||(tail==Wide(0.5)&&(m&1)))++m;if(m==0x1000000){m>>=1;++e;}return (neg?0x80000000u:0)|((e&127)<<24)|m;}
static Wide unpack(uint32_t w){int e=(w>>24)&127;if(e&64)e-=128;return !(w&0x800000)?Wide(0):boost::multiprecision::ldexp(Wide(w&0xffffff),e-24)*((w>>31)?-1:1);}
struct Context {
 std::array<uint8_t,65536> rtl{},oracle{};
 std::deque<std::pair<uint8_t,uint8_t>> reads,writes;
 std::vector<uint16_t> written;
};
static uint8_t memory_read(void* p,uint16_t a){return static_cast<Context*>(p)->oracle[a];}
static void memory_write(void* p,uint16_t a,uint8_t d){auto& c=*static_cast<Context*>(p);c.oracle[a]=d;c.written.push_back(a);}
static uint8_t port_read(void* p,uint8_t port){auto& q=static_cast<Context*>(p)->reads;check(!q.empty()&&q.front().first==port,"external ISS exact input-port sequence");uint8_t v=q.front().second;q.pop_front();return v;}
static void port_write(void* p,uint8_t port,uint8_t value){auto& q=static_cast<Context*>(p)->writes;check(!q.empty()&&q.front()==std::make_pair(port,value),"external ISS exact output-port/data");q.pop_front();}
static uint8_t flags(const i8080& c){return (c.sf<<7)|(c.zf<<6)|(c.hf<<4)|(c.pf<<2)|2|c.cf;}
static uint64_t regs(const i8080& c){return (uint64_t(c.a)<<48)|(uint64_t(c.b)<<40)|(uint64_t(c.c)<<32)|(uint64_t(c.d)<<24)|(uint64_t(c.e)<<16)|(uint64_t(c.h)<<8)|c.l;}
static void word(std::array<uint8_t,65536>& mem,unsigned a,uint32_t w){for(unsigned i=0;i<4;++i)mem[a+i]=uint8_t(w>>((3-i)*8));}
static uint32_t word(const std::array<uint8_t,65536>& mem,unsigned a){return (uint32_t(mem[a])<<24)|(uint32_t(mem[a+1])<<16)|(uint32_t(mem[a+2])<<8)|mem[a+3];}
struct Expected {uint32_t value;unsigned flags,mask;bool defined,approximate;Wide truth;};
static Expected expected(unsigned op,uint32_t a,uint32_t b){
 uint32_t r=0;bool single_divide=op==0x6f;unsigned error=0;bool carry=false,defined=true,approximate=false;Wide truth=0;
 if(op&32){int64_t aa=int32_t(a),bb=int32_t(b),v=0;
  switch(op){
   case 0x6f:{int16_t divisor=int16_t(a>>16),numerator=int16_t(a);uint16_t q=divisor?uint16_t(int32_t(numerator)/int32_t(divisor)):uint16_t(numerator);r=(uint32_t(q)<<16)|(b>>16);error=divisor?0:8;break;}
   case 0x2c:v=aa+bb;r=uint32_t(v);carry=uint64_t(a)+b>0xffffffffu;error=v>2147483647LL||v< -2147483648LL;break;
   case 0x2d:v=bb-aa;r=uint32_t(v);carry=b<a;error=a==0x80000000u||v>2147483647LL||v< -2147483648LL;break;
   case 0x2e:case 0x36:if(a==0x80000000u||b==0x80000000u){r=0x80000000u;error=1;defined=op==0x2e;}else{uint64_t p=uint64_t(aa*bb);r=op==0x36?uint32_t(p>>32):uint32_t(p);error=op==0x2e&&uint32_t(p>>32)!=0;}break;
   case 0x2f:if(!a){r=b;error=8;}else if(a==0x80000000u||b==0x80000000u){error=1;defined=false;}else r=uint32_t(bb/aa);break;
   default:std::abort();
  }
 }else{Wide aa=unpack(a),bb=unpack(b);
  switch(op){case 0x1a:truth=unpack(0x02c90fda);break;case 0x10:truth=aa+bb;break;case 0x11:truth=bb-aa;break;case 0x12:truth=aa*bb;break;case 0x13:if(aa==0){truth=bb;error=8;}else truth=bb/aa;break;
   case 0x0b:approximate=true;if(bb<=0){error=4;defined=false;}else{Wide exponent=aa*log(bb);if(abs(exponent)>32){error=12;defined=false;}else truth=exp(exponent);}break;
   default:std::abort();}
  r=op==0x1a?0x02c90fda:packed(truth);
 }
 bool zero=single_divide?(r>>16)==0:(op&32)?r==0:!(r&0x800000);unsigned s=(r>>31?64:0)|(zero?32:0)|(error<<1)|carry;
 return {r,s,defined?127u:31u,defined,approximate,truth};
}
static void run(const std::array<uint8_t,65536>& program,bool poll,unsigned op,uint32_t a,uint32_t b){
 ++cases;Context c;c.rtl=program;word(c.rtl,0x2000,b);word(c.rtl,0x2004,a);
 unsigned entry=poll?0x30:0;
 const uint8_t caller[]={0x31,0x00,0x90,0x21,0x00,0x20,0x11,0x04,0x20,0x01,0x00,0x21,0x3e,uint8_t(op),0xcd,uint8_t(entry),0x00,0x76};
 for(unsigned i=0;i<sizeof(caller);++i)c.rtl[0x100+i]=caller[i];c.oracle=c.rtl;
 Vtb_top d;i8080 cpu;i8080_init(&cpu);cpu.userdata=&c;cpu.read_byte=memory_read;cpu.write_byte=memory_write;cpu.port_in=port_read;cpu.port_out=port_write;
 // Boot overlay feeds exactly JMP 0100 for the first three reads at 0000â€“0002.
 // The overlay is removed at its retirement; all subsequent PCs see original
 // code bytes. The external ISS receives the same temporary boot mapping.
 c.oracle[0]=0xc3;c.oracle[1]=0;c.oracle[2]=1;bool boot=true;
 d.reset_n_i=0;d.ram_ready_i=1;d.ram_data_i=0;d.clk_i=0;d.eval();d.clk_i=1;d.eval();d.clk_i=0;d.eval();d.reset_n_i=1;
 for(unsigned cycle=0;cycle<2000000;++cycle){
  d.clk_i=0;d.eval();d.ram_ready_i=(cycle%11)!=3;
  d.ram_data_i=boot&&d.address_o<3?uint8_t(d.address_o==0?0xc3:d.address_o==1?0:1):c.rtl[d.address_o];d.eval();
  check(!d.fault_o,"CPU has no opcode/control fault");
  if(d.req_o&&d.status_o==0xa2){check(d.address_o==cpu.pc,"exact next fetch PC");check(d.ram_data_i==c.oracle[cpu.pc],"exact next instruction byte");}
  bool accepted=d.req_o&&(d.io_o?true:d.ram_ready_i);
  // PAUSE is encoded by the chip's read_data and CPU READY internally. Exported
  // request persists through stalls; determine actual acceptance via READY.
  if(d.io_o)accepted=false;
  // I/O access is recorded when its bus request ends after a rising edge below.
  bool was_io=d.req_o&&d.io_o;bool was_write=d.write_o;uint8_t port=uint8_t(d.address_o),out=d.write_data_o,in=d.read_data_o;
  if(accepted&&d.write_o&&!d.io_o)c.rtl[d.address_o]=d.write_data_o;
  d.clk_i=1;d.eval();
  if(was_io&&(!d.req_o||!d.io_o)){
   check(port==0xc0||port==0xc1,"manufacturer native I/O ports");
   if(was_write){c.writes.emplace_back(port,out);++io_writes;}
   else{c.reads.emplace_back(port,in);++io_reads;}
  }
  if(d.retire_o){
   uint16_t before=cpu.pc;i8080_step(&cpu);++instructions;
   if(d.pc_o!=cpu.pc||d.sp_o!=cpu.sp||d.regs_o!=regs(cpu)||d.flags_o!=flags(cpu)){std::fprintf(stderr,"poll=%d op=%02x before=%04x rtl pc=%04x iss pc=%04x rtl flags=%02x iss flags=%02x\n",poll,op,before,d.pc_o,cpu.pc,d.flags_o,flags(cpu));check(false,"independent instruction state/exact post-PC");}
   check(d.inte_o==cpu.iff&&d.halted_o==cpu.halted,"independent CPU control state");
   for(auto address:c.written)check(c.rtl[address]==c.oracle[address],"independent memory write effects");c.written.clear();
   check(c.reads.empty()&&c.writes.empty(),"all instruction I/O consumed exactly");
   if(boot){check(before==0&&cpu.pc==0x100,"exact boot jump landing");boot=false;for(unsigned i=0;i<3;++i)c.oracle[i]=program[i];}
  }
  if(d.halted_o){
   check(cpu.halted&&cpu.pc==0x112,"exact firmware return/HALT location");Expected e=expected(op,a,b);uint32_t r=word(c.rtl,0x2100);
   if(e.defined){if(e.approximate)check(abs(unpack(r)-e.truth)<=Wide("2e-7")+abs(e.truth)*Wide("7e-7"),"original firmware approximate result");else check(r==e.value,"original firmware exact result");}
   check((cpu.a&e.mask)==(e.flags&e.mask),"original firmware returned APU status");d.final();return;
  }
 }
 check(false,"firmware watchdog");
}
int main(int argc,char** argv){Verilated::commandArgs(argc,argv);check(argc>=2,"original object-code path");std::array<uint8_t,65536> program{};std::ifstream file(argv[1]);check(bool(file),"original code opens");std::string line;unsigned count=0;
 while(std::getline(file,line)){std::istringstream row(line);unsigned address,value;row>>std::hex>>address;while(row>>std::hex>>value){program[address++]=uint8_t(value);++count;}}
 check(count==108,"exact original routine length");
 const uint32_t ints[]={0,1,2,7,0x7fffffff,0x80000000,0x80000001,0xffffffff};
 const char* floats[]={"0","0.5","-0.5","1","-1","2","-2","7"};
 for(bool poll:{false,true})for(unsigned op:{0x2cu,0x2du,0x2eu,0x36u,0x2fu,0x10u,0x11u,0x12u,0x13u,0x0bu})for(unsigned n=0;n<16;++n){uint32_t a=(op&32)?ints[n%8]:packed(Wide(floats[n%8]));uint32_t b=(op&32)?ints[(n*3+1)%8]:packed(Wide(floats[(n*3+1)%8]));run(program,poll,op,a,b);}
 for(bool poll:{false,true}){
  run(program,poll,0x6f,0xffff8000u,0x12345678u); // SDIV -32768/-1: original host consumes exact two-byte result.
  run(program,poll,0x6f,0x00008000u,0x12345678u); // SDIV divide-zero retains numerator.
  run(program,poll,0x1a,packed(Wide(1)),packed(Wide(2))); // Native PUPI constant through original programs.
  run(program,poll,0x10,0x69800000u,0x01800000u); // Half-ULP addition, even lower mantissa.
  run(program,poll,0x10,0x69800000u,0x01800001u); // Half-ULP addition, odd lower mantissa.
 }
 std::printf("TEST PASSED: original AMD DEMAND/POLL firmware %llu cases, %llu independent exact-PC instructions, %llu reads/%llu writes, %llu checks\n",(unsigned long long)cases,(unsigned long long)instructions,(unsigned long long)io_reads,(unsigned long long)io_writes,(unsigned long long)checks);}
