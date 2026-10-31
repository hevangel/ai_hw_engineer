#include "Vintel_80286_at_fixture.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

// Virtual fixture time: a timer edge occurs every half_period core-model
// ticks. This is not a claim that the core tick equals a physical CPU clock.
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        if (argc != 5) throw std::runtime_error("usage: runner ROM TRACE wait half_period");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size() != 65536) throw std::runtime_error("expected 64 KiB BIOS ROM");
        std::ofstream trace(argv[2]);
        if (!trace) throw std::runtime_error("cannot open trace");
        const bool wait = std::stoi(argv[3]) != 0;
        const unsigned half_period = unsigned(std::stoul(argv[4]));
        if (!half_period) throw std::runtime_error("half_period must be positive");

        Vintel_80286_at_fixture d;
        std::vector<uint8_t> memory(1u << 24, 0), ports(1u << 16, 0);
        for (size_t i=0; i<rom.size(); ++i)
            memory[0xf0000+i]=memory[0xff0000+i]=rom[i];
        uint64_t cycles=0, retired=0, timer_reads=0, timer_writes=0, first_test_reads=0;
        uint64_t dma_reads[2]={0,0}, dma_writes[2]={0,0};
        uint64_t page_reads=0, page_writes=0;
        uint16_t page_read_mask=0;
        uint8_t dma_register_reads[2]={0,0};
        uint8_t observed_or=0, observed_and=0xff;
        d.rst_n=0; d.timer_gate2_i=0;
        bool first_success=false, second_timer_success=false, dma1_success=false, dma2_success=false, success=false;
        for (; cycles<50000000; ++cycles) {
            if (cycles==2) d.rst_n=1;
            d.clk=0;
            d.bus_ready_i = !wait || cycles%4==3;
            d.timer_clk_i = ((cycles/half_period)&1) ? 0 : 7;
            d.host_rdata_i=0;
            d.eval();
            if (d.bus_req_o && d.bus_ready_i) {
                const uint32_t address=d.bus_addr_o;
                const bool io=d.bus_io_o, write=d.bus_write_o, fetch=d.bus_fetch_o;
                uint8_t value=uint8_t(d.bus_wdata_o);
                if (fetch && (io || write)) throw std::runtime_error("invalid fetch transaction");
                if (io) {
                    if (d.timer_selected_o) {
                        if (write) ++timer_writes;
                        else {
                            if (!d.timer_rdata_valid_o) throw std::runtime_error("timer read was undriven");
                            value=d.timer_rdata_o; ++timer_reads;
                            if (first_success) observed_and&=value;
                            else observed_or|=value;
                        }
                    } else if (d.dma_selected_o) {
                        const unsigned controller=d.dma_controller2_o ? 1 : 0;
                        if (write) ++dma_writes[controller];
                        else {
                            if (!d.dma_rdata_valid_o) throw std::runtime_error("DMA register read was undriven");
                            value=d.dma_rdata_o; ++dma_reads[controller];
                            const unsigned reg=controller ? ((address-0xc0)/2) : address;
                            if (reg<8) dma_register_reads[controller]|=uint8_t(1u<<reg);
                        }
                    } else if (d.page_selected_o) {
                        if (write) ++page_writes;
                        else {
                            if (!d.page_rdata_valid_o) throw std::runtime_error("page register read was undriven");
                            value=d.page_rdata_o; ++page_reads;
                            page_read_mask|=uint16_t(1u<<(address&15));
                        }
                    } else if (write) ports[uint16_t(address)]=value;
                    else value=ports[uint16_t(address)];
                } else if (write) memory[address]=value;
                else value=memory[address];
                if (!write) d.host_rdata_i=value;
                if (!fetch && d.rst_n)
                    trace << "B " << std::hex << address << ' ' << unsigned(value)
                          << ' ' << write << ' ' << io << std::dec << '\n';
            }
            d.eval(); d.clk=1; d.eval();
            if (!d.rst_n) continue;
            if (d.fault_o || d.shutdown_o || d.halted_o)
                throw std::runtime_error("CPU stopped before timer checkpoint at CS:IP " +
                    std::to_string(uint16_t(d.segs_o>>16)) + ":" + std::to_string(d.ip_o));
            if (d.retire_o) {
                ++retired;
                trace << "R " << std::hex << d.retire_pc_o << ' ' << unsigned(d.retire_opcode_o)
                      << ' ' << uint16_t(d.segs_o>>16) << ' ' << d.ip_o << ' ' << d.flags_o
                      << ' ' << d.segs_o;
                for (unsigned r=0;r<8;++r)
                    trace << ' ' << uint16_t(d.regs_o[r/2] >> ((r%2)*16));
                trace << std::dec << '\n';
                if (d.retire_pc_o==0xf0258) {
                    const uint16_t bx=uint16_t(d.regs_o[1]>>16);
                    if ((bx&0xff)!=0xff || !timer_reads || !timer_writes || observed_or!=0xff)
                        throw std::runtime_error("first timer checkpoint lacked the expected channel-1 observations");
                    first_success=true;
                    first_test_reads=timer_reads;
                }
                if (d.retire_pc_o==0xf027b) {
                    const uint16_t bx=uint16_t(d.regs_o[1]>>16);
                    if (!first_success || (bx&0xff)!=0 || timer_reads==first_test_reads || observed_and!=0)
                        throw std::runtime_error("second timer checkpoint lacked the expected channel-1 observations");
                    second_timer_success=true;
                }
                if (d.retire_pc_o==0xf02c2) {
                    const uint16_t bx=uint16_t(d.regs_o[1]>>16);
                    if (!second_timer_success || (bx&0xff)!=0xaa ||
                        dma_register_reads[0]!=0xff || dma_reads[0]<64 || !dma_writes[0])
                        throw std::runtime_error("first DMA register test did not complete all patterns and registers");
                    dma1_success=true;
                }
                if (d.retire_pc_o==0xf02f8 && d.ip_o==0x0302) {
                    const uint16_t bx=uint16_t(d.regs_o[1]>>16);
                    if (!dma1_success || (bx&0xff)!=0xaa ||
                        dma_register_reads[1]!=0xff || dma_reads[1]<64 || !dma_writes[1])
                        throw std::runtime_error("second DMA register test did not complete all patterns and registers");
                    dma2_success=true;
                }
                if (d.retire_pc_o==0xf038a) {
                    if (!dma2_success || page_read_mask!=0xfffe || page_reads<3573 || !page_writes)
                        throw std::runtime_error("DMA page-register BIOS test did not cover required ports");
                    success=true; break;
                }
            }
        }
        if (!success) throw std::runtime_error("timer checkpoint not reached before cycle bound");
        trace.flush();
        if (!trace) throw std::runtime_error("trace write failed");
        std::cout << "PASS: IBM AT BIOS reached F000:038A after timer, DMA and page-register tests; wait="
                  << wait << " virtual_half_period=" << half_period << " retired=" << retired
                  << " first_test_reads=" << first_test_reads << " total_timer_reads=" << timer_reads
                  << " timer_writes=" << timer_writes
                  << " dma_reads=" << dma_reads[0] << "/" << dma_reads[1]
                  << " page_reads=" << page_reads << " page_writes=" << page_writes
                  << " cycles=" << cycles << '\n';
        d.final();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
