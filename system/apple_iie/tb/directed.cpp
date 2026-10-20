#include "board_driver.h"
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv); BoardDriver b; b.run(1);
    auto access=[&](unsigned a,bool write=false,unsigned data=0){b.dut.external_addr=a;b.dut.external_we=write;b.dut.external_data=data;b.run(1);return b.last_data;};
    auto wr=[&](unsigned a,unsigned d=0){access(a,true,d);};
    wr(0x2000,0xa5);b.require(access(0x2000)==0xa5,"main RAM");
    wr(0xc005);wr(0x2000,0x5a);wr(0xc004);b.require(access(0x2000)==0xa5,"RAMWRT leaves main intact");
    wr(0xc003);b.require(access(0x2000)==0x5a,"RAMRD selects auxiliary");wr(0xc002);
    wr(0xc009);wr(0x10,0x6e);b.require(access(0x10)==0x6e,"ALTZP auxiliary zero page");wr(0xc008);b.require(access(0x10)==0,"ALTZP main zero page");
    wr(0xd000,0x21);b.require(b.memory(0xd000)==0x21,"reset bank2 write-enable");
    access(0xc08b);access(0xc08b);wr(0xd000,0x32);b.require(access(0xd000)==0x32&&b.memory(0xc000)==0x32,"language-card bank1 RA remap");
    access(0xc083);access(0xc083);b.require(access(0xd000)==0x21,"language-card bank2 retained");
    access(0xc082);wr(0xd000,0x99);b.require(b.memory(0xd000)==0x21,"language-card write protect");
    wr(0xc001);access(0xc055);wr(0x400,0x66);b.require(b.memory(0x400,true)==0x66,"80STORE read PAGE2 selects aux");
    access(0xc054);wr(0x400,0x77);b.require(b.memory(0x400)==0x77,"80STORE read PAGE1 selects main");wr(0xc000);
    b.dut.key_data='K';b.dut.key_down=1;b.run(5);b.require(access(0xc000)==('K'|128),"IOU keyboard strobe and data");
    access(0xc010);b.require(access(0xc000)=='K',"IOU C010 clears strobe");b.dut.key_down=0;b.run(5);
    access(0xc051);b.require(access(0xc01a)&128,"read TEXT switch status");
    access(0xc300);b.require(access(0xcb25)!=0xff,"internal slot3 extension");
    access(0xcfff);b.require(access(0xcb25)==0xff,"slot extension release");
    wr(0xc007);wr(0xc00b);b.require(access(0xc300)!=0xff&&access(0xcb25)!=0xff,"global internal ROM priority");wr(0xc006);wr(0xc00a);
    b.dut.external_addr=0x200; b.dut.external_we=0;
    // Wait past reset's first extended scanner frame, then start at vertical blank.
    b.run(40000);unsigned blank=0;
    while(blank<1000){b.run(1);blank=b.dut.video_visible?0:blank+1;}
    while(!b.dut.video_visible)b.run(1);
    unsigned samples=0;
    while(samples<7680){
        if(b.dut.video_visible){unsigned y=samples/40,x=samples%40;
            unsigned expected=0x400+((y/8)%8)*128+((y/8)/8)*40+x;
            b.require(b.dut.video_addr==expected,"TRM independent text scanner fold");
            b.require(b.dut.video_line==(y%8),"text character scanline");++samples;}
        if(samples<7680)b.run(1);
    }
    unsigned ticks=0;auto before=b.cycles;while(b.cycles==before){b.tick();++ticks;}
    b.require(ticks==14,"exact 14-master-tick bus cadence");
    std::printf("PASS IIe board: main/aux, ALTZP, 80STORE, language-card RA/protection, keyboard/status, Cxxx ROM, 7680 exact scanner addresses, 14-tick cadence\n");
}
