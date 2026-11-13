// Runs the unchanged IBM AT BIOS on the system board until the first access
// to hardware the board does not model yet, then reports where it stopped.
//
// Memory map supplied here (IBM 5170 Technical Reference, Mar 1984,
// PDF page 29 for the ROM aliases):
//   000000-09FFFF  640 KiB RAM (base 512 KiB plus 128 KiB expansion)
//   0F0000-0FFFFF  64 KiB BIOS ROM, aliased at FF0000-FFFFFF
// Any other memory address, any undecoded I/O port, a halt, a shutdown or a
// bus protocol error ends the run with a STOP line. The board clocks are
// virtual (ASSUMPTION AT1), not IBM AT physical timing.
//
// Trace records (consumed by scripts/check_post_trace.py):
//   B <addr> <byte> <write> <io>    data transfer, instruction fetches omitted
//   R <pc> <op> <cs> <ip> <flags> <segs> <8 regs>   retired instruction
#include "Vibm_pc_at_5170_tb.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
constexpr uint32_t kRamEnd = 0xa0000;
bool is_rom(uint32_t a) { return (a >= 0x0f0000 && a <= 0x0fffff) || a >= 0xff0000; }
bool is_ram(uint32_t a) { return a < kRamEnd; }

std::string hex(uint32_t v, int width) {
    char buf[16];
    std::snprintf(buf, sizeof buf, "%0*X", width, v);
    return buf;
}
}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    try {
        if (argc != 5) throw std::runtime_error("usage: post_runner ROM TRACE wait half_period");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size() != 65536) throw std::runtime_error("expected a 64 KiB BIOS image");
        std::ofstream trace(argv[2]);
        if (!trace) throw std::runtime_error("cannot open trace");
        const bool wait = std::stoi(argv[3]) != 0;
        const unsigned half = unsigned(std::stoul(argv[4]));
        if (!half) throw std::runtime_error("zero timer half-period");

        Vibm_pc_at_5170_tb d;
        // ASSUMPTION AT6: RAM powers up as zero. Real DRAM contents are
        // undefined; the BIOS writes RAM before reading it in the code
        // reached so far.
        std::vector<uint8_t> ram(kRamEnd, 0);
        uint64_t retired = 0, rom_writes = 0;
        uint16_t cur_cs = 0xf000, cur_ip = 0xfff0;
        unsigned refresh_cycles = 0;
        std::string stop;

        d.clk_i = 0; d.clk_2x_i = 0; d.reset_i = 1; d.ready_n_i = 0;
        d.dma_clk_n_i = 0; d.hold_permit_i = 1; d.refresh_ready_i = 0;
        d.timer_clk_i = 0; d.mem_rdata_i = 0;
        auto half_clock = [&](bool rising) {
            d.clk_i = rising; d.clk_2x_i = 1; d.eval();
            d.clk_2x_i = 0; d.eval();
        };
        d.eval();
        for (int i = 0; i < 16; i++) { half_clock(true); half_clock(false); }
        d.reset_i = 0;

        uint64_t cycle = 0;
        for (; cycle < 400000000 && stop.empty(); cycle++) {
            d.ready_n_i = wait ? (cycle % 5 != 4) : 0;
            d.dma_clk_n_i = cycle & 1;
            d.timer_clk_i = ((cycle / half) & 1) ? 7 : 0;
            d.eval();
            if (d.refresh_o) d.refresh_ready_i = ++refresh_cycles >= 3;
            else { refresh_cycles = 0; d.refresh_ready_i = 0; }
            d.eval();

            const std::string where = hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
            if (d.protocol_error_o) stop = "kind=protocol-error";
            else if (d.shutdown_o) stop = "kind=shutdown";
            else if (d.halted_o) stop = "kind=halt";
            else if (d.fault_o) stop = "kind=fault";
            if (!stop.empty()) { stop += " at=" + where; break; }

            const uint32_t a = d.address_o;
            const uint32_t base = a & ~1u;
            auto byte = [&](uint32_t x) -> uint8_t {
                return is_ram(x) ? ram[x] : is_rom(x) ? rom[x & 0xffff] : 0;
            };
            if (!d.io_cycle_o) d.mem_rdata_i = uint16_t(byte(base) | (byte(base + 1) << 8));
            if (d.io_unclaimed_o) {
                stop = std::string("kind=io-") + (d.data_oe_o ? "write" : "read") +
                       " port=" + hex(a & 0xffff, 4) + " at=" + where;
                break;
            }
            if (d.io_read_undriven_o) {
                stop = "kind=io-undriven port=" + hex(a & 0xffff, 4) + " at=" + where;
                break;
            }
            if (d.cycle_active_o && d.address_oe_o && !d.io_cycle_o) {
                // A byte access to an odd address uses only the high lane;
                // an even access uses the high lane only when BHE# is low.
                const bool low = !(a & 1), high = (a & 1) || !d.bhe_n_o;
                for (uint32_t b : {base, base + 1})
                    if (((b == base && low) || (b == base + 1 && high)) && !is_ram(b) && !is_rom(b))
                        stop = std::string("kind=mem-") + (d.data_oe_o ? "write" : "read") +
                               " addr=" + hex(b, 6) + " at=" + where;
                if (!stop.empty()) break;
            }
            d.eval();

            if (d.completed_bytes_o) {
                const bool io = d.io_cycle_o, write = d.data_oe_o, fetch = d.fetch_cycle_o;
                for (unsigned b = 0; b < d.completed_bytes_o; b++) {
                    const uint32_t x = a + b;
                    const uint16_t bus = write ? d.data_o : d.cpu_data_o;
                    const uint8_t value = uint8_t(bus >> (((x) & 1) * 8));
                    if (write && !io) {
                        if (is_ram(x)) ram[x] = value; else ++rom_writes;
                    }
                    if (!fetch)
                        trace << "B " << std::hex << x << ' ' << unsigned(value) << ' ' << write << ' '
                              << io << std::dec << '\n';
                }
            }

            d.clk_i = 1; d.clk_2x_i = 1; d.eval();
            if (d.retire_o) {
                ++retired;
                cur_cs = uint16_t(d.segs_o >> 16);
                cur_ip = d.ip_o;
                trace << "R " << std::hex << d.retire_pc_o << ' ' << unsigned(d.retire_opcode_o) << ' '
                      << cur_cs << ' ' << d.ip_o << ' ' << d.flags_o << ' ' << d.segs_o;
                for (unsigned r = 0; r < 8; r++) trace << ' ' << uint16_t(d.regs_o[r / 2] >> ((r % 2) * 16));
                trace << std::dec << '\n';
            }
            d.clk_2x_i = 0; d.eval();
            half_clock(false);
        }
        if (stop.empty()) stop = "kind=cycle-limit at=" + hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
        trace.flush();
        if (!trace) throw std::runtime_error("trace write failed");
        std::cout << "STOP " << stop << " post=" << hex(d.post_code_o, 2) << " retired=" << retired
                  << " cycles=" << cycle << " rom_writes=" << rom_writes << " wait=" << wait
                  << " half=" << half << '\n';
        d.final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
