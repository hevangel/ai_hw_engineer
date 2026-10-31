/*
 * Service adapter for the unchanged floooh/chips PAL VIC implementation.
 *
 * Source: floooh/chips commit 9e88298ce56319953ac7a43213a1120359f7a3a6.
 * Run scripts/fetch_raster_reference.py first; it verifies both original
 * headers and leaves their original zlib/libpng license notices intact.
 * No raster transition or register-read formula is reimplemented here.
 *
 * Compile as C, then link this object with the C++ simulation harness:
 *   cc -std=c11 -O2 -Wall -Wextra -Werror \
 *      -Idesign/mos_6560/work/raster-reference \
 *      -c design/mos_6560/tb/pal_raster_oracle.c \
 *      -o design/mos_6560/work/pal_raster_oracle.o
 *
 * API (C linkage):
 *   void pal_raster_oracle_init(void);
 *   void pal_raster_oracle_reset(void);
 *   unsigned pal_raster_oracle_tick(unsigned selected, unsigned read,
 *                                   unsigned reg, unsigned data);
 *   unsigned pal_raster_oracle_h_count(void);
 *   unsigned pal_raster_oracle_v_count(void);
 *   unsigned pal_raster_oracle_read3(void);
 *   unsigned pal_raster_oracle_read4(void);
 *
 * tick performs one genuine model bus access and one PAL CPU-clock tick.
 * The returned byte is the bus value BEFORE the model advances the raster.
 * selected is the already-decoded virtual CS; reg uses its low four bits.
 * h_count/v_count inspect the current model state AFTER prior ticks.
 * read3/read4 sample the genuine bus path on a private state copy, so they
 * do not consume a tick or change the live model. No clocks should be
 * inserted into the reference while the RTL's clock-enable is disabled.
 *
 * Only the PAL raster and register readback are qualified by this adapter.
 * The required memory-fetch callback supplies zero and the model owns a
 * full-sized backing framebuffer. Neither pixels/fetches nor analog sound,
 * POT, light pen, NTSC timing or a full VIC-20 are verified by that fixture.
 */
#include <assert.h>
#include <stdint.h>
#include <string.h>

#define CHIPS_IMPL
#include "chips_common.h"
#include "m6561.h"

static m6561_t pal_vic;
static uint8_t pal_framebuffer[M6561_FRAMEBUFFER_SIZE_BYTES];
static uint8_t sample_framebuffer[M6561_FRAMEBUFFER_SIZE_BYTES];
static int initialized;

static uint16_t fetch_zero(uint16_t address, void *user_data)
{
    (void)address;
    (void)user_data;
    return 0;
}

static uint64_t bus_pins(unsigned selected, unsigned read,
                         unsigned reg, unsigned data)
{
    uint64_t pins = reg & M6561_REG_MASK;
    if (selected) {
        pins |= M6561_CS;
    }
    if (read) {
        pins |= M6561_RW;
    }
    M6561_SET_DATA(pins, data & 0xffu);
    return pins;
}

void pal_raster_oracle_init(void)
{
    const m6561_desc_t desc = {
        .framebuffer = { .ptr = pal_framebuffer,
                         .size = sizeof(pal_framebuffer) },
        .screen = { .x = 0, .y = 0, .width = 512, .height = 320 },
        .fetch_cb = fetch_zero,
        .user_data = 0,
        /* Required audio service rates, not an oscillator qualification. */
        .tick_hz = 1108405,
        .sound_hz = 44100,
        .sound_magnitude = 0.0f,
    };
    memset(pal_framebuffer, 0, sizeof(pal_framebuffer));
    m6561_init(&pal_vic, &desc);
    initialized = 1;
}

void pal_raster_oracle_reset(void)
{
    assert(initialized);
    m6561_reset(&pal_vic);
}

unsigned pal_raster_oracle_tick(unsigned selected, unsigned read,
                                unsigned reg, unsigned data)
{
    assert(initialized);
    return M6561_GET_DATA(m6561_tick(&pal_vic,
        bus_pins(selected, read, reg, data)));
}

unsigned pal_raster_oracle_h_count(void)
{
    assert(initialized);
    return pal_vic.rs.h_count;
}

unsigned pal_raster_oracle_v_count(void)
{
    assert(initialized);
    return pal_vic.rs.v_count;
}

static unsigned sample_read(unsigned reg)
{
    assert(initialized);
    m6561_t sample = pal_vic;
    sample.crt.fb = sample_framebuffer;
    return M6561_GET_DATA(m6561_tick(&sample, bus_pins(1, 1, reg, 0)));
}

unsigned pal_raster_oracle_read3(void)
{
    return sample_read(3);
}

unsigned pal_raster_oracle_read4(void)
{
    return sample_read(4);
}
