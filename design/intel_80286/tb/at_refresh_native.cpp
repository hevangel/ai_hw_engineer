#include "Vintel_80286_at_refresh_native.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

static void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        Vintel_80286_at_refresh_native d;
        std::vector<uint8_t> mem(1u<<24, 0);
        auto put=[&](uint32_t address, std::initializer_list<uint8_t> data) {
            for (auto byte:data) mem[address++]=byte;
        };
        put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        put(0xf0100,{0xb8,0x34,0x12,       // MOV AX,1234
                     0xa3,0x00,0x02,       // MOV [0200],AX
                     0xbb,0x00,0x03,       // MOV BX,0300
                     0xf0,0x87,0x07,       // LOCK XCHG [BX],AX
                     0xa3,0x02,0x02,       // MOV [0202],AX
                     0xf4});                // HLT
        mem[0x300]=0x78; mem[0x301]=0x56;
        d.clk_i=0; d.clk_2x_i=0; d.reset_i=1; d.ready_n_i=0;
        d.timer_out1_i=0; d.dma_clk_n_i=0; d.hold_permit_i=1;
        d.io_ready_i=0; d.data_i=0; d.eval();
        auto clock_step=[&]() {
            for (int n=0;n<2;++n) {
                d.clk_2x_i=1; d.clk_i=(n==0); d.eval();
                d.clk_2x_i=0; d.eval();
            }
        };
        for (int i=0;i<16;++i) clock_step();
        d.reset_i=0;
        for (int i=0;i<4;++i) clock_step();
        const bool initial_detect=d.detect_o;
        bool first_trigger=false, second_trigger=false, first_wait_hold=false;
        bool locked_hold=false, was_refresh=false, had_hlda=false;
        unsigned stall_cycles=0, refresh_cycles=0, refresh_edges=0;
        unsigned writes_200=0, writes_202=0, writes_300=0;
        for (unsigned cycles=0;cycles<5000 && !d.halted_o;++cycles) {
            d.clk_i=0; d.clk_2x_i=0; d.ready_n_i=0;
            d.eval();
            const bool perform=d.cycle_active_o && !d.status_oe_o;
            const bool first_store=perform && d.data_oe_o && d.address_o==0x200;
            if (first_store && stall_cycles<8) {
                d.ready_n_i=1;
                ++stall_cycles;
            }
            const bool locked_read=perform && !d.data_oe_o && d.address_o==0x300 && !d.lock_n_o;
            if ((first_store && !first_trigger) ||
                (locked_read && first_trigger && !second_trigger)) {
                if (first_store && !first_trigger) first_trigger=true;
                else second_trigger=true;
                // Model a timer edge followed by a distinct -DMA CLK edge.
                d.timer_out1_i=1; d.eval();
                d.dma_clk_n_i=1; d.eval();
                d.timer_out1_i=0; d.dma_clk_n_i=0; d.eval();
            }
            if (d.address_oe_o) {
                const auto addr=d.address_o & 0xfffffeu;
                d.data_i=uint16_t(mem[addr]) | (uint16_t(mem[addr+1])<<8);
            } else d.data_i=0;
            if (d.refresh_o) {
                if (!was_refresh) { ++refresh_edges; refresh_cycles=0; }
                ++refresh_cycles;
                d.io_ready_i=(refresh_cycles>=4);
            } else d.io_ready_i=0;
            was_refresh=d.refresh_o;
            d.eval();
            check(!d.protocol_error_o && !d.fault_o && !d.shutdown_o,
                  "native CPU entered a diagnostic or protocol failure");
            if (first_store && d.ready_n_i && d.hold_o) {
                first_wait_hold=true;
                check(!d.hlda_o && d.address_oe_o && d.data_oe_o && d.address_o==0x200 && d.data_o==0x1234,
                      "HOLD interrupted or changed the stalled CPU write");
            }
            if (second_trigger && d.hold_o && d.lock_oe_o && !d.lock_n_o) {
                locked_hold=true;
                check(!d.hlda_o, "CPU granted refresh during a locked transfer");
            }
            if (d.hlda_o) {
                had_hlda=true;
                check(!d.address_oe_o && !d.data_oe_o && !d.status_oe_o && !d.cycle_active_o,
                      "CPU drove bus pins during HLDA");
            }
            if (d.refresh_o)
                check(d.hlda_o && !d.refresh_n_o && !d.address_oe_o,
                      "refresh signal asserted without CPU bus grant");
            if (d.completed_bytes_o && d.data_oe_o) {
                const uint32_t address=d.address_o;
                const unsigned bytes=d.completed_bytes_o;
                if (address==0x200) ++writes_200;
                if (address==0x202) ++writes_202;
                if (address==0x300) ++writes_300;
                if (bytes==2) { mem[address]=uint8_t(d.data_o); mem[address+1]=uint8_t(d.data_o>>8); }
                else mem[address]=uint8_t((address&1) ? d.data_o>>8 : d.data_o);
            }
            clock_step();
        }
        check(d.halted_o && !d.shutdown_o && !d.fault_o,"native CPU did not reach HLT");
        check(first_trigger && second_trigger && first_wait_hold && locked_hold && had_hlda,
              "READY-wait or LOCK refresh arbitration was not exercised");
        check(refresh_edges==2 && d.detect_o==initial_detect && !d.refresh_o,
              "refresh request count or detector edges were wrong");
        check(writes_200==1 && writes_202==1 && writes_300==1,
              "CPU writes were lost or duplicated around refresh");
        check(mem[0x200]==0x34 && mem[0x201]==0x12 && mem[0x202]==0x78 &&
              mem[0x203]==0x56 && mem[0x300]==0x34 && mem[0x301]==0x12,
              "CPU memory result was wrong after refresh handoffs");
        std::cout << "PASS: native 286 HOLD/HLDA refresh path defers to READY and LOCK, preserves exact writes\n";
        d.final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
