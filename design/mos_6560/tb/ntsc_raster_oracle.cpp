// Independent raster adapter for the unmodified, pinned MAME implementation.
// MAME source: BSD-3-Clause, copyright Curt Coder. The original sources and
// exact extracted functions are fetched into ignored work/ntsc-reference.
// Only the adapter below is authored in this project. It does not qualify
// video fetches, pixels, audio, light-pen capture, or physical sync waveforms.
#include <algorithm>
#include <cstdint>

#define BIT(value, bit) (((value) >> (bit)) & 1)

class mos6560_device {
public:
    enum : uint8_t {
        AREA_IDLE, AREA_PENDING, AREA_DISPLAY, AREA_DONE,
    };
    enum : uint8_t {
        FETCH_IDLE, FETCH_START, FETCH_MATRIX, FETCH_CHARGEN, FETCH_DONE,
    };

    // This is an explicit deterministic startup fixture, corresponding to
    // device_start's timing/register assignments. MAME device_reset does not
    // reset raster state; its original function is extracted separately.
    void platform_init(bool ntsc) {
        *this = mos6560_device{};
        m_ntsc = ntsc;
        m_interlace_capable = ntsc;
        m_cycles_per_line = ntsc ? 65 : 71;
        m_lines = ntsc ? 261 : 312;
        m_frame_lines = m_lines;
        m_raster_offset = ntsc ? 37 : 0;
    }

    void device_reset();
    int raster_line(uint64_t cycle, int *pos = nullptr) const;
    int last_line_cycles(int line) const;
    void end_of_line();
    void end_of_frame();
    void cycle();

    // Deliberately inert services outside this adapter's raster scope.
    // None changes m_cyc, m_line, m_frame_start, m_frame_lines, m_field,
    // m_interlace, or m_cycle_count. The original cycle() controls them.
    void open_v() {}
    void open_h() {}
    void handle_vmc() {}
    void trigger_light_pen() {}
    void fetch() {}
    void count_vmc() {}
    void output_pixels() {}

    int m_cycles_per_line = 65;
    int m_lines = 261;
    int m_raster_offset = 37;
    bool m_ntsc = true;
    bool m_interlace_capable = true;
    bool m_attack_ufo = false;
    uint64_t m_cycle_count = 0;
    uint64_t m_frame_start = 0;
    int32_t m_frame_lines = 261;
    uint8_t m_reg[16] = {};
    int32_t m_line = 0;
    int32_t m_cyc = 0;
    uint8_t m_area = AREA_IDLE;
    uint8_t m_fetch_state = FETCH_IDLE;
    int32_t m_pending_text_cols = 0;
    int32_t m_text_lines = 0;
    int32_t m_ycounter = 0;
    int32_t m_row_counter = 0;
    int32_t m_vmc = 0;
    int32_t m_vmb = 0;
    int32_t m_vmc_left = 0;
    bool m_vmc_inc = false;
    bool m_vmc_wrap_inc = false;
    bool m_blank_this_line = true;
    bool m_line_was_blank = true;
    bool m_interlace = false;
    int32_t m_field = 0;
    int32_t m_draw = 0;
    bool m_lp_state = false;
    bool m_lp_triggered = false;
    uint64_t m_lp_trigger = ~uint64_t(0);
};

// Generated from the hash-checked original source. All six bodies retain
// their upstream text and source order within each selected function.
#include "mame_raster_functions.inc"

namespace {
mos6560_device reference;
}

extern "C" {
void vic_mame_init(int ntsc) {
    reference.platform_init(ntsc != 0);
}

// Request is the register-0 bit already visible during this modeled cycle.
// MAME samples it inside end_of_frame, not on the write itself. Callers must
// preserve their CPU-write versus cycle ordering at a coincident boundary.
void vic_mame_tick(int interlace_request) {
    reference.m_reg[0] = interlace_request ? 0x80 : 0;
    reference.cycle();
    ++reference.m_cycle_count;
}

void vic_mame_device_reset() { reference.device_reset(); }
int vic_mame_h() { return reference.m_cyc; }
int vic_mame_line() { return reference.m_line; }
int vic_mame_frame_lines() { return reference.m_frame_lines; }
int vic_mame_field() { return reference.m_field; }
int vic_mame_interlace() { return reference.m_interlace ? 1 : 0; }
int vic_mame_raster() { return reference.raster_line(reference.m_cycle_count); }
int vic_mame_raster_pos() {
    int pos = 0;
    reference.raster_line(reference.m_cycle_count, &pos);
    return pos;
}
int vic_mame_last_line_cycles(int line) {
    return reference.last_line_cycles(line);
}
uint64_t vic_mame_cycle_count() { return reference.m_cycle_count; }
}
