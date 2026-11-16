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
// is undriven: a write there has no effect and is counted; a read ends
// the run, or with --empty-slots returns kOpenBus and is counted
// (ASSUMPTION AT14).
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
//   --empty-slots     an I/O read at 100h or above that nothing answers returns
//                     kOpenBus and is counted, instead of ending the run
//   --stop-at=ADDR    stop after the instruction at physical address ADDR (hex) retires
//   --max-cycles=N    give the run up after N processor clocks
//   --frame=FILE      (EGA build) write the last complete video frame as a PPM
//
// Built with -DAT_VGA the machine is ibm_pc_at_5170_vga (IBM PS/2 Display
// Adapter; the frame holds its DAC outputs). Built with -DAT_EGA the
// machine is ibm_pc_at_5170_ega: an IBM Enhanced
// Graphics Adapter sits on the I/O channel and owns memory A0000-DFFFF and
// the I/O addresses it decodes. A channel read the card does not drive
// still returns kOpenBus. The picture is rebuilt from the card's monitor
// connector: one pixel per pix_en_o while display enable is active (the
// border is left out), a new line at each horizontal sync
// and a new frame at each vertical sync; the six direct-drive bits
// {r,g,b,R,G,B} map to 2/3 and 1/3 intensity per gun (Enhanced Color
// Display, 350-line mode).
#if defined(AT_EGA)
#define AT_CARD 1
#include "Vibm_pc_at_5170_ega_tb.h"
using Dut = Vibm_pc_at_5170_ega_tb;
#elif defined(AT_VGA)
#define AT_CARD 1
#include "Vibm_pc_at_5170_vga_tb.h"
using Dut = Vibm_pc_at_5170_vga_tb;
#else
#include "Vibm_pc_at_5170_tb.h"
using Dut = Vibm_pc_at_5170_tb;
#endif
#include "verilated.h"
#ifdef AT_CARD
#include "at_diskette_media.hpp"
#endif
#include <chrono>
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
// Expansion RAM from 100000h (--ext-kb): end of it, 100000h when none.
uint32_t g_ext_end = 0x100000;
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
bool is_ram(uint32_t a) { return a < kRamEnd || (a >= 0x100000 && a < g_ext_end); }

// Bench stimulus, not a keyboard model: it presses and releases F1 once at
// the 8042's keyboard connector, as an AT keyboard sends it (Technical
// Reference, keyboard interface: the device drives the clock; each frame is
// a 0 start bit, eight data bits LSB first, an odd parity bit and a 1 stop
// bit; the host samples data while the clock is low). The bytes are scan
// code set 2: F1 make 05h, break F0h 05h; the 8042 translates them for the
// BIOS (command byte bit 6). A frame starts only after both lines have been
// released by the host for kIdle clocks; if the host pulls the clock low
// during a frame the byte is sent again. It answers no host command.
struct F1Stimulus {
    // Half a keyboard clock period: 240 processor clocks, 40 us on the
    // board's 6 MHz time base of the 8042 (AT1), a 12.5 kHz keyboard clock.
    static constexpr unsigned kHalf = 240, kIdle = 6000;
    const uint8_t bytes[3] = {0x05, 0xf0, 0x05};
    unsigned next = 0, bit = 0, phase = 0, count = 0, idle = 0;
    bool armed = false, framing = false;
    bool clk = true, data = true;   // what the stimulus drives (1 = released)
    uint64_t sent = 0, retries = 0;
    bool done() const { return next == 3; }
    void tick(bool clk_line, bool data_line) {
        if (!armed || done()) { clk = data = true; return; }
        if (!framing) {
            clk = data = true;
            idle = (clk_line && data_line) ? idle + 1 : 0;
            if (idle >= kIdle) { framing = true; bit = 0; phase = 0; count = 0; }
            return;
        }
        // While the stimulus releases the clock, a low clock line is the
        // host inhibiting: abandon the frame.
        if (clk && !clk_line && bit < 10) {
            framing = false; idle = 0; clk = data = true; ++retries; return;
        }
        const uint8_t b = bytes[next];
        const bool parity = !(__builtin_popcount(b) & 1);
        const bool level = bit == 0 ? false : bit <= 8 ? ((b >> (bit - 1)) & 1) : bit == 9 ? parity : true;
        data = level;
        clk = phase == 0;
        if (++count >= kHalf) {
            count = 0;
            if (phase == 0) phase = 1;
            else {
                phase = 0;
                if (++bit == 11) { framing = false; idle = 0; clk = data = true; ++next; ++sent; }
            }
        }
    }
};

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
#ifdef AT_CARD
        bool empty_slots = true;   // the I/O channel is modeled
#else
        bool empty_slots = false;
#endif
        uint64_t cycle_limit = kCycleLimit;
        std::string frame_path;
        std::string fd_path[2];
        bool fd_ro[2] = {false, false}, write_back = false;
        std::string fd_type[2] = {"1.2", ""};
        int f1_post = -1;
        uint64_t ext_kb = 0;
        while (argc > 5 && std::string(argv[argc - 1]).rfind("--", 0) == 0) {
            const std::string opt = argv[--argc];
            if (opt.rfind("--stop-post=", 0) == 0) stop_post = std::stoi(opt.substr(12), nullptr, 16);
            else if (opt.rfind("--frame=", 0) == 0) frame_path = opt.substr(8);
            else if (opt == "--empty-slots") empty_slots = true;
            else if (opt.rfind("--stop-at=", 0) == 0) stop_at = std::stol(opt.substr(10), nullptr, 16);
            else if (opt.rfind("--max-cycles=", 0) == 0) cycle_limit = std::stoull(opt.substr(13));
            else if (opt.rfind("--fda=", 0) == 0) fd_path[0] = opt.substr(6);
            else if (opt.rfind("--fdb=", 0) == 0) fd_path[1] = opt.substr(6);
            else if (opt == "--fda-ro") fd_ro[0] = true;
            else if (opt == "--fdb-ro") fd_ro[1] = true;
            else if (opt.rfind("--fda-type=", 0) == 0) fd_type[0] = opt.substr(11);
            else if (opt.rfind("--fdb-type=", 0) == 0) fd_type[1] = opt.substr(11);
            else if (opt == "--write-back") write_back = true;
            else if (opt.rfind("--f1-at-post=", 0) == 0) f1_post = std::stoi(opt.substr(13), nullptr, 16);
            else if (opt.rfind("--ext-kb=", 0) == 0) ext_kb = std::stoull(opt.substr(9));
            else throw std::runtime_error("unknown option " + opt);
        }
        if (ext_kb > 15 * 1024) throw std::runtime_error("--ext-kb above 15360");
        g_ext_end = 0x100000 + uint32_t(ext_kb * 1024);
#ifndef AT_CARD
        if (!fd_path[0].empty() || !fd_path[1].empty())
            throw std::runtime_error("the bare board has no diskette adapter");
#endif
        if (argc < 5 || argc > 7)
            throw std::runtime_error(
                "usage: post_runner ROM TRACE wait half_period [KBC_LOG [RTC_LOG]]");
        std::ifstream file(argv[1], std::ios::binary);
        std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)), {});
        if (rom.size() != 65536) throw std::runtime_error("expected a 64 KiB BIOS image");
        // TRACE "-" writes no trace (for speed measurements).
        const bool tracing = std::string(argv[2]) != "-";
        std::ofstream trace;
        if (tracing) trace.open(argv[2]);
        if (tracing && !trace) throw std::runtime_error("cannot open trace");
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
        // Base RAM 000000-09FFFF and expansion RAM 100000h-g_ext_end; the
        // vector also spans the unpopulated A0000-FFFFF, which is_ram()
        // excludes.
        std::vector<uint8_t> ram(std::max<uint32_t>(kRamEnd, g_ext_end), 0);
        uint64_t dma_writes = 0, dma_reads = 0, dma_open = 0;
        const auto wall_start = std::chrono::steady_clock::now();
        uint64_t retired = 0, rom_writes = 0, open_reads = 0, open_writes = 0, cpu_resets = 0;
        uint64_t halt_clocks = 0, inta_cycles = 0, chan_writes = 0;
        bool inta_active = false;
        uint8_t inta_byte = 0;
        bool was_reset = true;   // the power-on reset is not counted
        bool was_a20 = true;     // the 8042 output port resets to FFh: A20 GATE high
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
#ifdef AT_CARD
#ifdef AT_EGA
        // Enhanced Color Display as the primary display in its 350-line
        // mode: SW1 off, SW2 on, SW3 on, SW4 off (1 = off); P1 at pin 2 =
        // secondary red, P3 at the 3xx port addresses.
        d.ega_sw_i = 0x9; d.ega_p1_i = 1; d.ega_p3_i = 1;
        // The six direct-drive bits {r,g,b,R,G,B}: 2/3 and 1/3 intensity.
        auto pixel = [&]() -> uint32_t {
            const unsigned v = d.video_o;
            uint32_t rgb = 0;
            for (int gun = 2; gun >= 0; gun--)
                rgb = (rgb << 8) | (0xAA * ((v >> gun) & 1) + 0x55 * ((v >> (gun + 3)) & 1));
            return rgb;
        };
#else
        // The DAC's 6-bit codes scaled to 8 bits per gun.
        auto pixel = [&]() -> uint32_t {
            auto scale = [](unsigned c) { return (c << 2) | (c >> 4); };
            return (scale(d.r_o) << 16) | (scale(d.g_o) << 8) | scale(d.b_o);
        };
#endif
        d.vid_clk_i = 0;
        // The diskette drives on the adapter's cable. Their time base is the
        // adapter's CLK_HZ, 6 MHz of processor clock (ASSUMPTION AT27).
        at_diskette::Diskettes fd(6000000);
        for (unsigned u = 0; u < 2; u++) {
            if (fd_type[u].empty() && !fd_path[u].empty()) fd_type[u] = "1.2";
            if (fd_type[u] == "1.2") fd.drive[u].type = at_diskette::DriveType::HighCapacity;
            else if (fd_type[u] == "360") fd.drive[u].type = at_diskette::DriveType::DoubleDensity;
            else if (!fd_type[u].empty()) throw std::runtime_error("drive type must be 1.2 or 360");
            if (!fd_path[u].empty()) fd.mount(u, fd_path[u], fd_ro[u]);
        }
        at_diskette::DriveLines fdl;
        auto apply_drive_lines = [&]() {
            d.fd_track0_i = fdl.track0; d.fd_write_protect_i = fdl.write_protect;
            d.fd_change_i = fdl.change; d.fd_index_i = fdl.index; d.fd_header_i = fdl.header;
            d.fd_c_i = fdl.c; d.fd_h_i = fdl.h; d.fd_r_i = fdl.r; d.fd_n_i = fdl.n;
            d.fd_byte_valid_i = fdl.byte_valid; d.fd_byte_i = fdl.byte;
            d.fd_end_i = fdl.end; d.fd_slot_i = fdl.slot;
        };
        apply_drive_lines();
        auto drive_tick = [&]() {
            at_diskette::AdapterLines a;
            a.select = d.fd_select_o; a.motor = d.fd_motor_o; a.step = d.fd_step_o;
            a.direction = d.fd_direction_o; a.head = d.fd_head_o; a.rate = d.fd_rate_o;
            a.active = d.fd_active_o; a.writing = d.fd_write_o; a.formatting = d.fd_format_o;
            a.sector_begin = d.fd_sector_begin_o; a.tx_valid = d.fd_tx_valid_o;
            a.tx_byte = d.fd_tx_byte_o; a.sector_r = d.fd_sector_r_o;
            fdl = fd.tick(a);
            apply_drive_lines();
        };
        uint64_t irq6_rises = 0;
        bool was_irq6 = false;
        std::vector<std::vector<uint32_t>> lines(1), last_frame;
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
            if (d.de_o) lines.back().push_back(pixel());
        };
        // ASSUMPTION AT19: the video clock runs at the processor clock's
        // rate, and the 8254 clock is the channel's OSC / 12 on the same
        // time base (kOscHz / 12 against kVidHz), as on the real board.
        uint64_t timer_acc = 0;
        bool timer_level = false;
#define VID_RISE() do { d.vid_clk_i = 1; } while (0)
#define VID_AFTER() do { video_sample(); } while (0)
#define VID_FALL() do { d.vid_clk_i = 0; } while (0)
#ifdef AT_VGA
// The VGA needs a clock faster than its 28.322 MHz oscillator: two video
// clocks per processor clock (48 MHz on the AT19 time base), the second
// with the falling edge of clk_i.
#define VID_SECOND 1
#else
#define VID_SECOND 0
#endif
#else
#define VID_SECOND 0
#define VID_RISE() do { } while (0)
#define VID_AFTER() do { } while (0)
#define VID_FALL() do { } while (0)
#endif
        auto half_clock = [&](bool rising) {
            d.clk_i = rising; d.clk_2x_i = 1;
            if (rising || VID_SECOND) VID_RISE(); else VID_FALL();
            d.eval();
            if (rising || VID_SECOND) VID_AFTER();
            d.clk_2x_i = 0;
            if (VID_SECOND) VID_FALL();
            d.eval();
        };
        d.eval();
        for (int i = 0; i < 16; i++) { half_clock(true); half_clock(false); }
        d.reset_i = 0;

        F1Stimulus f1;
        uint64_t cycle = 0;
        for (; cycle < cycle_limit && stop.empty(); cycle++) {
            d.ready_n_i = wait ? (cycle % 5 != 4) : 0;
            d.dma_clk_n_i = cycle & 1;
#ifdef AT_CARD
            timer_acc += 2 * (kOscHz / 12);
            if (timer_acc >= kVidHz) { timer_acc -= kVidHz; timer_level = !timer_level; }
            d.timer_clk_i = timer_level ? 7 : 0;
            drive_tick();
            if (d.fd_irq6_o && !was_irq6) ++irq6_rises;
            was_irq6 = d.fd_irq6_o;
#else
            d.timer_clk_i = ((cycle / half) & 1) ? 7 : 0;
#endif
            if (f1_post >= 0 && !f1.armed && d.post_code_o == f1_post && !d.cpu_reset_o && cycle > 64)
                f1.armed = true;
            f1.tick(d.kbd_clk_o, d.kbd_data_o);
            if (klog.is_open() && (d.kbd_clk_i != f1.clk || d.kbd_data_i != f1.data))
                klog << "K " << kbc_started << ' ' << unsigned(f1.clk) << ' ' << unsigned(f1.data) << '\n';
            d.kbd_clk_i = f1.clk; d.kbd_data_i = f1.data;
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
            // During HLDA the address is a DMA (or refresh) address and
            // memory answers it.
            d.mem_rdata_i = (d.io_cycle_o && !d.hlda_o) ? uint16_t(kOpenBus | (kOpenBus << 8))
                                         : uint16_t(byte(base) | (byte(base + 1) << 8));
            const uint32_t port = d.io_port_o;
            const bool empty_slot = d.io_unclaimed_o && port >= 0x100;
            const bool empty_slot_write = empty_slot && d.data_oe_o;
            if (d.io_unclaimed_o && !(empty_slot && (empty_slots || d.data_oe_o))) {
                stop = std::string("kind=io-") + (d.data_oe_o ? "write" : "read") +
                       " port=" + hex(port, 4) + " at=" + where;
                break;
            }
            if (d.io_read_undriven_o) {
                stop = "kind=io-undriven port=" + hex(port, 4) + " at=" + where;
                break;
            }
#ifdef AT_CARD
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

            // A DMA memory transfer commits at this edge. Its record:
            //   D <addr> <byte> <write>   write = 1: DMA stored the byte in
            //   memory; 0: DMA read it from memory (for the device).
            // It is written in time order among the processor's B records.
            if (d.dma_mem_o) {
                const uint8_t value = d.dma_mem_write_o ? uint8_t(d.data_o) : byte(a);
                if (d.dma_mem_write_o) {
                    if (is_ram(a)) ram[a] = value; else ++dma_open;
                    ++dma_writes;
                } else {
                    if (!is_ram(a)) ++dma_open;
                    ++dma_reads;
                }
                if (tracing)
                    trace << "D " << std::hex << a << ' ' << unsigned(value) << ' '
                          << unsigned(d.dma_mem_write_o) << std::dec << '\n';
            }

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
                    if (!fetch && tracing)
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
                if (tracing) trace << "A " << std::hex << unsigned(inta_byte) << std::dec << '\n';
            }
            if (d.cpu_reset_o && !was_reset) {
                ++cpu_resets;
                if (tracing) trace << "Z\n";
            }
            // The 8042's A20 GATE output (P21) changed: G <level>.
            if (d.a20_gate_o != was_a20) {
                was_a20 = d.a20_gate_o;
                if (tracing) trace << "G " << unsigned(was_a20) << '\n';
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
                if (tracing) {
                trace << "R " << std::hex << d.retire_pc_o << ' ' << unsigned(d.retire_opcode_o) << ' '
                      << cur_cs << ' ' << d.ip_o << ' ' << d.flags_o << ' ' << d.segs_o;
                for (unsigned r = 0; r < 8; r++) trace << ' ' << uint16_t(d.regs_o[r / 2] >> ((r % 2) * 16));
                trace << std::dec << '\n';
                }
            }
            VID_AFTER();
            d.clk_2x_i = 0;
            if (VID_SECOND) VID_FALL();
            d.eval();
            half_clock(false);
            if ((stop_post >= 0 && d.post_code_o == stop_post && !d.cpu_reset_o && cycle > 64) ||
                (stop_at >= 0 && d.retire_o && long(d.retire_pc_o) == stop_at)) {
                stop = (stop_at >= 0 ? "kind=stop-at at=" : "kind=post-code at=") + hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
                ++cycle;
                break;
            }
        }
        if (stop.empty()) stop = "kind=cycle-limit at=" + hex(cur_cs, 4) + ":" + hex(cur_ip, 4);
        if (tracing) {
            trace.flush();
            if (!trace) throw std::runtime_error("trace write failed");
        }
        const double wall = std::chrono::duration<double>(std::chrono::steady_clock::now() - wall_start).count();
        if (klog.is_open()) {
            klog.flush();
            if (!klog) throw std::runtime_error("8042 log write failed");
        }
        std::cout << "STOP " << stop << " post=" << hex(d.post_code_o, 2) << " retired=" << retired
                  << " cycles=" << cycle << " kbc_retired=" << kbc_retired << " slot_writes=" << slot_writes << " slot_reads=" << slot_reads << " rom_writes=" << rom_writes << " open_reads=" << open_reads
                  << " open_writes=" << open_writes << " cpu_resets=" << cpu_resets << " inta_cycles=" << inta_cycles << " wait=" << wait
                  << " half=" << half << '\n';
        std::cout << "DMA mem_writes=" << dma_writes << " mem_reads=" << dma_reads
                  << " unpopulated=" << dma_open << " ext_kb=" << ext_kb << '\n';
        std::cout << "SPEED wall_seconds=" << wall << " clocks_per_second="
                  << uint64_t(wall > 0 ? double(cycle) / wall : 0) << " trace=" << (tracing ? 1 : 0)
                  << '\n';
#ifdef AT_CARD
        std::cout << "DISKETTE ids=" << fd.ids << " media_reads=" << fd.media_reads
                  << " media_writes=" << fd.media_writes << " steps=" << fd.steps
                  << " irq6=" << irq6_rises << " f1_bytes=" << f1.sent << " f1_retries=" << f1.retries
                  << " head_a=" << fd.drive[0].position << " head_b=" << fd.drive[1].position << '\n';
        for (unsigned u = 0; u < 2; u++)
            if (write_back && !fd_path[u].empty() && fd.drive[u].dirty) {
                fd.save(u, fd_path[u]);
                std::cout << "DISKETTE wrote " << fd_path[u] << '\n';
            }
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
                        const uint32_t v = x < last_frame[y].size() ? last_frame[y][x] : 0;
                        ppm.put(char(v >> 16)); ppm.put(char(v >> 8)); ppm.put(char(v));
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
