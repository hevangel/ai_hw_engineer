// Display/bus/light-pen/sound adapter for unmodified, pinned MAME VIC code.
// MAME source: BSD-3-Clause, copyright Curt Coder. scripts/fetch_ntsc_reference.py
// extracts the exact function bodies into ignored work/ntsc-reference.
// Only the service types below are authored in this project:
//   - memory reads record each display fetch and return harness memory;
//   - the bitmap records the four colors of the latest output_pixels call;
//   - an identity palette/DAC exposes color indices and DAC table indices;
//   - update_cycles is inert because this adapter advances cycles itself.
// The Attack UFO variant, analog DAC curve, palette RGB values and MAME's
// stream timing are not qualified by this adapter.
#include <algorithm>
#include <cmath>
#include <cstdint>

#define BIT(value, bit) (((value) >> (bit)) & 1)

typedef uint32_t offs_t;
typedef uint32_t rgb_t;

namespace {
// Two independent instances (index 0 PAL, 1 NTSC); services use ctive.
struct instance_services {
    unsigned fetch_count;
    unsigned fetch_addr;
    bool fetch_matrix;
    bool fetching_matrix;
    const uint8_t *video_memory;
    const uint8_t *color_memory;
    // Both double-buffer bitmaps record into the same latest pixel group.
    uint32_t latest_pixels[4];
    unsigned level;
    bool sample;
};
instance_services services[2];
instance_services *active = &services[0];
}

struct bitmap_rgb32 {
    int height() const { return 1 << 20; }
    int width() const { return 1 << 20; }
    uint32_t &pix(int, int) { return active->latest_pixels[0]; }
};

struct sound_stream {
    using sample_t = float;
    sample_t value = 0;
    int samples() const { return 1; }
    void put(int, int, sample_t v) { value = v; }
    void update() {}
};

struct video_space {
    uint8_t read_byte(offs_t addr) {
        active->fetch_count++;
        active->fetch_addr = addr;
        active->fetch_matrix = active->fetching_matrix;
        return active->video_memory[addr & 0x3fff];
    }
};

struct color_space {
    uint8_t read_byte(offs_t addr) { return active->color_memory[addr & 0x3ff]; }
};

struct pot_reader {
    uint8_t value = 0xff;
    uint8_t operator()(int) const { return value; }
};

class mos6560_device {
public:
    enum : uint8_t {
        AREA_IDLE, AREA_PENDING, AREA_DISPLAY, AREA_DONE,
    };
    enum : uint8_t {
        FETCH_IDLE, FETCH_START, FETCH_MATRIX, FETCH_CHARGEN, FETCH_DONE,
    };

    // Deterministic startup fixture matching device_start's assignments.
    void platform_init(bool ntsc) {
        *this = mos6560_device{};
        m_ntsc = ntsc;
        m_interlace_capable = ntsc;
        m_cycles_per_line = ntsc ? 65 : 71;
        m_lines = ntsc ? 261 : 312;
        m_frame_lines = m_lines;
        m_raster_offset = ntsc ? 37 : 0;
        for (unsigned i = 0; i < 16; i++) identity_palette[i] = i;
        m_palette = identity_palette;
        for (unsigned i = 0; i < sizeof(m_dac) / sizeof(m_dac[0]); i++)
            m_dac[i] = float(i);
        m_stream = &stream;
    }

    void device_reset();
    int raster_line(uint64_t cycle, int *pos = nullptr) const;
    int last_line_cycles(int line) const;
    void open_v();
    void close_v();
    void open_h();
    void handle_vmc();
    void count_vmc();
    void end_of_line();
    void end_of_frame();
    uint8_t fetch_byte(offs_t addr);
    void fetch();
    void output_pixels();
    void trigger_light_pen();
    void cycle();
    uint8_t read(offs_t offset);
    void write(offs_t offset, uint8_t data);
    void lp_w(int state);
    void sound_stream_update(sound_stream &stream);

    void update_cycles() {}
    bool started() const { return true; }

    sound_stream stream;
    uint32_t identity_palette[16] = {};

    int m_cycles_per_line = 65;
    int m_lines = 261;
    int m_raster_offset = 37;
    const rgb_t *m_palette = nullptr;
    bool m_ntsc = true;
    bool m_interlace_capable = true;
    bool m_attack_ufo = false;
    pot_reader m_read_potx;
    pot_reader m_read_poty;
    video_space m_videoram;
    color_space m_colorram;
    sound_stream *m_stream = nullptr;
    bitmap_rgb32 m_bitmap[2];
    int32_t m_draw = 0;
    uint64_t m_cycle_count = 0;
    uint64_t m_frame_start = 0;
    int32_t m_frame_lines = 261;
    uint8_t m_reg[16] = {};
    int32_t m_line = 0;
    int32_t m_cyc = 0;
    uint8_t m_area = AREA_IDLE;
    uint8_t m_fetch_state = FETCH_IDLE;
    int32_t m_start_delay = 0;
    int32_t m_buf_offset = 0;
    int32_t m_text_cols = 0;
    int32_t m_pending_text_cols = 0;
    int32_t m_text_lines = 0;
    int32_t m_char_height = 8;
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
    uint8_t m_vbuf = 0;
    uint8_t m_cbuf = 0;
    uint8_t m_gload[3] = {};
    uint8_t m_cload[3] = {};
    bool m_load[3] = {};
    uint8_t m_gdata = 0;
    uint8_t m_cdata = 0;
    int32_t m_shift_pos = 8;
    uint8_t m_vbus = 0;
    uint8_t m_vbus_high = 0;
    uint8_t m_out_bg = 0;
    uint8_t m_out_border = 0;
    uint8_t m_out_aux = 0;
    bool m_out_reverse = false;
    int32_t m_pend_reg = -1;
    uint8_t m_pend_data = 0;
    bool m_lp_state = false;
    bool m_lp_triggered = false;
    uint64_t m_lp_trigger = ~uint64_t(0);
    uint8_t m_lp_x = 0;
    uint8_t m_lp_y = 0;
    uint8_t m_lp_extra = 1;
    uint8_t m_snd_div = 0;
    uint8_t m_snd_cnt[4] = {};
    uint8_t m_snd_sreg[4] = {};
    uint16_t m_noise_lfsr = 0;
    bool m_noise_lfsr0 = false;
    sound_stream::sample_t m_dac[(4 * 7 + 1) * 15 + 1] = {};
};

// Generated from the hash-checked original source; bodies are unchanged.
#include "mame_display_functions.inc"

namespace {
mos6560_device references[2];
mos6560_device &select(int which) {
    active = &services[which & 1];
    return references[which & 1];
}
}

extern "C" {
void vic_display_init(int which, int ntsc, const uint8_t *video, const uint8_t *color) {
    mos6560_device &reference = select(which);
    *active = instance_services{};
    active->video_memory = video;
    active->color_memory = color;
    reference.platform_init(ntsc != 0);
}

// One system clock: the light-pen level is applied before the cycle, then
// the original cycle and a half-rate sound sample run. Register reads must
// be taken before this call and register writes applied after it.
void vic_display_clock(int which, int lightpen_level) {
    mos6560_device &reference = select(which);
    reference.lp_w(lightpen_level);
    active->fetch_count = 0;
    active->fetching_matrix = reference.m_fetch_state == mos6560_device::FETCH_MATRIX;
    reference.cycle();
    active->sample = (reference.m_cycle_count & 1) != 0;
    ++reference.m_cycle_count;
    if (active->sample) {
        reference.sound_stream_update(reference.stream);
        active->level = unsigned(reference.stream.value);
    }
}

// Light-pen level change while the display clock is held.
void vic_display_lightpen(int which, int level) { select(which).lp_w(level); }
void vic_display_write(int which, unsigned reg, unsigned data) {
    select(which).write(reg, uint8_t(data));
}
unsigned vic_display_read(int which, unsigned reg) { return select(which).read(reg); }
void vic_display_pots(int which, unsigned x, unsigned y) {
    mos6560_device &reference = select(which);
    reference.m_read_potx.value = uint8_t(x);
    reference.m_read_poty.value = uint8_t(y);
}
unsigned vic_display_fetch_count(int which) { select(which); return active->fetch_count; }
unsigned vic_display_fetch_addr(int which) { select(which); return active->fetch_addr & 0x3fff; }
unsigned vic_display_fetch_matrix(int which) { select(which); return active->fetch_matrix ? 1 : 0; }
unsigned vic_display_pixels(int which) {
    select(which);
    const uint32_t *p = active->latest_pixels;
    return p[0] | (p[1] << 4) | (p[2] << 8) | (p[3] << 12);
}
unsigned vic_display_sample(int which) { select(which); return active->sample ? 1 : 0; }
unsigned vic_display_level(int which) { select(which); return active->level; }
int vic_display_h(int which) { return select(which).m_cyc; }
int vic_display_line(int which) { return select(which).m_line; }
int vic_display_frame_lines(int which) { return select(which).m_frame_lines; }
int vic_display_lightpen_x(int which) { return select(which).m_lp_x; }
int vic_display_area(int which) { return select(which).m_area; }
int vic_display_lightpen_extra(int which) { return select(which).m_lp_extra; }
}