// Runs the unchanged IBM AT BIOS on the system board until the first access
// to hardware the board does not model yet, then reports where it stopped.
//
// Memory map supplied here (IBM 5170 Technical Reference, Mar 1984,
// PDF page 29 for the ROM aliases):
//   000000-09FFFF  640 KiB RAM (base 512 KiB plus 128 KiB expansion)
//   0F0000-0FFFFF  64 KiB BIOS ROM, aliased at FF0000-FFFFFF
// No memory card is fitted, so every other memory address is unpopulated:
// a write there is ignored and counted, a data read returns kOpenBus and is
// counted (the BIOS sizes memory by finding where a written pattern does not
// read back), and an instruction fetch from there ends the run. A halt with
// interrupts disabled or a bus protocol error also ends the run with a STOP
// line. So does an I/O cycle that no board device
// decodes, with one exception: a write to an I/O channel address (100h and
// above; the system board decodes 000h-0FFh, Technical Reference I/O map)
// is accepted and counted, because the expansion slots are empty and a
// write to an address no adapter decodes has no effect on the real bus. A
// read from an empty slot still stops the run: its value is undefined. The board clocks are
// virtual (ASSUMPTION AT1), not IBM AT physical timing.
//
// Trace records (consumed by scripts/check_post_trace.py):
//   B <addr> <byte> <write> <io>    data transfer, instruction fetches omitted
//   R <pc> <op> <cs> <ip> <flags> <segs> <8 regs>   retired instruction
//   A <byte>                        interrupt-acknowledge cycle; the second
//                                   of each pair carries the vector
//   Z                               the processor was reset (8042 RC or shutdown)
//
// Optional 8042 log (consumed by scripts/check_kbc_log.py), in time order:
//   I <pc>            8042 instruction or interrupt vector retired
//   W <n> <a0> <data> host write took effect after <n> 8042 instruction starts
//   X <n>             host read of the data register took effect (clears OBF)
//   S <a0> <data>     value the CPU read from the 8042 (a0 = 1: status)
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
// ASSUMPTION AT14 (see spec): value read from a memory address no device
// drives.
constexpr uint8_t kOpenBus = 0xff;
// Processor clocks a halt with interrupts disabled may last (about a third
// of a second at 6 MHz) before the run is given up.
constexpr uint64_t kHaltWait = 2000000;
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
        if (argc != 5 && argc != 6)
            throw std::runtime_error("usage: post_runner ROM TRACE wait half_period [KBC_LOG]");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size() != 65536) throw std::runtime_error("expected a 64 KiB BIOS image");
        std::ofstream trace(argv[2]);
        if (!trace) throw std::runtime_error("cannot open trace");
        std::ofstream klog;
        if (argc == 6) {
            klog.open(argv[5]);
            if (!klog) throw std::runtime_error("cannot open 8042 log");
            klog << std::hex;
        }
        const bool wait = std::stoi(argv[3]) != 0;
        const unsigned half = unsigned(std::stoul(argv[4]));
        if (!half) throw std::runtime_error("zero timer half-period");

        Vibm_pc_at_5170_tb d;
        // ASSUMPTION AT6: RAM powers up as zero. Real DRAM contents are
        // undefined; the BIOS writes RAM before reading it in the code
        // reached so far.
        std::vector<uint8_t> ram(kRamEnd, 0);
        uint64_t retired = 0, rom_writes = 0, open_reads = 0, open_writes = 0, cpu_resets = 0;
        uint64_t halt_clocks = 0;
        bool was_reset = true;   // the power-on reset is not counted
        uint16_t cur_cs = 0xf000, cur_ip = 0xfff0;
        unsigned refresh_cycles = 0;
        std::string stop;

        d.clk_i = 0; d.clk_2x_i = 0; d.reset_i = 1; d.ready_n_i = 0;
        d.dma_clk_n_i = 0; d.hold_permit_i = 1; d.refresh_ready_i = 0;
        d.timer_clk_i = 0; d.mem_rdata_i = 0;
        // Board configuration: keyboard unlocked, monochrome display switch,
        // no manufacturing jumper, J18 enabling the 2nd 256K, and no keyboard
        // plugged in (both keyboard lines released).
        d.kbd_unlocked_i = 1; d.display_mono_i = 1; d.mfg_jumper_i = 0; d.ram_512k_i = 1;
        d.kbd_clk_i = 1; d.kbd_data_i = 1;
        d.chan_irq_i = 0;   // no adapter requests an interrupt
        uint64_t kbc_retired = 0, kbc_started = 0, slot_writes = 0;
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
            // A shutdown resets the processor on the board. A halt with
            // interrupts disabled can end only by a processor reset (NMI is
            // not connected); the BIOS halts like that after asking the 8042
            // to pulse the reset line, so allow kHaltWait clocks for it.
            else if (halt_clocks > kHaltWait) stop = "kind=halt";
            else if (d.fault_o) stop = "kind=fault";
            else if (d.kbc_illegal_o) stop = "kind=kbc-illegal-opcode";
            if (!stop.empty()) { stop += " at=" + where; break; }

            const uint32_t a = d.address_o;
            const uint32_t base = a & ~1u;
            auto byte = [&](uint32_t x) -> uint8_t {
                return is_ram(x) ? ram[x] : is_rom(x) ? rom[x & 0xffff] : kOpenBus;
            };
            if (!d.io_cycle_o) d.mem_rdata_i = uint16_t(byte(base) | (byte(base + 1) << 8));
            const uint32_t port = d.io_port_o;
            const bool empty_slot_write = d.io_unclaimed_o && d.data_oe_o && port >= 0x100;
            if (d.io_unclaimed_o && !empty_slot_write) {
                stop = std::string("kind=io-") + (d.data_oe_o ? "write" : "read") +
                       " port=" + hex(port, 4) + " at=" + where;
                break;
            }
            if (d.io_read_undriven_o) {
                stop = "kind=io-undriven port=" + hex(port, 4) + " at=" + where;
                break;
            }
            if (d.completed_bytes_o && !d.io_cycle_o && d.fetch_cycle_o) {
                // A byte access to an odd address uses only the high lane;
                // an even access uses the high lane only when BHE# is low.
                const bool low = !(a & 1), high = (a & 1) || !d.bhe_n_o;
                for (uint32_t b : {base, base + 1})
                    if (((b == base && low) || (b == base + 1 && high)) && !is_ram(b) && !is_rom(b))
                        stop = "kind=fetch-unpopulated addr=" + hex(b, 6) + " at=" + where;
                if (!stop.empty()) break;
            }
            d.eval();

            if (d.completed_bytes_o) {
                const bool io = d.io_cycle_o, write = d.data_oe_o, fetch = d.fetch_cycle_o;
                if (d.inta_cycle_o)
                    trace << "A " << std::hex << unsigned(d.cpu_data_o & 0xff) << std::dec << '\n';
                else
                for (unsigned b = 0; b < d.completed_bytes_o; b++) {
                    const uint32_t x = a + b;
                    const uint16_t bus = write ? d.data_o : d.cpu_data_o;
                    const uint8_t value = uint8_t(bus >> (((x) & 1) * 8));
                    if (write && !io) {
                        if (is_ram(x)) ram[x] = value;
                        else if (is_rom(x)) ++rom_writes;
                        else ++open_writes;
                    }
                    if (!write && !io && !fetch && !is_ram(x) && !is_rom(x) && !d.inta_cycle_o)
                        ++open_reads;
                    if (io && write && empty_slot_write) ++slot_writes;
                    // The 8042 select (sheets 13/18): even addresses 060h-06Eh.
                    if (klog.is_open() && io && !write && (x & 0x3f1) == 0x060)
                        klog << "S " << ((x >> 2) & 1) << ' ' << unsigned(value) << '\n';
                    if (!fetch)
                        trace << "B " << std::hex << x << ' ' << unsigned(value) << ' ' << write << ' '
                              << io << std::dec << '\n';
                }
            }

            // 8042 events at this rising edge. An instruction that starts at
            // the edge used the state before it, so it is counted before a
            // host event that takes effect at the same edge.
            if (d.cpu_reset_o && !was_reset) {
                ++cpu_resets;
                trace << "Z\n";
            }
            halt_clocks = (d.halted_o && !(d.flags_o & 0x200)) ? halt_clocks + 1 : 0;
            was_reset = d.cpu_reset_o;
            if (d.kbc_start_o) ++kbc_started;
            if (klog.is_open()) {
                if (d.kbc_wr_end_o)
                    klog << "W " << kbc_started << ' ' << unsigned(d.kbc_wr_a0_o) << ' '
                         << unsigned(d.kbc_wr_data_o) << '\n';
                if (d.kbc_rd_end_o && !d.kbc_rd_a0_o) klog << "X " << kbc_started << '\n';
            }
            d.clk_i = 1; d.clk_2x_i = 1; d.eval();
            if (d.kbc_retire_o) {
                ++kbc_retired;
                if (klog.is_open()) klog << "I " << unsigned(d.kbc_retire_pc_o) << '\n';
            }
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
        if (klog.is_open()) {
            klog.flush();
            if (!klog) throw std::runtime_error("8042 log write failed");
        }
        std::cout << "STOP " << stop << " post=" << hex(d.post_code_o, 2) << " retired=" << retired
                  << " cycles=" << cycle << " kbc_retired=" << kbc_retired << " slot_writes=" << slot_writes << " rom_writes=" << rom_writes << " open_reads=" << open_reads
                  << " open_writes=" << open_writes << " cpu_resets=" << cpu_resets << " wait=" << wait
                  << " half=" << half << '\n';
        d.final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
