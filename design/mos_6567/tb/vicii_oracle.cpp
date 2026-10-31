// Oracle adapter: compiles the unchanged, pinned MAME mos6566.cpp/.h
// (BSD-3-Clause, Curt Coder) against tb/mame_stubs. Access specifiers are
// widened by macro only so the harness can observe state; no source line
// of the reference is edited. Per call the adapter runs exactly one
// execute_run() iteration (one system clock) and records:
//   - each display-memory fetch address in order (phase 1 and phase 2);
//   - every output_stage pixel (row, column, color index via an identity
//     palette) in drawing order;
//   - IRQ, BA and AEC line levels.
#include <cstdint>
#include <cstdio>
#include <deque>
#include <vector>

#define private public
#define protected public
#include "mos6566.cpp"
#undef private
#undef protected

namespace {
struct pixel_record {
    int row, col;
    uint32_t color;
};

struct instance {
    mos6566_device *device = nullptr;
    std::vector<unsigned> fetches;
    std::deque<pixel_record> pixels;
    const uint8_t *video = nullptr;
    const uint8_t *color = nullptr;
    int rom_window = 0;
};

instance instances[2];
const machine_config config;
const rgb_t identity[16] = {
    rgb_t(0, 0, 0), rgb_t(0, 0, 1), rgb_t(0, 0, 2), rgb_t(0, 0, 3),
    rgb_t(0, 0, 4), rgb_t(0, 0, 5), rgb_t(0, 0, 6), rgb_t(0, 0, 7),
    rgb_t(0, 0, 8), rgb_t(0, 0, 9), rgb_t(0, 0, 10), rgb_t(0, 0, 11),
    rgb_t(0, 0, 12), rgb_t(0, 0, 13), rgb_t(0, 0, 14), rgb_t(0, 0, 15)};

mos6566_device *create(int variant) {
    switch (variant) {
    case 0: return new mos6569_device(config, "vic", nullptr, 985248);
    case 1: return new mos6567_device(config, "vic", nullptr, 1022727);
    case 2: return new mos6567r56a_device(config, "vic", nullptr, 1022727);
    case 3: return new mos8565_device(config, "vic", nullptr, 985248);
    default: return new mos8562_device(config, "vic", nullptr, 1022727);
    }
}
}

extern "C" {
// variant: 0 6569, 1 6567 (R8), 2 6567R56A, 3 8565, 4 8562.
// rom_window: the board maps character ROM at VIC $1000-$1FFF.
void vicii_init(int which, int variant, const uint8_t *video, const uint8_t *color, int rom_window) {
    instance &in = instances[which & 1];
    delete in.device;
    in = instance{};
    in.video = video;
    in.color = color;
    in.rom_window = rom_window;
    in.device = create(variant);
    mos6566_device &d = *in.device;
    d.set_palette(identity);
    d.m_videoram.reader = [&in](offs_t a) {
        in.fetches.push_back(a & 0x3fff);
        return in.video[a & 0x3fff];
    };
    d.m_colorram.reader = [&in](offs_t a) { return in.color[a & 0x3ff]; };
    d.m_read_charrom.reader = [&in](offs_t a) -> uint8_t {
        return (in.rom_window && (a & 0x3000) == 0x1000) ? 1 : 0;
    };
    d.m_bitmap.on_write = [&in](int row, int col) -> uint32_t & {
        in.pixels.push_back({row, col, 0});
        return in.pixels.back().color;
    };
    d.device_start();
    d.device_reset();
}

void vicii_set_rom_window(int which, int rom_window) { instances[which & 1].rom_window = rom_window; }

// Light-pen level, then one execute_run iteration.
void vicii_clock(int which, int lightpen_level) {
    instance &in = instances[which & 1];
    in.fetches.clear();
    in.device->lp_w(lightpen_level);
    in.device->m_icount = 1;
    in.device->execute_run();
}

unsigned vicii_read(int which, unsigned reg) { return instances[which & 1].device->read(reg); }
void vicii_write(int which, unsigned reg, unsigned data) {
    instances[which & 1].device->write(reg, uint8_t(data));
}
unsigned vicii_fetch_count(int which) { return unsigned(instances[which & 1].fetches.size()); }
unsigned vicii_fetch(int which, unsigned index) { return instances[which & 1].fetches.at(index); }
int vicii_irq(int which) { return instances[which & 1].device->m_irq_out; }
int vicii_ba(int which) { return instances[which & 1].device->m_ba; }
int vicii_aec(int which) { return instances[which & 1].device->m_aec; }
int vicii_cycle(int which) { return instances[which & 1].device->m_cycle; }
int vicii_rasterline(int which) { return instances[which & 1].device->m_rasterline; }
// Pixel stream in drawing order (identity palette: value = color index).
unsigned vicii_pixel_count(int which) { return unsigned(instances[which & 1].pixels.size()); }
int vicii_pixel_pop(int which, int *row, int *col) {
    instance &in = instances[which & 1];
    const pixel_record p = in.pixels.front();
    in.pixels.pop_front();
    *row = p.row;
    *col = p.col;
    return int(p.color);
}
}
