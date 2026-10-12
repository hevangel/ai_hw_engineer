#include "Vintel_8086_chip.h"
#include "Vintel_8086_chip___024root.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>
using Registers=std::array<uint16_t,14>;
static uint32_t physical(uint16_t s,uint16_t o){return ((uint32_t(s)<<4)+o)&0xfffff;}
static void require(bool condition,const std::string &message){if(!condition)throw std::runtime_error(message);}
class Bench {
public:
    Vintel_8086_chip dut;
    std::vector<uint8_t> memory=std::vector<uint8_t>(1<<20),ports=std::vector<uint8_t>(65536);
    uint64_t cycles=0;
    unsigned acknowledgements=0, waits=0, code_reads=0, write_count=0, grant0=0,grant1=0;
    std::unordered_map<uint32_t,uint8_t> writes;
    std::vector<std::pair<uint32_t,uint8_t>> ordered_writes;
    std::vector<uint32_t> touched;
    bool saw_fetch=false;
    uint32_t first_fetch_address=0,fetch_address=0;
    uint8_t first_fetch_byte=0,fetch_byte=0;
    unsigned qs_seen=0;
    uint32_t address=0;
    uint8_t lanes=0,status=7,external_rqgt=3;
    bool min_mode=true,random_wait=true;
    bool ready_at_t2=true;
    bool vector_mode=false,vector_instruction_done=false;
    std::unordered_map<uint32_t,uint8_t> fixture_code;
    void set(uint32_t a,uint8_t v){a&=0xfffff;memory[a]=v;touched.push_back(a);}
    bool request(){return dut.rootp->intel_8086_chip__DOT__req;}
    void tick(bool stall=false){
        dut.clk=0;dut.ready_i=!stall && (!random_wait || cycles%11>=3);
        dut.rqgt_n_i=external_rqgt & (dut.rqgt_n_o|(~dut.rqgt_oe_o&3));dut.eval();
        const auto phase=dut.phase_o;
        if(phase==1 && !dut.reset_i){
            require(bool(dut.ad_oe_o)==(dut.status_o!=0) && dut.address_status_oe_o,"T1 address/INTA float");
            address=(uint32_t(dut.address_status_o)<<16)|dut.ad_o;
            lanes=(!(address&1) ? 1:0)|(!dut.bhe_status_n_o ? 2:0);status=dut.status_o;
            require(lanes!=0,"native no active byte lane");
            if(status==0 && acknowledgements==0)require(!dut.bhe_status_n_o,"first INTA BHE must be low");
        }
        auto aligned=address&0xffffe;
        dut.ad_i=status==0 ? 0x20 : status<=2 ? ports[aligned&65535]|uint16_t(ports[(aligned+1)&65535])<<8 :
            memory[aligned]|uint16_t(memory[(aligned+1)&0xfffff])<<8;
        // Match the upstream hardware harness: CODE fetches beyond the
        // instruction are 90h even when data RAM at that address differs.
        // Ordinary native/software tests use unified RAM and exercise real SMC.
        if(vector_mode && status==4){
            dut.ad_i=0;
            for(unsigned lane=0;lane<2;++lane){auto a=(aligned+lane)&0xfffff;
                auto v=!vector_instruction_done && fixture_code.count(a) ? fixture_code[a]:0x90;
                dut.ad_i|=uint16_t(v)<<(lane*8);
            }
        }
        dut.eval();
        if(phase==2)ready_at_t2=dut.ready_i;
        if(!dut.reset_i){
            if(dut.control_oe_o && (phase==1 || phase==2 || phase==3 && !ready_at_t2 || phase==4 && !dut.ready_i))
                require(dut.status_o==status,"active cycle status lost during READY wait");
            if(dut.hlda_o) require(!dut.ad_oe_o && !dut.address_status_oe_o && !dut.control_oe_o && !dut.bhe_oe_o,"HOLD pins did not float");
            if(phase>=2 && phase<=4 && dut.control_oe_o){
                const bool writing=status==2 || status==6;
                require(bool(dut.ad_oe_o)==writing,"native data direction");
                require(bool(dut.rd_n_o)==(writing || status==0),"native RD phase");
                if(min_mode){
                    require(!dut.den_n_o && bool(dut.wr_n_o)==!writing && bool(dut.inta_n_o)==(status!=0),"minimum control phase");
                }
            }
            if(phase==5 && dut.control_oe_o){
                require(bool(dut.ad_oe_o)==(status==2 || status==6),"T4 write-data hold");
                if(min_mode)require(!dut.den_n_o,"T4 data-enable hold");
            }
            require(bool(dut.ale_o)==(min_mode && phase==1 && dut.control_oe_o),"ALE timing/mode");
            if(!min_mode) require(dut.wr_n_o && dut.den_n_o && dut.inta_n_o,"minimum controls active in maximum mode");
        }
        const auto write_data=dut.ad_o;
        auto *root=dut.rootp;
        if(root->intel_8086_chip__DOT__req && root->intel_8086_chip__DOT__fetching && root->intel_8086_chip__DOT__core_ready){
            fetch_address=root->intel_8086_chip__DOT__address+(root->intel_8086_chip__DOT__be==2);
            fetch_byte=uint8_t(root->intel_8086_chip__DOT__read_data >> (root->intel_8086_chip__DOT__be==2 ? 8:0));
            if(!saw_fetch){first_fetch_address=fetch_address;first_fetch_byte=fetch_byte;saw_fetch=true;}
        }
        dut.clk=1;dut.eval();++cycles;
        if(dut.retire_o)vector_instruction_done=true;
        qs_seen|=1<<dut.qs_o;
        if(phase==4)++waits;
        if(dut.rqgt_oe_o&1)++grant0;
        if(dut.rqgt_oe_o&2)++grant1;
        if(!dut.reset_i && (phase==3 || phase==4) && dut.phase_o==5){
            if(status==4){require(acknowledgements!=1,"CODE cycle split interrupt acknowledges");++code_reads;}
            if(status==0)++acknowledgements;
            if(status==2 || status==6){
                for(unsigned lane=0;lane<2;++lane)if(lanes&(1<<lane)){
                    if(status==2)ports[(aligned+lane)&65535]=uint8_t(write_data>>(lane*8));
                    else {set(aligned+lane,uint8_t(write_data>>(lane*8)));writes[(aligned+lane)&0xfffff]=uint8_t(write_data>>(lane*8));}
                    ordered_writes.emplace_back(((aligned+lane)&0xfffff)|(status==2 ? 1<<20:0),uint8_t(write_data>>(lane*8)));
                    ++write_count;
                }
            }
        }
        require(dut.queue_count_o<=6,"prefetch overflow");
        require(!dut.fault_o || dut.reset_i,"native unexpected decode fault at IP="+std::to_string(dut.ip_o));
    }
    void reset(){
        for(auto a:touched)memory[a]=0;touched.clear();std::fill(ports.begin(),ports.end(),255);
        cycles=0;acknowledgements=waits=code_reads=write_count=grant0=grant1=qs_seen=0;
        writes.clear();ordered_writes.clear();saw_fetch=false;
        vector_mode=false;vector_instruction_done=false;fixture_code.clear();
        external_rqgt=3;dut.intr_i=0;dut.nmi_i=0;dut.hold_i=0;dut.test_n_i=0;
        dut.min_mode_i=min_mode;dut.reset_i=1;tick();tick();dut.reset_i=0;
    }
    Registers read(){
        Registers r{};for(unsigned i=0;i<8;++i)r[i]=(dut.regs_o[i/2]>>(16*(i%2)))&65535;
        for(unsigned i=0;i<4;++i)r[8+i]=(dut.segs_o>>(16*i))&65535;
        r[12]=dut.ip_o;r[13]=dut.flags_o;return r;
    }
    void host_registers(const Registers &r){
        for(unsigned i=0;i<8;++i)dut.rootp->intel_8086_chip__DOT__eu__DOT__gpr[i]=r[i];
        for(unsigned i=0;i<4;++i)dut.rootp->intel_8086_chip__DOT__eu__DOT__seg[i]=r[8+i];
        dut.eval();
    }
    void load(const Registers &r){
        host_registers(r);auto *root=dut.rootp;
        root->intel_8086_chip__DOT__eu__DOT__ip=r[12];root->intel_8086_chip__DOT__eu__DOT__flags=r[13];
        root->intel_8086_chip__DOT__biu__DOT__queue_cs=r[9];
        root->intel_8086_chip__DOT__biu__DOT__head_ip=r[12];root->intel_8086_chip__DOT__biu__DOT__fetch_ip=r[12];dut.eval();
    }
    void seed_queue(const std::vector<std::pair<uint32_t,uint8_t>> &bytes){
        auto *root=dut.rootp;unsigned length=0;vector_mode=true;
        for(auto [i,v]:bytes){if(i&(1<<20))fixture_code[i&0xfffff]=v;
            else {require(i<6,"physical initial queue length");root->intel_8086_chip__DOT__biu__DOT__queue[i]=v;++length;}}
        root->intel_8086_chip__DOT__biu__DOT__count=length;
        root->intel_8086_chip__DOT__biu__DOT__tail=length%6;
        root->intel_8086_chip__DOT__biu__DOT__fetch_ip=uint16_t(dut.ip_o+length);dut.eval();
    }
    void retire(){
        saw_fetch=false;
        for(unsigned i=0;i<100000;++i){tick();if(dut.retire_o)return;}
        throw std::runtime_error("native retirement watchdog at IP="+std::to_string(dut.ip_o)+
            " phase="+std::to_string(dut.phase_o)+" queue="+std::to_string(dut.queue_count_o));
    }
    void boot(std::initializer_list<uint8_t> code){
        reset();const uint8_t jump[]={0xea,0,0,0,0x10};
        for(unsigned i=0;i<5;++i)set(0xffff0+i,jump[i]);
        unsigned a=0x10000;for(auto c:code)set(a++,c);
        retire();require(dut.ip_o==0 && read()[9]==0x1000,"native reset far jump");
    }
    void step(uint16_t ip){retire();require(dut.ip_o==ip,"native exact IP actual="+std::to_string(dut.ip_o)+" expected="+std::to_string(ip));}
};
#include "tb_dos.hpp"
#include "tb_vectors_common.hpp"
static void native_tests(Bench &b){
    unsigned cases=0;
    for(bool mode:{true,false}){
        b.min_mode=mode;
        b.boot({0xb8,0,0x20,0x8e,0xd8,0xb8,0x34,0x12,0xa3,0xff,0xff,
                0xb8,0,0,0xa1,0xff,0xff,0xe7,0x21,0xe5,0x21,0xf4});
        for(auto ip:{3,5,8,11,14,17,19})b.step(ip);
        require(b.memory[0x2ffff]==0x34 && b.memory[0x20000]==0x12,"native odd word segment wrap");
        require(b.ports[0x21]==0x34 && b.ports[0x22]==0x12,"native odd word I/O write");
        b.ports[0x21]=0xa5;b.ports[0x22]=0x5a;b.step(21);
        require(b.read()[0]==0x5aa5,"native odd word I/O read");b.step(22);
        require(b.dut.halted_o && b.waits && (b.qs_seen&14)==14,"native HLT/wait/QS coverage");++cases;
        // A busy WAIT permits the six-byte queue to fill. Changing RAM does
        // not change queued bytes; a taken jump flushes and exposes the change.
        b.boot({0x90,0x9b,0x90,0xeb,0xfd,0x90,0x90,0x90,0x90});b.step(1);b.dut.test_n_i=1;
        for(unsigned i=0;i<200 && b.dut.queue_count_o!=6;++i)b.tick();
        require(b.dut.queue_count_o==6,"six-byte queue did not fill");
        b.set(0x10002,0xf4);b.dut.test_n_i=0;b.step(2);b.step(3);
        require(!b.dut.halted_o,"self-modifying RAM invalidated queued instruction");
        b.step(2);b.step(3);require(b.dut.halted_o,"jump failed to flush stale prefetch");++cases;
        // Two INTA bus cycles, interrupt vector entry and IRET through pins.
        b.boot({0xbc,0,0x80,0xfb,0x90,0xf4});
        b.set(0x80,0);b.set(0x81,4);b.set(0x82,0);b.set(0x83,0);
        b.set(0x400,0x43);b.set(0x401,0xcf);
        b.step(3);b.step(4);b.dut.intr_i=1;b.step(5);
        for(unsigned i=0;i<1000 && !(b.read()[9]==0 && b.dut.ip_o==0x400);++i)b.tick();
        require(b.acknowledgements==2 && b.read()[4]==0x7ffa && b.memory[0x7ffa]==5,"native IRQ entry");
        b.dut.intr_i=0;b.step(0x401);b.step(5);b.step(6);++cases;
        // LOCK prevents an arbiter from splitting a read/modify/write cycle.
        b.boot({0xf0,0xff,0x06,0,0x20,0x90,0xf4});
        for(unsigned i=0;i<500 && !(b.dut.phase_o==2 && b.status==5);++i)b.tick();
        if(mode)b.dut.hold_i=1;else b.external_rqgt=2;
        for(unsigned i=0;i<500 && !b.dut.retire_o;++i){b.tick();require(mode ? !b.dut.hlda_o:b.grant0==0,"native grant split LOCK");}
        require(b.memory[0x2000]==1,"native locked INC");
        if(!mode)b.external_rqgt=3;
        for(unsigned i=0;i<100 && b.dut.control_oe_o;++i)b.tick();
        require(!b.dut.control_oe_o && (mode ? b.dut.hlda_o:b.grant0==1),"native arbitration grant");
        for(unsigned i=0;i<20;++i){b.tick();require(!b.dut.ad_oe_o,"bus driven while granted");}
        if(mode)b.dut.hold_i=0;else b.external_rqgt=2;
        b.tick();b.external_rqgt=3;
        for(unsigned i=0;i<100 && !b.dut.control_oe_o;++i)b.tick();
        require(b.dut.control_oe_o,"native arbitration release");++cases;
        // Datasheet RQ/GT rule 2 also protects an unlocked odd-address word.
        b.boot({0xb8,0x34,0x12,0xa3,1,0x20,0x90,0xf4});b.step(3);
        for(unsigned i=0;i<500 && !(b.dut.phase_o==2 && b.status==6);++i)b.tick();
        require(b.address==0x2001,"odd-word arbitration stimulus");
        if(mode)b.dut.hold_i=1;else b.external_rqgt=2;
        for(unsigned i=0;i<500 && b.write_count<2;++i){
            b.tick();require(mode ? !b.dut.hlda_o:b.grant0==0,"grant split unlocked odd word");
            require(b.dut.lock_n_o,"odd-word protection incorrectly asserted LOCK");
            if(b.write_count==1)require(!(b.dut.phase_o==1 && b.dut.status_o==4),"prefetch split odd word");
        }
        require(b.memory[0x2001]==0x34 && b.memory[0x2002]==0x12,"odd word incomplete before grant");
        if(!mode)b.external_rqgt=3;
        for(unsigned i=0;i<100 && b.dut.control_oe_o;++i)b.tick();
        require(!b.dut.control_oe_o,"odd-word pending request lost");++cases;
        // A request arriving after T2 must not release the active cycle in T4.
        b.random_wait=false;b.boot({0x9b,0x90,0xf4});b.dut.test_n_i=1;
        for(unsigned i=0;i<500 && b.dut.phase_o!=3;++i)b.tick();
        require(b.dut.phase_o==3,"late arbitration stimulus");
        if(mode)b.dut.hold_i=1;else b.external_rqgt=2;
        b.tick();require(b.dut.phase_o==5 && b.dut.control_oe_o,"late request grant before T4");
        b.tick();require(b.dut.control_oe_o,"late request incorrectly granted in T4");
        b.tick();require(!b.dut.control_oe_o,"idle pending request not granted");
        b.random_wait=true;++cases;
        // A request at reset release wins before the reset-vector fetch.
        b.reset();if(mode)b.dut.hold_i=1;else b.external_rqgt=2;b.tick();
        require(!b.dut.control_oe_o && b.code_reads==0,"reset-release request priority");++cases;
        // Reset must abort each possible active phase without a late write.
        for(unsigned target:{1,2,3,4,5}){
            b.boot({0xb8,0x55,0xaa,0xa3,0,0x20,0xf4});b.step(3);
            auto target_cycle=[&](){return b.dut.phase_o==target && (target==1 ? b.dut.status_o:b.status)==6;};
            for(unsigned i=0;i<1000 && !target_cycle();++i)b.tick(target==4 && b.status==6);
            require(target_cycle(),"reset-phase coverage target="+std::to_string(target));
            auto writes=b.write_count;b.dut.reset_i=1;b.tick();
            require(b.dut.phase_o==0 && b.dut.queue_count_o==0 && b.dut.ip_o==0 && b.read()[9]==0xffff,"native reset state");
            require(b.write_count==writes,"reset accepted an aborted write");++cases;
        }
    }
    // Maximum-mode RQ/GT0 has priority; a queued RQ/GT1 is granted after release.
    b.min_mode=false;b.boot({0x9b,0x90,0xf4});b.dut.test_n_i=1;b.external_rqgt=0;b.tick();b.external_rqgt=3;
    for(unsigned i=0;i<100 && b.grant0==0;++i)b.tick();
    require(b.grant0==1 && b.grant1==0,"RQ/GT priority");
    b.tick();b.tick();b.external_rqgt=2;b.tick();b.external_rqgt=3;
    for(unsigned i=0;i<100 && b.grant1==0;++i)b.tick();
    require(b.grant1==1,"pending lower-priority RQ/GT lost");++cases;
    std::cout<<"PASS: "<<cases<<" native minimum/maximum-mode bus, prefetch, arbitration and reset scenarios\n";
}
int main(int argc,char **argv){
    Verilated::commandArgs(argc,argv);
    try{
        Bench b;
        if(std::getenv("I8086_NATIVE_MAX"))b.min_mode=false;
        if(argc==3 && std::string(argv[1])=="--debug"){
            for(bool mode:{true,false}){b.min_mode=mode;debug_software(b,argv[2]);}
        }else if(argc==3 && std::string(argv[1])=="--vectors")vectors(b,argv[2]);
        else native_tests(b);
        b.dut.final();
    }catch(const std::exception &e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}
}
