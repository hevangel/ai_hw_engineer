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
// line. So does an I/O cycle below 100h that no board device decodes (the
// system board decodes 000h-0FFh, Technical Reference I/O map). The
// expansion slots are empty, so an I/O channel address (100h and above)
// is undriven: a write there has no effect and a read returns kOpenBus;
// both are counted (ASSUMPTION AT14).
//
// The board clocks are
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
//
// Optional MC146818 log (consumed by scripts/check_rtc_log.py), in time
// order; <t> is the number of oscillator periods the chip has counted:
//   A <t> <byte>      address strobe took effect with this bus value
//   W <t> <byte>      data write took effect
//   V <t> <byte>      value the CPU read from port 71h
//   R <t>             that read took effect (register C clears on read)
//
// Options, after the positional arguments:
//   --stop-post=XX    stop when port 80h holds XX (hex)
//   --stop-at=ADDR    stop after the instruction at physical address ADDR (hex) retires
//   --max-cycles=N    give the run up after N processor clocks
//   --frame=FILE      (EGA build) write the last complete video frame as a PPM
//
// Built with -DAT_EGA the machine is ibm_pc_at_5170_ega: an IBM Enhanced
// Graphics Adapter sits on the I/O channel and owns memory A0000-DFFFF and
// the I/O addresses it decodes. A channel read the card does not drive
// still returns kOpenBus. The picture is rebuilt from the card's monitor
// connector: one pixel per pix_en_o, a new line at each horizontal sync
// and a new frame at each vertical sync; the six direct-drive bits
// {r,g,b,R,G,B} map to 2/3 and 1/3 intensity per gun (Enhanced Color
// Display, 350-line mode).
#ifdef AT_EGA
#include "Vibm_pc_at_5170_ega_tb.h"
using Dut = Vibm_pc_at_5170_ega_tb;
#else
#include "Vibm_pc_at_5170_tb.h"
using Dut = Vibm_pc_at_5170_tb;
#endif
#include "verilated.h"
#include <algorithm>
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
// Processor clocks after which a run that has not stopped is given up.
constexpr uint64_t kCycleLimit = 6000000000ull;
// Must match the parameters of ibm_pc_at_5170_ega.
[[maybe_unused]] constexpr uint64_t kVidHz = 24000000, kOscHz = 14318180;
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
        int stop_post = -1;
        long stop_at = -1;
        uint64_t cycle_limit = kCycleLimit;
        std::string frame_path;
        while (argc > 5 && std::string(argv[argc - 1]).rfind("--", 0) == 0) {
            const std::string opt = argv[--argc];
            if (opt.rfind("--stop-post=", 0) == 0) stop_post = std::stoi(opt.substr(12), nullptr, 16);
            else if (opt.rfind("--frame=", 0) == 0) frame_path = opt.substr(8);
            else if (opt.rfind("--stop-at=", 0) == 0) stop_at = std::stol(opt.substr(10), nullptr, 16);
            else if (opt.rfind("--max-cycles=", 0) == 0) cycle_limit = std::stoull(opt.substr(13));
            else throw std::runtime_error("unknown option " + opt);
        }
        if (argc < 5 || argc > 7)
            throw std::runtime_error(
                "usage: post_runner ROM TRACE wait half_period [KBC_LOG [RTC_LOG]]");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size() != 65536) throw std::runtime_error("expected a 64 KiB BIOS image");
        std::ofstream trace(argv[2]);
        if (!trace) throw std::runtime_error("cannot open trace");
        std::ofstream klog;
        if (argc >= 6) {
            klog.open(argv[5]);
            if (!klog) throw std::runtime_error("cannot open 8042 log");
            klog << std::hex;
        }
        std::ofstream rlog;
        if (argc == 7) {
            rlog.open(argv[6]);
            if (!rlog) throw std::runtime_error("cannot open MC146818 log");
            rlog << std::hex;
        }
        uint64_t rtc_ticks = 0;
        const bool wait = std::stoi(argv[3]) != 0;
        const unsigned half = unsigned(std::stoul(argv[4]));
        if (!half) throw std::runtime_error("zero timer half-period");

        Dut d;
        // ASSUMPTION AT6: RAM powers up as zero. Real DRAM contents are
        // undefined; the BIOS writes RAM before reading it in the code
        // reached so far.
        std::vector<uint8_t> ram(kRamEnd, 0);
        uint64_t retired = 0, rom_writes = 0, open_reads = 0, open_writes = 0, cpu_resets = 0;
        uint64_t halt_clocks = 0, inta_cycles = 0, chan_writes = 0;
        bool inta_active = false;
        uint8_t inta_byte = 0;
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
        uint64_t kbc_retired = 0, kbc_started = 0, slot_writes = 0, slot_reads = 0;
#ifdef AT_EGA
        // Enhanced Color Display as the primary display in its 350-line
        // mode: SW1 off, SW2 on, SW3 on, SW4 off (1 = off); P1 at pin 2 =
        // secondary red, P3 at the 3xx port addresses.
        d.ega_sw_i = 0x9; d.ega_p1_i = 1; d.ega_p3_i = 1; d.vid_clk_i = 0;
        std::vector<std::vector<uint8_t>> lines(1), last_frame;
        uint64_t frames = 0;
        bool was_hsync = false, was_vsync = false;
        // One rising edge of the video clock has just been evaluated.
        auto video_sample = [&]() {
            if (!d.pix_en_o) return;
            if (d.vsync_o && !was_vsync) {
                if (lines.size() > 1) { last_frame = lines; ++frames; }
                lines.assign(1, {});
            } else if (d.hsync_o && !was_hsync) {
                lines.emplace_back();
            }
            was_hsync = d.hsync_o; was_vsync = d.vsync_o;
            if (!d.blank_o) lines.back().push_back(uint8_t(d.video_o));
        };
        // ASSUMPTION AT19: the video clock runs at the processor clock's
        // rate, and the 8254 clock is the channel's OSC / 12 on the same
        // time base (kOscHz / 12 against kVidHz), as on the real board.
        uint64_t timer_acc = 0;
        bool timer_level = false;
#define VID_RISE() do { d.vid_clk_i = 1; } while (0)
#define VID_AFTER() do { video_sample(); } while (0)
#define VID_FALL() do { d.vid_clk_i = 0; } while (0)
#else
#define VID_RISE() do { } while (0)
#define VID_AFTER() do { } while (0)
#define VID_FALL() do { } while (0)
#endif
        auto half_clock = [&](bool rising) {
            d.clk_i = rising; d.clk_2x_i = 1;
            if (rising) VID_RISE(); else VID_FALL();
            d.eval();
            if (rising) VID_AFTER();
            d.clk_2x_i = 0; d.eval();
        };
        d.eval();
        for (int i = 0; i < 16; i++) { half_clock(true); half_clock(false); }
        d.reset_i = 0;

        uint64_t cycle = 0;
        for (; cycle < cycle_limit && stop.empty(); cycle++) {
            d.ready_n_i = wait ? (cycle % 5 != 4) : 0;
            d.dma_clk_n_i = cycle & 1;
#ifdef AT_EGA
            timer_acc += 2 * (kOscHz / 12);
            if (timer_acc >= kVidHz) { timer_acc -= kVidHz; timer_level = !timer_level; }
            d.timer_clk_i = timer_level ? 7 : 0;
#else
            d.timer_clk_i = ((cycle / half) & 1) ? 7 : 0;
#endif
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
            // The host's data for this cycle: memory, or the undriven bus of
            // an I/O read that no board device answers.
            d.mem_rdata_i = d.io_cycle_o ? uint16_t(kOpenBus | (kOpenBus << 8))
                                         : uint16_t(byte(base) | (byte(base + 1) << 8));
            const uint32_t port = d.io_port_o;
            const bool empty_slot = d.io_unclaimed_o && port >= 0x100;
            const bool empty_slot_write = empty_slot && d.data_oe_o;
            if (d.io_unclaimed_o && !empty_slot) {
                stop = std::string("kind=io-") + (d.data_oe_o ? "write" : "read") +
                       " port=" + hex(port, 4) + " at=" + where;
                break;
            }
            if (d.io_read_undriven_o) {
                stop = "kind=io-undriven port=" + hex(port, 4) + " at=" + where;
                break;
            }
#ifdef AT_EGA
            const bool chan_driven = d.chan_sel_o && d.chan_driven_o;
            const bool chan_mem = d.chan_sel_o && !d.io_cycle_o;
#else
            const bool chan_driven = false, chan_mem = false;
#endif
            if (d.completed_bytes_o && !d.io_cycle_o && d.fetch_cycle_o && !chan_driven) {
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
                for (unsigned b = 0; b < d.completed_bytes_o; b++) {
                    const uint32_t x = a + b;
                    const uint16_t bus = write ? d.data_o : d.cpu_data_o;
                    const uint8_t value = uint8_t(bus >> (((x) & 1) * 8));
                    if (write && !io) {
                        if (is_ram(x)) ram[x] = value;
                        else if (is_rom(x)) ++rom_writes;
                        else if (chan_mem) ++chan_writes;
                        else ++open_writes;
                    }
                    if (!write && !io && !fetch && !is_ram(x) && !is_rom(x) && !d.inta_cycle_o &&
                        !chan_driven)
                        ++open_reads;
                    if (io && write && empty_slot_write) ++slot_writes;
                    if (io && !write && empty_slot && !chan_driven) ++slot_reads;
                    // The 8042 select (sheets 13/18): even addresses 060h-06Eh.
                    if (klog.is_open() && io && !write && (x & 0x3f1) == 0x060)
                        klog << "S " << ((x >> 2) & 1) << ' ' << unsigned(value) << '\n';
                    // MC146818 data port (sheet 18): odd addresses 071h-07Fh.
                    if (rlog.is_open() && io && !write && (x & 0x3f1) == 0x071)
                        rlog << "V " << rtc_ticks << ' ' << unsigned(value) << '\n';
                    if (!fetch)
                        trace << "B " << std::hex << x << ' ' << unsigned(value) << ' ' << write << ' '
                              << io << std::dec << '\n';
                }
            }

            // 8042 events at this rising edge. An instruction that starts at
            // the edge used the state before it, so it is counted before a
            // host event that takes effect at the same edge.
            // An interrupt-acknowledge cycle ends when inta_cycle_o falls; the
            // byte on the data bus in its last clock is what the CPU took.
            if (d.inta_cycle_o) {
                inta_active = true;
                inta_byte = uint8_t(d.cpu_data_o);
            } else if (inta_active) {
                inta_active = false;
                ++inta_cycles;
                trace << "A " << std::hex << unsigned(inta_byte) << std::dec << '\n';
            }
            if (d.cpu_reset_o && !was_reset) {
                ++cpu_resets;
                trace << "Z\n";
            }
            halt_clocks = (d.halted_o && !(d.flags_o & 0x200)) ? halt_clocks + 1 : 0;
            was_reset = d.cpu_reset_o;
            // MC146818 events at this rising edge. A bus event is logged
            // before an oscillator period that the chip counts at the same
            // edge.
            if (rlog.is_open()) {
                if (d.rtc_as_fall_o) rlog << "A " << rtc_ticks << ' ' << unsigned(d.rtc_ad_o) << '\n';
                if (d.rtc_wr_end_o) rlog << "W " << rtc_ticks << ' ' << unsigned(d.rtc_ad_o) << '\n';
                if (d.rtc_rd_end_o) rlog << "R " << rtc_ticks << '\n';
            }
            if (d.rtc_tick_o) ++rtc_ticks;
            if (d.kbc_start_o) ++kbc_started;
            if (klog.is_open()) {
                if (d.kbc_wr_end_o)
                    klog << "W " << kbc_started << ' ' << unsigned(d.kbc_wr_a0_o) << ' '
                         << unsigned(d.kbc_wr_data_o) << '\n';
                if (d.kbc_rd_end_o && !d.kbc_rd_a0_o) klog << "X " << kbc_started << '\n';
            }
            d.clk_i = 1; d.clk_2x_i = 1; VID_RISE(); d.eval();
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
            VID_AFTER();
            d.clk_2x_i = 0; d.eval();
            half_clock(false);
            if ((stop_post >= 0 && d.post_code_o == stop_post && !d.cpu_reset_o && cycle > 64) ||
                (stop_at >= 0 && d.retire_o && long(d.retire_pc_o) == stop_at)) {
                stop = (stop_at >= 0 ? "kind=stop-at at=" : "kind=post-code at=") + hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
                ++cycle;
                break;
            }
        }
        if (stop.empty()) stop = "kind=cycle-limit at=" + hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
        trace.flush();
        if (!trace) throw std::runtime_error("trace write failed");
        if (klog.is_open()) {
            klog.flush();
            if (!klog) throw std::runtime_error("8042 log write failed");
        }
        std::cout << "STOP " << stop << " post=" << hex(d.post_code_o, 2) << " retired=" << retired
                  << " cycles=" << cycle << " kbc_retired=" << kbc_retired << " slot_writes=" << slot_writes << " slot_reads=" << slot_reads << " rom_writes=" << rom_writes << " open_reads=" << open_reads
                  << " open_writes=" << open_writes << " cpu_resets=" << cpu_resets << " inta_cycles=" << inta_cycles << " wait=" << wait
                  << " half=" << half << '\n';
#ifdef AT_EGA
        std::cout << "VIDEO frames=" << frames << " chan_mem_writes=" << chan_writes;
        if (!last_frame.empty()) {
            size_t width = 0;
            for (const auto& l : last_frame) width = std::max(width, l.size());
            size_t first = 0, last = last_frame.size();
            while (first < last && last_frame[first].empty()) ++first;
            while (last > first && last_frame[last - 1].empty()) --last;
            std::cout << " width=" << width << " lines=" << (last - first);
            if (!frame_path.empty() && width) {
                std::ofstream ppm(frame_path, std::ios::binary);
                ppm << "P6\n" << width << ' ' << (last - first) << "\n255\n";
                for (size_t y = first; y < last; y++)
                    for (size_t x = 0; x < width; x++) {
                        const unsigned v = x < last_frame[y].size() ? last_frame[y][x] : 0;
                        for (int gun = 2; gun >= 0; gun--)
                            ppm.put(char(0xAA * ((v >> gun) & 1) + 0x55 * ((v >> (gun + 3)) & 1)));
                    }
                if (!ppm) throw std::runtime_error("frame write failed");
            }
        }
        std::cout << '\n';
#endif
        d.final();
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
