#pragma once
#include "Vapple_iie.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>
struct BoardDriver {
    Vapple_iie dut;
    uint64_t cycles=0,fetches=0,acknowledgements=0,frames=0;
    std::array<uint8_t,7680*5> frame{},completed_frame{};
    unsigned scan_sample=0;
    bool low_vector=false,high_vector=false,first_fetch=false;
    unsigned last_addr=0,last_data=0; bool last_write=false;
    unsigned vector_pc=0;
    BoardDriver() {
        std::ifstream f("work/Apple2e.rom",std::ios::binary); std::vector<unsigned char> rom((std::istreambuf_iterator<char>(f)),{});
        require(rom.size()==16384,"original ROM size"); vector_pc=rom[0x3ffc]|(rom[0x3ffd]<<8);
        dut.clk14=0;dut.power_n=0;dut.rst_n=0;dut.key_data=0;dut.key_down=0;
        dut.external_addr=0;dut.external_data=0;dut.external_we=0;dut.debug_addr=0;dut.debug_aux=0;
        for(unsigned i=0;i<8;i++)tick(); dut.power_n=1;
        for(unsigned i=0;i<56;i++)tick(); dut.rst_n=1;dut.eval();
    }
    void require(bool ok,const char* what) {
        if(!ok) {std::fprintf(stderr,"FAIL %s PC=%04x address=%04x cycles=%llu\n",what,dut.pc,dut.bus_addr,(unsigned long long)cycles);std::exit(1);}
    }
    bool tick() {
        dut.clk14=0;dut.eval(); bool previous=dut.bus_clk;
        unsigned a=dut.bus_addr,d=dut.bus_data; bool write=dut.bus_we,f=dut.fetch;
        dut.clk14=1;dut.eval(); bool edge=dut.rst_n && !previous && dut.bus_clk;
        if(edge) {
            ++cycles; last_addr=a;last_data=d;last_write=write;
            if((!write && a==0xc010) || (write && a>=0xc010 && a<=0xc01f)) ++acknowledgements;
            if(!write && a==0xfffc && !first_fetch) {require(d==(vector_pc&255),"exact reset vector low");low_vector=true;}
            if(!write && a==0xfffd && !first_fetch) {require(d==(vector_pc>>8),"exact reset vector high");high_vector=true;}
            if(f) {
                ++fetches;
                if(!first_fetch) {require(low_vector&&high_vector&&a==vector_pc,"exact first firmware fetch");first_fetch=true;}
            }
            if(dut.video_visible) {
                auto i=scan_sample*5;
                frame[i]=dut.video_main;frame[i+1]=dut.video_aux;
                frame[i+2]=dut.video_graphics;frame[i+3]=dut.video_line|(dut.video_font_main<<3);frame[i+4]=dut.video_80col|(dut.video_font_aux<<1);
                if(++scan_sample==7680) {scan_sample=0;completed_frame=frame;++frames;}
            }
        }
        if(dut.rst_n)require(!dut.fault,"undocumented firmware opcode");
        dut.clk14=0;dut.eval(); return edge;
    }
    void run(uint64_t n) {uint64_t end=cycles+n;while(cycles<end)tick();}
    unsigned memory(unsigned a,bool aux=false) {dut.debug_addr=a;dut.debug_aux=aux;dut.eval();return dut.debug_data;}
    std::string screen() {
        std::string s;
        for(unsigned row=0;row<24;row++) {for(unsigned col=0;col<40;col++) {
            unsigned c=memory(0x400+(row%8)*128+(row/8)*40+col)&127;s+=char(c<32?c+64:c);
        }s+='\n';}return s;
    }
    void key(unsigned c) {
        uint64_t ready_deadline=cycles+1000000;
        while((last_addr!=0xc000||last_write)&&cycles<ready_deadline)tick();
        require(last_addr==0xc000&&!last_write,"firmware keyboard-ready poll");
        auto before=acknowledgements;dut.key_data=c;dut.key_down=1;run(5);
        uint64_t end=cycles+1000000;while(acknowledgements==before&&cycles<end)tick();
        if(acknowledgements==before) std::fprintf(stderr,"KEY=%02x down=%u pending=%u busdata=%02x screen=\n%s\n",c,dut.key_down,dut.keyboard_pending,dut.bus_data,screen().c_str());
        require(acknowledgements>before,"keyboard C010 acknowledgement");dut.key_down=0;run(80);
    }
    void type(const std::string& text) {for(unsigned char c:text){key(c);if(c==13)run(20000);}}

    std::string screen80() {
        std::string s;
        for(unsigned row=0;row<24;row++){for(unsigned col=0;col<40;col++){
            unsigned a=0x400+(row%8)*128+(row/8)*40+col;
            for(bool aux:{true,false}) {unsigned c=memory(a,aux)&127;s+=char(c<32?c+64:c);}
        }s+='\n';}return s;
    }
    void capture_wave() {
        std::ofstream f("work/wave.tmp");f<<"[";
        for(unsigned i=0;i<140;i++) {tick();if(i)f<<",";
            f<<"["<<unsigned(dut.phi0)<<","<<unsigned(dut.q3)<<","<<unsigned(dut.pras_n)<<","<<unsigned(dut.pcas_n)<<","<<unsigned(dut.ldps_n)<<","<<dut.bus_addr<<","<<unsigned(dut.bus_we)<<","<<unsigned(dut.bus_data)<<"]";
        }f<<"]";f.close();require(std::rename("work/wave.tmp","work/wave.json")==0,"wave publication");
    }
    void save_frame() {
        std::ofstream f("work/frame.tmp",std::ios::binary);f.write((char*)completed_frame.data(),completed_frame.size());f.close();
        require(std::rename("work/frame.tmp","work/frame.bin")==0,"atomic frame publication");
        std::ofstream m("work/state.tmp");m<<"{\"cycles\":"<<cycles<<",\"frames\":"<<frames<<",\"pc\":"<<dut.pc<<",\"fault\":"<<unsigned(dut.fault)<<"}";m.close();
        require(std::rename("work/state.tmp","work/state.json")==0,"atomic state publication");
    }
};
