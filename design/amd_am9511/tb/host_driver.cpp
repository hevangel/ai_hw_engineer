#include "Vamd_am9511.h"
#include "verilated.h"
#include <boost/multiprecision/cpp_bin_float.hpp>
#include <boost/math/constants/constants.hpp>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <random>
using Wide=boost::multiprecision::number<boost::multiprecision::cpp_bin_float<100>>;
using Stack=std::array<uint8_t,16>;
struct Command {unsigned code,width,mask;std::string name,pattern;};
static uint64_t checks=0,cases=0,transfers=0;
static void check(bool v,const char* why){++checks;if(!v){std::fprintf(stderr,"FAIL host case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static Wide unpack(uint32_t w){int e=(w>>24)&127;if(e&64)e-=128;return !(w&0x800000)?Wide(0):boost::multiprecision::ldexp(Wide(w&0xffffff),e-24)*((w>>31)?-1:1);}
static uint32_t pack(Wide x){if(x==0)return 0;bool neg=x<0;if(neg)x=-x;int e;Wide m=boost::multiprecision::ldexp(boost::multiprecision::frexp(x,&e),24),f=floor(m);uint32_t w=f.convert_to<uint32_t>();Wide t=m-f;if(t>Wide(0.5)||(t==Wide(0.5)&&(w&1)))++w;if(w==0x1000000){w>>=1;++e;}return (neg?0x80000000u:0)|((e&127)<<24)|w;}
static uint32_t get(const Stack& s,unsigned offset,unsigned bytes){uint32_t w=0;for(unsigned i=0;i<bytes;++i)w=(w<<8)|s[offset+i];return w;}
static void put(Stack& s,unsigned offset,unsigned bytes,uint32_t w){for(unsigned i=0;i<bytes;++i)s[offset+i]=uint8_t(w>>((bytes-i-1)*8));}
class Host {
public:
 Vamd_am9511 d;
 Host(){d.cs_n_i=d.rd_n_i=d.wr_n_i=d.eack_n_i=d.svack_n_i=1;d.reset_i=1;d.cd_i=0;d.data_i=0;tick();d.reset_i=0;tick();}
 void tick(){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
 uint8_t access(bool write,bool command,uint8_t data=0,unsigned hold=0){
  ++transfers;d.cs_n_i=0;d.rd_n_i=write;d.wr_n_i=!write;d.cd_i=command;d.data_i=data;d.eval();
  check(!d.pause_n_o,"new cycle requests PAUSE");unsigned clocks=0;
  while(!d.pause_n_o){tick();check(++clocks<=6110,"host bounded wait");}
  check(d.data_oe_o==!write,"bus output enable");uint8_t result=d.data_o;
  for(unsigned i=0;i<hold;++i){tick();check(d.pause_n_o,"accepted held cycle");if(!write)check(d.data_o==result,"held read latch");}
  d.cs_n_i=d.rd_n_i=d.wr_n_i=1;d.eval();check(!d.data_oe_o,"released bus");tick();return result;
 }
 void load(const Stack& s,unsigned hold=0){for(unsigned i=16;i>0;--i)access(true,false,s[i-1],hold);}
 Stack read(unsigned hold=0){Stack s{};for(auto& b:s)b=access(false,false,0,hold);return s;}
 void issue(unsigned cmd,unsigned hold=0){access(true,true,uint8_t(cmd),hold);}
 void wait(){unsigned n=0;while(!d.end_pull_low_o){tick();check(++n<=6105,"completion bound");}}
 uint8_t status(){return access(false,true);}
 void seed(){
  Stack s{};put(s,0,4,1);put(s,4,4,0xffffffff);load(s);issue(0x2c);wait();check(status()==0x21,"carry seed");
  s={};put(s,4,4,7);load(s);issue(0x2f);wait();check(status()==0x11,"divide-zero/error seed preserves carry");
 }
};
struct Result {uint32_t word;unsigned error;bool carry,defined,is_float,single,approximate;Wide truth;};
static Result evaluate(const Command& c,const Stack& s){
 unsigned n=c.width/8;uint32_t a=get(s,0,n),b=get(s,n,n),r=0;unsigned error=0;bool carry=false,defined=true,is_float=false,single=n==2,approximate=false;Wide truth=0;
 unsigned op=c.code&31;uint64_t limit=uint64_t(1)<<c.width,mask=limit-1,min=limit/2;
 int64_t sa=(a&min)?int64_t(a)-int64_t(limit):a,sb=(b&min)?int64_t(b)-int64_t(limit):b;
 if(c.code==0){return {0,0,false,true,false,false,false,Wide(0)};}
 if(c.name=="PUPI"){r=0x02c90fda;is_float=true;}
 else if(c.name=="CHSF"){r=(a&0x800000)?a^0x80000000u:a;is_float=true;}
 else if(c.name[0]=='P'&&c.name!="PWR"){r=c.name.substr(0,3)=="POP"?b:a;is_float=!(c.code&32);}
 else if(c.name.substr(0,3)=="XCH"){r=b;is_float=!(c.code&32);}
 else if(c.code&32){
  int64_t value=0;
  switch(op){
   case 12:value=sa+sb;r=(uint64_t(a)+b)&mask;carry=uint64_t(a)+b>=limit;error=value< -int64_t(min)||value>=int64_t(min);break;
   case 13:value=sb-sa;r=(uint64_t(b)-a)&mask;carry=b<a;error=a==min||value< -int64_t(min)||value>=int64_t(min);break;
   case 14:case 22:
    if(a==min||b==min){r=min;error=1;defined=single||op==14;}
    else {uint64_t p=uint64_t(sa*sb),upper=(p>>c.width)&mask;r=(op==22?upper:p)&mask;error=op==14&&upper!=0;}
    break;
   case 15:if(!a){r=b;error=8;}else if(!single&&(a==min||b==min)){r=0;error=1;defined=false;}else r=uint64_t(sb/sa)&mask;break;
   case 20:r=(uint64_t(0)-a)&mask;error=a==min;break;
   default:std::abort();
  }
 }else if(c.code>=0x1c){
  if(op==28||op==29){truth=op==29?Wide(int16_t(a)):Wide(int32_t(a));r=pack(truth);is_float=true;single=false;}
  else {Wide aa=unpack(a),mag=abs(aa);int bits=op==31?15:31;
   if(mag>=boost::multiprecision::ldexp(Wide(1),bits)){r=a;error=1;is_float=true;single=false;}
   else {single=op==31;r=uint32_t(aa.convert_to<int64_t>())&(single?0xffffu:0xffffffffu);}
  }
 }else {
  is_float=true;single=false;Wide aa=unpack(a),bb=unpack(b);approximate=c.code>=1&&c.code<=11;
  switch(op){
   case 1:if(aa<0)error=4;else truth=sqrt(aa);break;
   case 2:truth=sin(aa);break;case 3:truth=cos(aa);break;case 4:truth=tan(aa);break;
   case 5:if(abs(aa)>1)error=12;else truth=asin(aa);break;
   case 6:if(abs(aa)>1)error=12;else truth=acos(aa);break;
   case 7:truth=atan(aa);break;
   case 8:if(aa<=0)error=4;else truth=log10(aa);break;
   case 9:if(aa<=0)error=4;else truth=log(aa);break;
   case 10:if(abs(aa)>32)error=12;else truth=exp(aa);break;
   case 11:if(bb<=0)error=4;else {Wide exponent=aa*log(bb);if(abs(exponent)>32)error=12;else truth=exp(exponent);}break;
   case 16:truth=aa+bb;break;case 17:truth=bb-aa;break;case 18:truth=aa*bb;break;
   case 19:if(aa==0){truth=bb;error=8;r=b;}else truth=bb/aa;break;
   default:std::abort();
  }
  if(approximate&&error)defined=false;
  else if(op!=19||!error){r=pack(truth);if(truth!=0){int e;boost::multiprecision::frexp(abs(truth),&e);if(e>63)error=1;if(e< -64)error=2;}}
 }
 return {r,error,carry,defined,is_float,single,approximate,truth};
}
static void exercise(Host& h,const Command& c,const Stack& before,bool sr,unsigned hold){
 ++cases;h.seed();h.load(before,hold);Result e=evaluate(c,before);h.issue(c.code|(sr?128:0),hold);h.wait();
 check(h.d.svreq_o==sr,"completed service request");uint8_t actual_status=h.status();check(!h.d.end_pull_low_o,"access acknowledges END");check(h.d.svreq_o==sr,"access preserves SVREQ");
 Stack after=h.read(hold);std::string pattern=c.pattern;unsigned bytes=c.width/8;
 if(c.code==0x1f){if(e.error){pattern="A B C ?";bytes=4;}else bytes=2;}
 if(c.code==0x1d)bytes=2;
 unsigned result_bytes=e.single?2:4;uint32_t actual=get(after,0,result_bytes);
 if(e.defined&&e.approximate){Wide delta=abs(unpack(actual)-e.truth),bound=Wide("2e-7")+abs(e.truth)*Wide("7e-7");check(delta<=bound,"whole-chip numerical result");e.word=actual;}
 uint32_t sign_mask=e.single?0x8000u:0x80000000u;
 unsigned flags=((e.word&sign_mask)?0x40:0)|((e.is_float?!(e.word&0x800000):e.word==0)?0x20:0)|(e.error<<1)|e.carry;
 if(c.code==0)flags=0;
 unsigned expected_status=(0x11&~c.mask)|(flags&c.mask);
 unsigned status_mask=e.defined?127:31;
 if((actual_status&status_mask)!=(expected_status&status_mask)){std::fprintf(stderr,"command=%s expected status=%02x actual=%02x result=%08x\n",c.name.c_str(),expected_status,actual_status,actual);check(false,"affected/preserved status");}
 std::istringstream words(pattern);std::string token;unsigned offset=0;
 while(words>>token){
  unsigned count=bytes;bool compare=true;uint32_t word=0;
  if(token=="?")compare=false;
  else if(token=="R"){word=e.word;compare=e.defined;}
  else if(token=="Rhi"){word=e.word>>16;count=2;}
  else if(token=="Rlo"){word=e.word&0xffff;count=2;}
  else if(token=="PI")word=0x02c90fda;
  else {unsigned old=(token[0]-'A')*(c.width/8);if(token.size()==3){old=(token[0]-'A')*4+(token.substr(1)=="lo"?2:0);count=2;}word=get(before,old,count);}
  // Error-path stack contents not pinned by the original descriptions are
  // excluded; explicit fixed divide/conversion errors remain compared.
  if(e.approximate&&!e.defined)compare=false;
  if(compare&&get(after,offset,count)!=word){std::fprintf(stderr,"command=%s token=%s offset=%u expected=%08x actual=%08x\n",c.name.c_str(),token.c_str(),offset,word,get(after,offset,count));check(false,"manufacturer stack survivor/rotation");}
  offset+=count;
 }
 check(offset==16,"complete manufacturer stack diagram");check(h.status()==actual_status,"byte reads preserve command status");
 check(h.read()==after,"sixteen-byte read rotation");
 if(sr){h.d.svack_n_i=0;h.tick();check(!h.d.svreq_o,"service acknowledge");h.d.svack_n_i=1;h.tick();check(!h.d.svreq_o,"service remains cleared");}
}
int main(int argc,char** argv){
 Verilated::commandArgs(argc,argv);check(argc>=2,"command CSV argument");std::ifstream f(argv[1]);check(bool(f),"manufacturer command table opens");std::string line;std::getline(f,line);std::vector<Command> commands;
 while(std::getline(f,line)){if(!line.empty()&&line.back()=='\r')line.pop_back();std::istringstream row(line);std::vector<std::string> fields;std::string field;while(std::getline(row,field,','))fields.push_back(field);check(fields.size()==6,"CSV row");unsigned mask=fields[4]=="ALL"?127:(fields[4].find('S')!=std::string::npos?64:0)|(fields[4].find('Z')!=std::string::npos?32:0)|(fields[4].find('E')!=std::string::npos?30:0)|(fields[4].find('C')!=std::string::npos?1:0);commands.push_back({unsigned(std::stoul(fields[0],nullptr,16)),unsigned(std::stoul(fields[2])),mask,fields[1],fields[3]});}
 check(commands.size()==43,"all legal base commands");Host h;std::mt19937 rng(0x9511a);
 const char* floats[]={"0","0.5","-0.5","1","-1","1.5","-1.5","32","-32","33","-33","32767.75","32768","2147483648"};
 const uint32_t integers[]={0,1,2,0x7fff,0x8000,0xffff,0x7fffffff,0x80000000,0xffffffff};
 for(unsigned n=0;n<32;++n)for(const auto& c:commands)for(bool sr:{false,true}){
  Stack s{};for(auto& b:s)b=uint8_t(rng());unsigned bytes=c.width/8;uint32_t a,b;
  if((c.code&32)||c.code==0x1c||c.code==0x1d){a=integers[n%9];b=integers[(n*3+1)%9];}
  else {a=pack(Wide(floats[n%14]));b=pack(Wide(floats[(n*3+1)%14]));}
  put(s,0,bytes,a);put(s,bytes,bytes,b);exercise(h,c,s,sr,n%4);
 }
 // Reset preserves previously written stack and clears status/service state.
 Stack s{};for(auto& b:s)b=uint8_t(rng());h.load(s);h.d.reset_i=1;h.tick();h.d.reset_i=0;h.tick();check(h.read()==s,"native reset preserves stack");check(h.status()==0&&!h.d.svreq_o,"reset status/service");
 // A data read queued while FDIV is busy must complete with its result byte.
 s={};put(s,0,4,pack(Wide(2)));put(s,4,4,pack(Wide(7)));h.load(s);h.issue(0x93);check(h.status()&128,"busy status is readable");uint8_t first=h.access(false,false,0,5);check(first==uint8_t(pack(Wide("3.5"))>>24),"queued data access result");check(h.d.svreq_o,"queued access preserves completion service");
 // Tied LOW EACK exposes the completion pulse for less than a clock period.
 h.d.eack_n_i=0;h.issue(0x80);check(h.d.end_pull_low_o,"tied-EACK HIGH-phase completion pulse");h.d.clk_i=0;h.d.eval();check(!h.d.end_pull_low_o,"tied-EACK pulse ends at falling edge");h.tick();check(!h.d.end_pull_low_o,"completion pulse does not repeat");h.d.eack_n_i=1;
 std::printf("TEST PASSED: Am9511 host %llu all-command/service cases, %llu transfers, %llu checks\n",(unsigned long long)cases,(unsigned long long)transfers,(unsigned long long)checks);h.d.final();
}
