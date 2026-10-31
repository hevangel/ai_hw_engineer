#include "Vintel_80286_at_bios_native.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

// Fixture clocks are virtual, not IBM AT physical timing.
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        if (argc != 5) throw std::runtime_error("usage: runner ROM TRACE wait half_period");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size()!=65536) throw std::runtime_error("expected 64 KiB BIOS");
        std::ofstream trace(argv[2]);
        if (!trace) throw std::runtime_error("cannot open trace");
        const bool wait=std::stoi(argv[3])!=0;
        const unsigned half=unsigned(std::stoul(argv[4]));
        if (!half) throw std::runtime_error("zero timer half-period");
        Vintel_80286_at_bios_native d;
        std::vector<uint8_t> memory(1u<<24,0), ports(1u<<16,0);
        for (size_t i=0;i<rom.size();++i) memory[0xf0000+i]=memory[0xff0000+i]=rom[i];
        uint64_t retired=0, refreshes=0, memr=0, port_reads=0;
        uint64_t dma_reads[2]={0,0}, page_reads=0, timer_reads=0;
        bool last_refresh=false, last_memr=false, bit_high=false, bit_low=false;
        bool timer1=false, timer2=false, dma1=false, dma2=false, page=false;
        uint8_t refresh_page=0; // matches the page fixture's documented reset assumption
        unsigned refresh_cycles=0;
        d.clk_i=0; d.clk_2x_i=0; d.reset_i=1; d.ready_n_i=0;
        d.dma_clk_n_i=0; d.hold_permit_i=1; d.io_ready_i=0; d.timer_clk_i=0; d.host_data_i=0;
        auto tick=[&]() {
            d.clk_i=1; d.clk_2x_i=1; d.eval();
            d.clk_2x_i=0; d.eval();
            d.clk_i=0; d.clk_2x_i=1; d.eval();
            d.clk_2x_i=0; d.eval();
        };
        d.eval();
        for (int i=0;i<16;i++) tick();
        d.reset_i=0;
        bool success=false;
        uint64_t cycles=0;
        for (;cycles<150000000;cycles++) {
            d.ready_n_i=wait ? (cycles%5!=4) : 0;
            d.dma_clk_n_i=cycles&1;
            d.timer_clk_i=((cycles/half)&1) ? 7 : 0;
            d.eval();
            if (d.refresh_o) {
                if (!last_refresh) { refreshes++; refresh_cycles=0; }
                ++refresh_cycles;
                d.io_ready_i=refresh_cycles>=3;
            } else d.io_ready_i=0;
            last_refresh=d.refresh_o;
            d.eval();
            if (d.protocol_error_o || d.fault_o || d.shutdown_o || d.halted_o)
                throw std::runtime_error("CPU stopped or rejected a beat at cycle " + std::to_string(cycles) +
                                         " after retired " + std::to_string(retired));
            if (d.hlda_o && (d.address_oe_o || d.data_oe_o || d.status_oe_o || d.cycle_active_o))
                throw std::runtime_error("CPU drove bus during HLDA");
            if (d.refresh_o && !d.hlda_o) throw std::runtime_error("refresh without HLDA");
            bool current_memr=d.refresh_memr_oe_o && !d.refresh_memr_n_o;
            if (bool(d.refresh_ras_trigger_o)!=current_memr)
                throw std::runtime_error("refresh read drive and RAS trigger disagree");
            if (current_memr && !last_memr) {
                if (!d.refresh_row_oe_o || !d.hlda_o || !d.refresh_o || d.refresh_row_o!=uint8_t(memr))
                    throw std::runtime_error("invalid refresh row or read drive");
                if (d.page_map_index_o!=15 || !d.page_a23_a17_oe_o || d.page_xa16_valid_o ||
                    d.page_a23_a17_o!=(refresh_page>>1) || d.page_xa16_o!=(refresh_page&1))
                    throw std::runtime_error("invalid refresh page selection or mapper drive");
                memr++;
            }
            last_memr=current_memr;
            uint32_t a=d.address_o;
            uint32_t base=a&~1u;
            if (d.io_cycle_o) {
                d.host_data_i=uint16_t(ports[uint16_t(base)]) | (uint16_t(ports[uint16_t(base+1)])<<8);
            } else {
                d.host_data_i=uint16_t(memory[base]) | (uint16_t(memory[base+1])<<8);
            }
            d.eval();
            if (d.completed_bytes_o) {
                const bool io=d.io_cycle_o, write=d.data_oe_o, fetch=d.fetch_cycle_o;
                const unsigned bytes=d.completed_bytes_o;
                if (io && bytes!=1) throw std::runtime_error("unexpected word I/O in BIOS");
                if (io && !write && d.dma_selected_o && !d.dma_rdata_valid_o)
                    throw std::runtime_error("undriven selected DMA read");
                if (io && !write && d.page_selected_o && !d.page_rdata_valid_o)
                    throw std::runtime_error("undriven selected page read");
                if (io && !write && d.timer_selected_o && !d.timer_rdata_valid_o)
                    throw std::runtime_error("undriven selected timer read");
                if (io && !write && d.port61_selected_o && !d.port61_rdata_valid_o)
                    throw std::runtime_error("undriven port 61 read");
                for (unsigned b=0;b<bytes;b++) {
                    const unsigned lane=(a+b)&1;
                    const uint16_t bus=write ? d.data_o : d.cpu_data_o;
                    const uint8_t value=uint8_t(bus>>(lane*8));
                    if (write) {
                        if (io) ports[uint16_t(a+b)]=value;
                        else memory[a+b]=value;
                        if (io && (a+b)==0x8f) refresh_page=value;
                    }
                    if (!fetch) trace << "B " << std::hex << (a+b) << ' ' << unsigned(value)
                                      << ' ' << write << ' ' << io << std::dec << '\n';
                }
                if (io && !write) {
                    if (d.dma_selected_o) dma_reads[d.dma_controller2_o ? 1 : 0]++;
                    if (d.page_selected_o) page_reads++;
                    if (d.timer_selected_o) timer_reads++;
                    if (d.port61_selected_o) {
                        port_reads++;
                        if (d.port61_rdata_o&0x10) bit_high=true; else bit_low=true;
                    }
                }
            }
            // Retire is sampled immediately after the processor rising edge.
            d.clk_i=1; d.clk_2x_i=1; d.eval();
            if (d.retire_o) {
                ++retired;
                trace << "R " << std::hex << d.retire_pc_o << ' ' << unsigned(d.retire_opcode_o)
                      << ' ' << uint16_t(d.segs_o>>16) << ' ' << d.ip_o << ' ' << d.flags_o
                      << ' ' << d.segs_o;
                for (unsigned r=0;r<8;r++) trace << ' ' << uint16_t(d.regs_o[r/2]>>((r%2)*16));
                trace << std::dec << '\n';
                if (d.retire_pc_o==0xf0258) timer1=true;
                if (d.retire_pc_o==0xf027b) timer2=true;
                if (d.retire_pc_o==0xf02c2) dma1=true;
                if (d.retire_pc_o==0xf02f8 && d.ip_o==0x0302) dma2=true;
                if (d.retire_pc_o==0xf038a) page=true;
                if (d.retire_pc_o==0xf03a2) {
                    if (!timer1 || !timer2 || !dma1 || !dma2 || !page || !timer_reads ||
                        dma_reads[0]<64 || dma_reads[1]<64 || page_reads<3573 ||
                        !bit_high || !bit_low || refreshes<2 || memr<2)
                        throw std::runtime_error("checkpoint lacks device or refresh evidence");
                    success=true;
                }
            }
            d.clk_2x_i=0; d.eval();
            d.clk_i=0; d.clk_2x_i=1; d.eval();
            d.clk_2x_i=0; d.eval();
            if (success) break;
        }
        if (!success) throw std::runtime_error("BIOS refresh checkpoint not reached before cycle bound");
        trace.flush();
        if (!trace) throw std::runtime_error("trace write failed");
        std::cout << "PASS: IBM AT BIOS reached F000:03A2 on native bus; wait=" << wait
                  << " half=" << half << " retired=" << retired << " cycles=" << cycles
                  << " timer_reads=" << timer_reads << " dma_reads=" << dma_reads[0] << '/' << dma_reads[1]
                  << " page_reads=" << page_reads << " port61_reads=" << port_reads
                  << " refreshes=" << refreshes << " memr=" << memr << '\n';
        d.final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
