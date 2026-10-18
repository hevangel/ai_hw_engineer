// Independent arithmetic oracle: physical build-host x87, not an RTL model.
#include "Vintel_8087.h"
#include "verilated.h"
#include <array>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <random>
#include <sstream>
#include <stdexcept>
#include <vector>

static_assert(LDBL_MANT_DIG==64 && LDBL_MAX_EXP==16384,
              "Regression needs a real x87 extended-precision host");
using Ext=std::array<uint8_t,10>;
static unsigned checks=0;
static void require(bool ok,const std::string &s) {
    ++checks; if(!ok) throw std::runtime_error(s);
}
static Ext bits(long double x) { Ext v{}; std::memcpy(v.data(),&x,10); return v; }
static long double number(const Ext &v) { long double x=0; std::memcpy(&x,v.data(),10); return x; }
static std::string hex(const Ext &v) {
    std::ostringstream s; for(int i=9;i>=0;--i) s<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(v[i]); return s.str();
}
static void host_cw(uint16_t cw) { asm volatile("fldcw %0"::"m"(cw)); }
static long double oracle(long double a,long double b,int op,uint16_t cw) {
    uint16_t old; asm volatile("fnstcw %0":"=m"(old));
    host_cw(uint16_t((cw&0x0f00)|0x007f));
    volatile long double va=a,vb=b,r=0;
    switch(op) {case 0:r=va+vb;break;case 1:r=va*vb;break;case 4:r=va-vb;break;case 6:r=va/vb;break;default:break;}
    long double answer=r; host_cw(old); return answer;
}
static long double oracle_round(long double x,uint16_t cw) {
    uint16_t old;asm volatile("fnstcw %0":"=m"(old));host_cw(uint16_t((cw&0x0f00)|0x007f));
    long double result;asm volatile("fldt %1; frndint; fstpt %0":"=m"(result):"m"(x));host_cw(old);return result;
}
static float oracle_single(long double x,uint16_t cw) {
    uint16_t old;asm volatile("fnstcw %0":"=m"(old));host_cw(uint16_t((cw&0x0f00)|0x007f));
    float result;asm volatile("fldt %1; fstps %0":"=m"(result):"m"(x));host_cw(old);return result;
}
class Bench {
public:
    Vintel_8087 d;
    std::vector<uint8_t> mem=std::vector<uint8_t>(1<<20);
    uint64_t cycles=0;
    bool held=false;
    uint32_t held_address=0;
    uint8_t held_data=0;
    bool held_write=false;
    bool force_stall=false;
    unsigned writes=0,reads=0;
    Bench() { d.rst_n=0; tick();tick();d.rst_n=1;tick(); }
    void tick() {
        d.clk=0;d.eval();
        if(held&&d.rst_n) require(d.mem_valid_o && d.mem_address_o==held_address &&
            d.mem_write_o==held_write && (!held_write||d.mem_wdata_o==held_data),"stalled bus changed");
        d.mem_ready_i=!force_stall&&(cycles%7)!=2&&(cycles%7)!=3;
        d.mem_rdata_i=mem.at(d.mem_address_o);d.eval();
        held=d.rst_n&&d.mem_valid_o&&!d.mem_ready_i;
        held_address=d.mem_address_o;held_write=d.mem_write_o;held_data=d.mem_wdata_o;
        if(d.mem_valid_o&&d.mem_ready_i) {
            if(d.mem_write_o) {mem[d.mem_address_o]=d.mem_wdata_o;++writes;} else ++reads;
        }
        d.clk=1;d.eval();++cycles;
    }
    void cmd(uint8_t op,uint8_t md,uint32_t addr=0,uint32_t ip=0x12345,bool reject=false) {
        require(d.cmd_ready_o,"command interface not ready");
        d.opcode_i=op;d.modrm_i=md;d.address_i=addr;d.instruction_i=ip;d.cmd_valid_i=1;
        tick();d.cmd_valid_i=0;
        unsigned n=0;while(!d.done_o&&n++<3000)tick();
        require(d.done_o,"instruction timeout");
        require(bool(d.unsupported_o)==reject,"unexpected encoding classification");
        require((d.status_o&0x40)==0,"later-x87 stack fault bit leaked into original status");
    }
    void init() {cmd(0xdb,0xe3);}
    void cw(uint16_t c) {mem[0x80]=uint8_t(c);mem[0x81]=uint8_t(c>>8);cmd(0xd9,0x28,0x80);}
    void load(long double x) {load_bits(bits(x));}
    void load_bits(const Ext &x) {std::memcpy(mem.data()+0x100,x.data(),10);cmd(0xdb,0x28,0x100);}
    Ext top_bits(unsigned logical=0) const {
        unsigned top=(d.status_o>>11)&7, offset=((top+logical)&7)*80; Ext v{};
        for(unsigned i=0;i<80;++i) if((d.registers_o[(offset+i)/32]>>((offset+i)%32))&1) v[i/8]|=uint8_t(1u<<(i%8));
        return v;
    }
    long double top(unsigned i=0)const{return number(top_bits(i));}
    void expect(long double x,const std::string &where,unsigned i=0) {
        Ext got=top_bits(i),want=bits(x);require(got==want,where+" got="+hex(got)+" expected="+hex(want));
    }
    template<class T> void put(uint32_t addr,T x) {std::memcpy(mem.data()+addr,&x,sizeof x);}
    template<class T> T get(uint32_t addr) {T x;std::memcpy(&x,mem.data()+addr,sizeof x);return x;}
};

static void architecture(Bench &b) {
    require(b.d.control_o==0x03ff&&b.d.tags_o==0xffff,"original reset state");
    b.cmd(0xd9,0xe8);b.expect(1,"FLD1");
    b.cmd(0xd9,0xee);b.expect(0,"FLDZ");b.expect(1,"stack order",1);
    b.cmd(0xd9,0xc9);b.expect(1,"FXCH");b.expect(0,"FXCH lower",1);
    b.cmd(0xdd,0xd9);b.expect(1,"FSTP ST1");
    b.init();require(b.d.tags_o==0xffff&&b.d.control_o==0x03ff,"FINIT");
    b.load(5);b.load(2);b.cmd(0xdc,0xe1);b.expect(-3,"DC FSUBR",1);
    b.init();b.load(5);b.load(2);b.cmd(0xde,0xe9);b.expect(3,"DE FSUBP");
    b.init();b.load(5);b.load(2);b.cmd(0xd8,0xe9);b.expect(3,"D8 FSUBR");
    b.init();b.load(5);b.load(2);b.cmd(0xde,0xf9);b.expect(2.5L,"DE FDIVP");
    b.init();b.load(1);b.load(2);b.cmd(0xd8,0xd1);require((b.d.status_o&0x4500)==0,"FCOM greater");
    b.cmd(0xd9,0xc9);b.cmd(0xd8,0xd1);require((b.d.status_o&0x4500)==0x100,"FCOM less");
    b.cmd(0xd9,0xe4);require((b.d.status_o&0x4500)==0,"FTST");
    b.init();b.cmd(0xd9,0xe4);require((b.d.status_o&0x4501)==0x4501,"empty compare masked");
    b.init();for(int i=0;i<9;++i)b.cmd(0xd9,0xe8);
    require((b.d.status_o&1)!=0,"stack overflow IE");require(std::isnan(b.top()),"stack overflow indefinite");
    b.init();b.cmd(0xd9,0xf6);require(((b.d.status_o>>11)&7)==7&&b.d.tags_o==0xffff,"FDECSTP without tag mutation");
    b.cmd(0xd9,0xf7);require(((b.d.status_o>>11)&7)==0,"FINCSTP wrap");
    b.cmd(0xdf,0xe0,0,0,true); // FNSTSW AX belongs to later hardware.
    b.cmd(0xda,0xe9,0,0,true); // FUCOMPP belongs to later hardware.
    b.init();b.load(4);b.load(0);b.cw(0x03fb);b.cmd(0xde,0xf9);
    require((b.d.status_o&4)&&!b.d.int_o,"interrupt-enable mask");b.expect(0,"unmasked divide retains top");b.expect(4,"unmasked divide retains destination",1);
    b.cmd(0xdb,0xe0);require(b.d.int_o,"FENI raises pending interrupt");
    b.cmd(0xdb,0xe1);require(!b.d.int_o,"FDISI masks interrupt");
    require((b.d.status_o&0x80)!=0,"IR status survives interrupt-disable mask");
    b.d.cpu_wait_i=1;b.tick();require(b.d.int_o,"WAIT overrides IEM to prevent deadlock");b.d.cpu_wait_i=0;b.tick();
    b.cmd(0xdb,0xe2);require((b.d.status_o&0x3f)==0&&!b.d.busy_o,"FCLEX clears pending busy");
    b.init();b.load(3);b.load(8);b.cmd(0xd9,0xf8);b.expect(2,"FPREM");require((b.d.status_o&0x4700)==0x4000,"FPREM quotient 2 condition bits");
    b.init();b.load(12);b.cmd(0xd9,0xf4);b.expect(1.5L,"FXTRACT significand");b.expect(3,"FXTRACT exponent",1);
    b.init();b.load(-0.0L);b.cmd(0xd9,0xf4);b.expect(-0.0L,"8087 FXTRACT zero");b.expect(-0.0L,"8087 FXTRACT zero exponent",1);
    b.init();b.load(3);b.load(1.5L);b.cmd(0xd9,0xfd);b.expect(12,"FSCALE");
    b.init();b.load(2);b.cmd(0xd9,0xfa);b.expect(std::sqrt(2.0L),"FSQRT 2");
    b.init();b.load(-4);b.cmd(0xd9,0xfa);require(std::isnan(b.top())&&(b.d.status_o&1),"negative sqrt");
    for(unsigned rc=0;rc<4;++rc) {
        b.init();b.cw(uint16_t(0x03ff|(rc<<10)));b.load(2.5L);b.cmd(0xd9,0xfc);
        b.expect(rc==2?3:2,"FRNDINT modes");
    }
    // Original projective infinity differs from later x87 affine-only mode.
    b.init();b.load(INFINITY);b.load(INFINITY);b.cmd(0xd8,0xc1);
    require(std::isnan(b.top())&&(b.d.status_o&1),"projective infinity + infinity");
    b.init();b.cw(0x13ff);b.load(INFINITY);b.load(INFINITY);b.cmd(0xd8,0xc1);
    require(std::isinf(b.top())&&!(b.d.status_o&1),"affine infinity + infinity");
    std::cout<<"PASS architecture, stack, original control and exception behavior\n";
}

static void formats(Bench &b) {
    for(int16_t n:{int16_t(0),int16_t(-32768),int16_t(32767),int16_t(-9)}) {
        b.init();b.put(0x200,n);b.cmd(0xdf,0x00,0x200);b.expect(n,"FILD16");
        b.cmd(0xdf,0x18,0x300);require(b.get<int16_t>(0x300)==n,"FISTP16");
    }
    for(int32_t n:{0,1,-1,32767,-32768,123456789,-123456789}) {
        b.init();b.put(0x200,n);b.cmd(0xdb,0x00,0x200);b.expect(n,"FILD32");
        b.cmd(0xdb,0x18,0x300);require(b.get<int32_t>(0x300)==n,"FISTP32");
    }
    for(int64_t n:{INT64_C(0),INT64_C(-9223372036854775807)-1,INT64_C(9223372036854775807),INT64_C(-1)}) {
        b.init();b.put(0x200,n);b.cmd(0xdf,0x28,0x200);b.expect(static_cast<long double>(n),"FILD64");
        b.cmd(0xdf,0x38,0x300);require(b.get<int64_t>(0x300)==n,"FISTP64");
    }
    for(double n:{0.0,-0.0,1.0,-1.25,1e-300,1e300,std::numeric_limits<double>::denorm_min()}) {
        b.init();b.put(0x200,n);b.cmd(0xdd,0x00,0x200);b.expect(n,"FLD64");
        b.cmd(0xdd,0x18,0x300);double got=b.get<double>(0x300);require(std::memcmp(&got,&n,8)==0,"FSTP64 exact");
    }
    for(float n:{0.0f,-0.0f,1.0f,-1.25f,1e-30f,1e30f,std::numeric_limits<float>::denorm_min()}) {
        b.init();b.put(0x200,n);b.cmd(0xd9,0x00,0x200);b.expect(n,"FLD32");
        b.cmd(0xd9,0x18,0x300);float got=b.get<float>(0x300);require(std::memcmp(&got,&n,4)==0,"FSTP32 exact");
    }
    for(int64_t n:{INT64_C(123456789012345678),INT64_C(-999999999999999999),INT64_C(0)}) {
        uint64_t mag=n<0?uint64_t(-n):uint64_t(n);Ext v{};
        for(int i=0;i<18;++i){v[i/2]|=uint8_t((mag%10)<<((i%2)*4));mag/=10;}v[9]=n<0?0x80:0;
        std::memcpy(b.mem.data()+0x200,v.data(),10);b.init();b.cmd(0xdf,0x20,0x200);b.expect(static_cast<long double>(n),"FBLD");
        b.cmd(0xdf,0x30,0x300);require(std::memcmp(b.mem.data()+0x300,v.data(),10)==0,"FBSTP");
    }
    b.init();b.load(1);b.cmd(0xdb,0x38,0xffffb);
    Ext one=bits(1);for(unsigned i=0;i<10;++i)require(b.mem[(0xffffb+i)&0xfffff]==one[i],"physical address wrap");
    b.init();b.load(7);b.load(9);b.cw(0x0bff);
    auto regs=b.d.registers_o;uint16_t tags=b.d.tags_o;uint16_t cw=b.d.control_o,sw=b.d.status_o;
    b.cmd(0xdd,0x30,0x500);require(b.d.tags_o==0xffff&&b.d.control_o==0x03ff,"FSAVE initializes");
    b.cmd(0xdd,0x20,0x500);require(b.d.registers_o==regs&&b.d.tags_o==tags&&b.d.control_o==cw,"FRSTOR exact image");
    require((b.d.status_o&0x7fff)==(sw&0x7fff),"FRSTOR status");
    b.cmd(0xd9,0x30,0x600);require((b.d.control_o&0x3f)==0x3f,"FSTENV masks exceptions");
    require(b.get<uint16_t>(0x600)==cw,"FSTENV original CW");
    b.cmd(0xd9,0x20,0x600);require(b.d.control_o==cw,"FLDENV restores CW");
    for(unsigned rc=0;rc<4;++rc) for(long double n:{-2.5L,-1.5L,-0.5L,0.5L,1.5L,2.5L}) {
        uint16_t c=uint16_t(0x13ff|(rc<<10));
        b.init();b.cw(c);b.load(n);b.cmd(0xdf,0x18,0x300);
        require(b.get<int16_t>(0x300)==int16_t(oracle_round(n,c)),"FIST16 independent tie rounding");
        for(int sign:{-1,1}) {
            long double x=sign*(1.0L+std::ldexp(1.0L,-24));
            b.init();b.cw(c);b.load(x);b.cmd(0xd9,0x18,0x300);
            require(b.get<float>(0x300)==oracle_single(x,c),"FST32 independent halfway rounding");
        }
    }
    b.init();b.load(11);auto old_tags=b.d.tags_o;
    b.d.opcode_i=0xdd;b.d.modrm_i=0x30;b.d.address_i=0x800;b.d.cmd_valid_i=1;
    b.tick();b.d.cmd_valid_i=0;b.force_stall=true;b.tick();b.tick();
    require(b.d.mem_valid_o&&b.d.tags_o==old_tags,"FSAVE does not initialize before final write");
    unsigned old_writes=b.writes;b.d.rst_n=0;b.tick();
    require(!b.d.mem_valid_o&&b.writes==old_writes,"reset aborts stalled write");
    b.d.rst_n=1;b.force_stall=false;b.tick();
    require(b.d.tags_o==0xffff&&b.d.control_o==0x03ff,"reset during memory transfer");
    std::cout<<"PASS numeric formats, memory stalls, wrap and save/restore\n";
}

static void arithmetic(Bench &b) {
    std::mt19937_64 rng(0x80871980);
    for(unsigned pc:{0u,2u,3u}) for(unsigned rc=0;rc<4;++rc) for(unsigned n=0;n<160;++n) {
        long double a=std::ldexp(static_cast<long double>(int64_t(rng())),int(rng()%160)-80);
        long double c=std::ldexp(static_cast<long double>(int64_t(rng())),int(rng()%160)-80);
        for(int op:{0,1,4,6}) {
            uint16_t cw=uint16_t(0x10ff|(pc<<8)|(rc<<10));
            b.init();b.cw(cw);b.load(c);b.load(a);b.cmd(0xd8,uint8_t(0xc1|(op<<3)));
            b.expect(oracle(a,c,op,cw),"independent x87 arithmetic pc="+std::to_string(pc)+" rc="+std::to_string(rc)+" op="+std::to_string(op));
        }
    }
    std::cout<<"PASS 7680 independent x87 arithmetic cases across PC/RC modes\n";
}

static Ext encoded(uint16_t se,uint64_t mant) {
    Ext v{};std::memcpy(v.data(),&mant,8);std::memcpy(v.data()+8,&se,2);return v;
}
static void extremes(Bench &b) {
    for(unsigned rc=0;rc<4;++rc) {
        b.init();b.cw(uint16_t(0x13ff|(rc<<10)));
        b.load_bits(encoded(0x7ffe,0xffffffffffffffffULL));b.load(2);b.cmd(0xde,0xc9);
        require((b.d.status_o&0x28)==0x28,"masked overflow OE/PE");
        if(rc==1) require(b.top_bits()==encoded(0x7ffe,0xffffffffffffffffULL),"directed overflow finite");
        else require(std::isinf(b.top()),"original chop/nearest/up overflow infinity");
    }
    b.init();b.cw(0x13f7);b.load_bits(encoded(0x7ffe,0x8000000000000000ULL));b.load(2);b.cmd(0xde,0xc9);
    require(b.top_bits()==encoded(0x1fff,0x8000000000000000ULL),"unmasked overflow exponent wrapping");
    require((b.d.status_o&0x88)==0x88,"overflow IR status");
    b.init();b.cw(0x13ef);b.load_bits(encoded(1,0x8000000000000000ULL));b.load(0.5L);b.cmd(0xde,0xc9);
    require(b.top_bits()==encoded(0x6000,0x8000000000000000ULL),"unmasked underflow exponent wrapping");
    b.init();b.load_bits(encoded(1,0x8000000000000000ULL));b.load(0.5L);b.cmd(0xde,0xc9);
    require(b.top_bits()==encoded(0,0x4000000000000000ULL),"masked gradual exact underflow");
    require((b.d.status_o&0x10)!=0,"original exact underflow flag");
    b.init();b.cw(0x13df);b.load(3);b.load(1);b.cmd(0xde,0xf1);
    b.expect(oracle(1,3,6,0x13ff),"precision trap retires rounded register result");
    require((b.d.status_o&0xa0)==0xa0,"precision trap pending");
    b.init();b.cw(0x13f7);b.load(std::ldexp(1.0L,200));unsigned writes=b.writes;auto original=b.top_bits();
    b.cmd(0xd9,0x18,0x700);require(b.writes==writes&&b.top_bits()==original,"unmasked store overflow suppresses memory/pop");
    b.init();b.cw(0x13df);b.load(1.0L+std::ldexp(1.0L,-30));writes=b.writes;
    b.cmd(0xd9,0x18,0x700);require(b.writes==writes+4&&b.get<float>(0x700)==1.0f,"precision store trap retires rounded memory/pop");
    b.init();b.load_bits(encoded(0x7fff,0xc000000000000001ULL));b.load_bits(encoded(0xffff,0xd000000000000002ULL));b.cmd(0xd8,0xc1);
    require(b.top_bits()==encoded(0xffff,0xd000000000000002ULL)&&(b.d.status_o&1),"original larger-payload NaN propagation and IE");
    b.init();b.load_bits(encoded(0x4000,0x4000000000000000ULL));b.load(1);b.cmd(0xde,0xc1);b.expect(2,"8087 unnormal arithmetic operand");
    for(unsigned i=0;i<180;++i) {
        long double x=std::ldexp(1.0L+static_cast<long double>(i)/181,int(i)-90);
        b.init();b.cw(0x13ff);b.load(x);b.cmd(0xd9,0xfa);b.expect(std::sqrt(x),"independent FSQRT");
    }
    std::cout<<"PASS extreme exponents, original trap retirement, NaNs and 180 independent square roots\n";
}

// Intel July 1980 supplement, figure S-24, printed S-64--S-66:
// original ARRSUM numeric instruction sequence, executed in original reverse
// array order with the CPU's loop/index operations provided by this harness.
static void manufacturer_software(Bench &b) {
    b.init();b.cw(0x033e);for(int i=0;i<3;++i)b.cmd(0xd9,0xee);
    const std::array<float,8> xs={1,-2,3.5f,4,-5.25f,6,7.5f,8};
    for(unsigned i=0;i<xs.size();++i)b.put(0x1000+i*4,xs[i]);
    for(unsigned n=unsigned(xs.size());n>0;--n) {
        b.put<uint16_t>(0x900,uint16_t(n));
        b.cmd(0xd9,0x84,0x1000+(n-1)*4); // FLD X_ARRAY[SI]
        b.cmd(0xdc,0xc3);                // FADD ST(3),ST
        b.cmd(0xd9,0xc0);                // FLD ST
        b.cmd(0xdc,0xc8);                // FMUL ST,ST
        b.cmd(0xde,0xc2);                // FADDP ST(2),ST
        b.cmd(0xde,0x08,0x900);          // FIMUL N_OF_X
        b.cmd(0xde,0xc2);                // FADDP ST(2),ST
    }
    b.cmd(0xd9,0x18,0xa00);b.cmd(0xd9,0x18,0xa04);b.cmd(0xd9,0x18,0xa08);
    long double sum=0,squares=0,indexes=0;
    for(unsigned i=0;i<xs.size();++i){sum+=xs[i];squares+=static_cast<long double>(xs[i])*xs[i];indexes+=(i+1)*static_cast<long double>(xs[i]);}
    require(b.get<float>(0xa00)==float(squares),"Intel ARRSUM sum squares");
    require(b.get<float>(0xa04)==float(indexes),"Intel ARRSUM index-weighted sum");
    require(b.get<float>(0xa08)==float(sum),"Intel ARRSUM sum");
    require(b.d.tags_o==0xffff,"Intel ARRSUM stack balance");
    std::cout<<"PASS original Intel ARRSUM numeric software (figure S-24)\n";
}

static void transcendental(Bench &b) {
    for(unsigned i=1;i<=12;++i) {
        long double x=static_cast<long double>(i)/32;
        auto close=[&](long double wanted,const std::string &name) {
            long double err=std::fabs(b.top()-wanted);
            require(err<=std::fabs(wanted)*4e-18L+1e-25L,name+" numerical error");
        };
        b.init();b.load(x);b.cmd(0xd9,0xf0);close(std::expm1(x*std::log(2.0L)),"F2XM1");
        b.init();b.load(x);b.cmd(0xd9,0xf2);b.expect(1,"FPTAN X ratio");b.cmd(0xdd,0xd8);close(std::tan(x),"FPTAN");
        b.init();b.load(x);b.load(1);b.cmd(0xd9,0xf3);close(std::atan(x),"FPATAN");
        b.init();b.load(3);b.load(1+x);b.cmd(0xd9,0xf1);close(3*std::log2(1+x),"FYL2X");
        if(x<0.29L) {b.init();b.load(3);b.load(x);b.cmd(0xd9,0xf9);close(3*std::log1p(x)/std::log(2.0L),"FYL2XP1");}
    }
    std::cout<<"PASS reduced-domain transcendental accuracy samples (4e-18 relative tolerance)\n";
}
int main(int argc,char **argv) {
    Verilated::commandArgs(argc,argv);
    try {
        Bench b;
        architecture(b);formats(b);arithmetic(b);extremes(b);manufacturer_software(b);transcendental(b);
        std::cout<<"PASS Intel 8087: "<<checks<<" checks, "<<b.cycles<<" cycles, "<<b.reads<<" reads, "<<b.writes<<" writes\n";
    } catch(const std::exception &e) {std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}
}
