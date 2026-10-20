#include "board_driver.h"
#include <chrono>
#include <thread>
#if VM_COVERAGE
#include "verilated_cov.h"
#endif
extern "C" int panel_cycle(int,int,int,int,int,int,int,int,int,int,int);
extern "C" void panel_wave(int,int,int,int,int,int,int,int);
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);BoardDriver board;
    if(argc>1&&std::string(argv[1])=="--serve") {
        unsigned reset_ticks=0;
        while(true) {
            for(unsigned tick=0;tick<4096;tick++) {
                if(board.tick()) {
                    auto&d=board.dut;
                    int code=panel_cycle(board.last_addr,board.last_write,d.pc,d.video_visible,d.video_main,d.video_aux,d.video_graphics,d.video_line,d.video_font_main,d.video_font_aux,d.video_80col);
                    d.key_data=code&127;d.key_down=(code>>7)&1;
                    if(code&256){d.rst_n=0;reset_ticks=56;board.scan_sample=0;}
                }
                auto&d=board.dut;
                panel_wave(d.phi0,d.q3,d.pras_n,d.pcas_n,d.ldps_n,d.bus_addr,d.bus_we,d.bus_data);
                if(reset_ticks&&!--reset_ticks){d.rst_n=1;d.eval();}
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
    board.run(1000000);
    board.require(board.first_fetch,"firmware first fetch observed");
    board.require(board.screen().find("Apple ][")!=std::string::npos,"original ROM startup banner");
    board.require(!board.dut.video_graphics,"ROM selected TEXT through read access");
    board.type("POKE 768,55\r");board.run(100000);

    board.require(board.memory(768)==55,"real Applesoft POKE physical main RAM");
    board.type("PRINT 6*7\r");board.run(100000);
    board.require(board.screen().find("42")!=std::string::npos,"real Applesoft arithmetic PRINT");
    // Original 80-column firmware exercises C3xx/C8xx and auxiliary text RAM.
    board.type("PR#3\r");board.run(20000);
    board.require(board.dut.video_80col,"original slot-3 firmware enabled 80 columns");
    board.type("PRINT 12345\r");board.run(100000);
    bool aux_text=false;for(unsigned a=0x400;a<0x800;a++)if(board.memory(a,true)!=0&&board.memory(a,true)!=0xa0)aux_text=true;
    board.require(aux_text,"real 80-column firmware wrote auxiliary text RAM");
    board.require(board.screen80().find("12345")!=std::string::npos,"exact 80-column PRINT readback");
    board.run(20000);board.save_frame();board.capture_wave();
    std::printf("PASS original IIe ROM: exact reset/first fetch, Apple ][, keyboard/C010, POKE 768=55, PRINT 42, PR#3 and auxiliary text; cycles=%llu fetches=%llu frames=%llu\n",(unsigned long long)board.cycles,(unsigned long long)board.fetches,(unsigned long long)board.frames);
    std::printf("%s",board.screen80().c_str());
#if VM_COVERAGE
    VerilatedCov::write("work/coverage.dat");
#endif
}
