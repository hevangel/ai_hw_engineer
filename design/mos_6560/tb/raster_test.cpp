#include "Vraster_pair.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

extern "C" {
void pal_raster_oracle_init(void);
void pal_raster_oracle_reset(void);
unsigned pal_raster_oracle_tick(unsigned, unsigned, unsigned, unsigned);
unsigned pal_raster_oracle_h_count(void);
unsigned pal_raster_oracle_v_count(void);
unsigned pal_raster_oracle_read3(void);
unsigned pal_raster_oracle_read4(void);
void vic_mame_init(int);
void vic_mame_tick(int);
int vic_mame_h(void);
int vic_mame_line(void);
int vic_mame_frame_lines(void);
int vic_mame_field(void);
int vic_mame_interlace(void);
int vic_mame_raster(void);
int vic_mame_raster_pos(void);
}

static Vraster_pair dut;
static uint64_t clocks, comparisons, records;
static unsigned low3;
static FILE *vectors;
static unsigned disabled_fields[2], entered_interlace;

static uint64_t expected(bool pal) {
    const unsigned h = pal ? pal_raster_oracle_h_count() : vic_mame_h();
    const unsigned line = pal ? pal_raster_oracle_v_count() : vic_mame_line();
    const unsigned raster = pal ? pal_raster_oracle_read4()*2 +
                                 (pal_raster_oracle_read3() >> 7) : vic_mame_raster();
    const unsigned pos = pal ? h : vic_mame_raster_pos();
    const unsigned lines = pal ? 312 : vic_mame_frame_lines();
    const unsigned field = pal ? 0 : vic_mame_field();
    const unsigned lace = pal ? 0 : vic_mame_interlace();
    const bool line_end = dut.rst_n && dut.ce_i && h == (pal ? 70u : 64u);
    const bool frame_end = line_end && line == lines-1;
    const bool oe = dut.rst_n && dut.phi2_i && dut.rw_i &&
                    dut.addr_i >= 0x1000 && dut.addr_i <= 0x10ff;
    unsigned data = 0;
    if (oe) {
        const unsigned reg = dut.addr_i & 15;
        if (pal) data = reg == 3 ? pal_raster_oracle_read3() : pal_raster_oracle_read4();
        else data = reg == 3 ? ((raster & 1) << 7) | low3 : raster >> 1;
    }
    return uint64_t(h) | (uint64_t(line) << 7) | (uint64_t(raster) << 16) |
           (uint64_t(pos) << 25) | (uint64_t(lines) << 32) |
           (uint64_t(field) << 41) | (uint64_t(lace) << 42) |
           (uint64_t(line_end) << 43) | (uint64_t(frame_end) << 44) |
           (uint64_t(data) << 45) | (uint64_t(oe) << 53);
}

static void step(bool reset, bool enable, bool request, bool record) {
    dut.clk = 0;
    dut.rst_n = !reset;
    dut.ce_i = enable;
    dut.interlace_i = request;
    // All stalls retain timing. CPU-bus writes are only applied on enabled
    // clocks so the unchanged PAL tick samples the same actual transaction.
    dut.phi2_i = clocks % 19 != 0;
    dut.rw_i = !enable || clocks % 131 != 0;
    dut.addr_i = 0x1000 | ((clocks & 15) << 4) | ((!dut.rw_i || (clocks & 1)) ? 3 : 4);
    dut.data_i = (clocks >> 3) & 255;
    dut.eval();
    const uint64_t pal = expected(true), ntsc = expected(false);
    if (dut.pal_state_o != pal || dut.ntsc_state_o != ntsc) {
        std::fprintf(stderr, "raster mismatch clock=%llu pal=%llx/%llx ntsc=%llx/%llx\n",
            (unsigned long long)clocks, (unsigned long long)dut.pal_state_o,
            (unsigned long long)pal, (unsigned long long)dut.ntsc_state_o,
            (unsigned long long)ntsc);
        std::exit(1);
    }
    comparisons += 2;
    if (record) {
        std::fprintf(vectors, "%x %x %x %x %x %x %x %llx %llx\n",
            unsigned(dut.rst_n), unsigned(dut.ce_i), unsigned(dut.interlace_i),
            unsigned(dut.phi2_i), unsigned(dut.rw_i), unsigned(dut.addr_i),
            unsigned(dut.data_i), (unsigned long long)pal, (unsigned long long)ntsc);
        records++;
    }
    dut.clk = 1;
    dut.eval();
    if (reset) {
        pal_raster_oracle_reset();
        vic_mame_init(1);
        low3 = 0;
    } else if (enable) {
        pal_raster_oracle_tick(dut.phi2_i, dut.rw_i, dut.addr_i & 15, dut.data_i);
        vic_mame_tick(request);
        if (dut.phi2_i && !dut.rw_i) low3 = dut.data_i & 127;
    }
    clocks++;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 2 || !(vectors = std::fopen(argv[1], "w"))) return 2;
    pal_raster_oracle_init();
    vic_mame_init(1);
    // Initialize before comparing uninitialized DUT state. Subsequent reset
    // cycles are checked normally, including reset asserted mid-frame.
    dut.rst_n = 0; dut.clk = 0; dut.eval(); dut.clk = 1; dut.eval();
    step(true, false, false, true);
    for (unsigned c = 0; c < 71*312*6; c++)
        step(false, c % 127 != 0, (c / 499) & 1, true);
    step(true, true, true, true);
    step(true, false, false, true);
    // Enable and disable NTSC interlace at every possible horizontal phase
    // on the last line. Each case crosses 261/263/262-line frames and returns
    // to progressive. PAL runs concurrently and must ignore the request.
    for (unsigned exit_field = 0; exit_field < 2; exit_field++) {
        for (unsigned phase = 0; phase < 65; phase++) {
            step(true, false, false, false);
            bool request = false;
            unsigned frames = 0;
            while (frames < 3 + exit_field) {
                const unsigned h = vic_mame_h(), line = vic_mame_line();
                const unsigned lines = vic_mame_frame_lines();
                if (line == lines-1 && h == phase) {
                    if (frames == 0) request = true;
                    if (frames == 1 + exit_field) request = false;
                }
                const bool end = h == 64 && line == lines-1;
                if (end && frames == 0) entered_interlace++;
                if (end && frames == 1 + exit_field) {
                    if (!vic_mame_interlace() || unsigned(vic_mame_field()) != exit_field)
                        std::abort();
                    disabled_fields[exit_field]++;
                }
                // Only contiguous initial/final runs are recorded. The sweep
                // remains fully checked here and is bracketed by resets.
                step(false, true, request, false);
                if (end) frames++;
            }
        }
    }
    if (entered_interlace != 130 || disabled_fields[0] != 65 || disabled_fields[1] != 65)
        std::abort();
    // Record additional genuine interlace transitions for four-state replay.
    step(true, false, false, false);
    step(true, false, false, true);
    // One-clock requests just after EOF must not enable interlace.
    for (unsigned c = 0; c < 65*261*2; c++) {
        const bool late_pulse = vic_mame_h() == 0 && vic_mame_line() == 0;
        step(false, true, late_pulse, true);
        if (vic_mame_interlace()) std::abort();
    }
    for (unsigned c = 0; c < 65*264*5; c++)
        step(false, true, c < 65*264*4, true);
    std::fclose(vectors);
    std::printf("MOS 6560 RASTER ORACLE PASS: %llu clocks, %llu profile comparisons, %llu replay records, 65 interlace phases per exit field\n",
        (unsigned long long)clocks, (unsigned long long)comparisons,
        (unsigned long long)records);
}
