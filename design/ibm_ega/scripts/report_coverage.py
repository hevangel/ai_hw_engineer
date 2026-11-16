#!/usr/bin/env python3
"""Coverage gate for the IBM EGA lockstep runs (model counters).

usage: report_coverage.py COV.json... [--require] [--bios-dir DIR]

Sums the model's coverage counters and checks that every register was
written, every documented bit of every register was written as 0 and as 1,
every write mode, read mode, read map select, memory map, odd/even and
chain combination, Input Status/CRTC readback, switch-sense position,
video-status mux setting, attribute/graphics/clocking mode, skew, panning
value and CRTC feature (line compare, light pen, vertical interrupt, ...)
was exercised. With --bios-dir, every BIOS VIDEO_PARMS entry must have
been run (documented modes). With --require, exits 1 on any hole.
"""
import json
import os
import sys

REG_BITS = {}
for i, m in enumerate([0x03, 0x0F, 0x0F, 0x0F, 0x07]):
    REG_BITS['seq%d' % i] = m
for i in range(25):
    REG_BITS['crtc%02x' % i] = 0xFF
for i, m in enumerate([0x0F, 0x0F, 0x0F, 0x1F, 0x07, 0x3F, 0x0F, 0x0F, 0xFF]):
    REG_BITS['gc%d' % i] = m
for i in range(16):
    REG_BITS['pal%x' % i] = 0x3F
REG_BITS.update({'attr10': 0x0F, 'attr11': 0x3F, 'attr12': 0x3F, 'attr13': 0x0F,
                 'misc': 0xFF, 'fcr': 0x03})

REQUIRED = (
    ['write_mode%d' % i for i in range(4)] + ['read_mode1', 'set_reset_used'] +
    ['fn_%d' % i for i in range(4)] +
    ['ram_write_map%d_oe%d' % (m, o) for m in range(4) for o in range(2)] +
    ['ram_read_map%d' % m for m in range(4)] + ['chain_0'] +
    ['io_r_isr0', 'io_r_isr1', 'io_r_crtc', 'crtc_read_0c', 'crtc_read_0d',
     'crtc_read_0e', 'crtc_read_0f', 'crtc_read_lp', 'crtc_read_wo',
     'io_read_writeonly', 'io_write_undecoded', 'mem_dack0_blocked', 'rom_read',
     'attr_write_3c1'] +
    ['sw_read_%d_%d' % (k, v) for k in range(4) for v in range(2)] +
    ['diag_mux_%d' % m for m in range(4)] +
    ['amode_text', 'amode_gfx', 'amode_bit1', 'amode_bit2', 'amode_bit3',
     'cursor_char', 'underline_row', 'gc_shift0_sl0', 'gc_shift1_sl0',
     'clock_w8_div0', 'clock_w8_div1', 'clock_w9_div0', 'clock_w9_div1'] +
    ['skew_%d' % i for i in range(4)] + ['cskew_%d' % i for i in range(4)] +
    ['hdelay_%d' % i for i in range(4)] +
    ['line_compare_hit', 'frame_start', 'vretrace_start', 'vint_set', 'lp_latch',
     'start_odd', 'count_by_two', 'hrtc_div2', 'crtc_word_mode', 'charmap_A',
     'pal_write_ignored'] +
    ['font_fetch_map%d' % m for m in range(4)] +
    ['gc1pos_%d' % p for p in range(4)] + ['gc2pos_%d' % p for p in range(4)])

ANY_OF = {
    'read map select 0-7 (read mode 0)': [['read_mode0_rms%d_oe0' % m, 'read_mode0_rms%d_oe1' % m]
                                          for m in range(8)],
    'chain with the page bit (maps 1-3)': [['chain_1', 'chain_2', 'chain_3']],
    'shift load (Clocking bit 2)': [['gc_shift0_sl1', 'gc_shift1_sl1']],
    'panning values 1-15': [['pan_%d_w8' % p, 'pan_%d_w9' % p] for p in range(1, 16)],
}

BIOS_ENTRIES = ['entry%02x' % n for n in range(23)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    bios_dir = None
    if '--bios-dir' in sys.argv:
        bios_dir = sys.argv[sys.argv.index('--bios-dir') + 1]
        args = [a for a in args if a != bios_dir]
    total = {}
    for f in args:
        for k, v in json.load(open(f)).items():
            total[k] = total.get(k, 0) + v
    holes = []
    nbits = 0
    for name, mask in REG_BITS.items():
        if not total.get('w_' + name):
            holes.append('write ' + name)
        for b in range(8):
            if not (mask >> b) & 1:
                continue
            for v in (0, 1):
                nbits += 1
                if not total.get('wb_%s_%d_%d' % (name, b, v)):
                    holes.append('%s.%d=%d' % (name, b, v))
    print('registers: %d; documented register bit values: %d required'
          % (len(REG_BITS), nbits))
    for k in REQUIRED:
        if not total.get(k):
            holes.append(k)
    for what, groups in ANY_OF.items():
        for g in groups:
            if not any(total.get(k) for k in g):
                holes.append('%s: %s' % (what, '/'.join(g)))
    if bios_dir:
        for e in BIOS_ENTRIES:
            if not os.path.exists(os.path.join(bios_dir, e + '.cov')):
                holes.append('BIOS mode table ' + e)
    shown = ['write_mode0', 'write_mode1', 'write_mode2', 'write_mode3', 'read_mode1',
             'line_compare_hit', 'vint_set', 'lp_latch', 'cursor_char', 'underline_row',
             'frame_start']
    print('  ' + ', '.join('%s %d' % (k, total.get(k, 0)) for k in shown))
    if holes:
        print('coverage holes (%d): %s' % (len(holes), ' '.join(holes[:60])))
    if '--require' in sys.argv and holes:
        print('FAIL: coverage')
        sys.exit(1)
    print('PASS: coverage' if not holes else 'NOTE: coverage holes')


if __name__ == '__main__':
    main()
