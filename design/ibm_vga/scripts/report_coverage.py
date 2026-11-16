#!/usr/bin/env python3
"""Coverage gate for the IBM VGA lockstep runs (model counters).

usage: report_coverage.py COV.json... [--require] [--bios-dir DIR]

Sums the model's coverage counters and checks that every register was
written, every documented bit of every register was written as 0 and as 1
(sequencer, CRTC, graphics, attribute, palette, Misc Output, Feature
Control, 46E8h, PEL mask) and every bit of every DAC component, every write
mode, read mode, read map, memory map, odd/even/chain/chain-4 combination,
every readable port, the DAC paths (write, read, cross-direction, state),
switch-sense values, the video status mux, the CRTC features (protect,
double scan, doubleword, count by 4, line compare, interrupt, ...), the
attribute modes (PEL width, P5/P4 select, panning compatibility), all
skews/delays and panning values. With --bios-dir, every BIOS VIDEO_PARMS
entry and every Unicorn scenario must have been run. With --require,
exits 1 on any hole.
"""
import json
import os
import sys

REG_BITS = {}
for i, m in enumerate([0x03, 0x3D, 0x0F, 0x3F, 0x0E]):
    REG_BITS['seq%d' % i] = m
CRTC_MASK = {0x08: 0x7F, 0x0A: 0x3F, 0x0B: 0x7F, 0x14: 0x7F, 0x17: 0xEF}
for i in range(25):
    REG_BITS['crtc%02x' % i] = CRTC_MASK.get(i, 0xFF)
for i, m in enumerate([0x0F, 0x0F, 0x0F, 0x1F, 0x03, 0x7B, 0x0F, 0x0F, 0xFF]):
    REG_BITS['gc%d' % i] = m
for i in range(16):
    REG_BITS['pal%x' % i] = 0x3F
REG_BITS.update({'attr10': 0xEF, 'attr11': 0xFF, 'attr12': 0x3F, 'attr13': 0x0F,
                 'attr14': 0x0F, 'misc': 0xFF, 'fcr': 0xFF, 'vse': 0xFF, 'pelmask': 0xFF})

REQUIRED = (
    ['write_mode%d' % i for i in range(4)] + ['read_mode1', 'set_reset_used'] +
    ['fn_%d' % i for i in range(4)] +
    ['ram_write_map%d_oe%d_c4%d' % (m, o, 0) for m in range(4) for o in range(2)] +
    ['ram_write_map1_oe0_c41', 'ram_write_map1_oe1_c41'] +
    ['ram_read_map%d' % m for m in range(4)] + ['chain_0', 'chain4_1', 'read_chain4',
                                                'read_oddeven'] +
    ['read_mode0_map%d' % m for m in range(4)] +
    ['io_r_' + p for p in ('attr', 'attr_data', 'c2', 'seqa', 'seqd', 'pelmask', 'dac_ra',
                           'dac_wa', 'dac_data', 'fcr_rd', 'misc_rd', 'gca', 'gcd', 'crtca',
                           'crtcd', 'xa', 'pos')] +
    ['io_w_' + p for p in ('vse', 'pos', 'attr', 'c2', 'seqa', 'seqd', 'pelmask', 'dac_ra',
                           'dac_wa', 'dac_data', 'gca', 'gcd', 'crtca', 'crtcd', 'xa')] +
    ['io_read_writeonly', 'io_write_undecoded', 'mem_dack0_blocked', 'rom_read',
     'dac_entry_written', 'dac_read_0', 'dac_read_1', 'dac_read_2',
     'dac_write_in_read_mode', 'dac_read_in_write_mode', 'pos_0', 'pos_1',
     'sense_0', 'sense_1', 'crtc_protected'] +
    ['dac_bit_%d_%d_%d' % (k, b, v) for k in range(3) for b in range(6) for v in range(2)] +
    ['diag_mux_%d' % m for m in range(4)] + ['diag_nonzero_%d' % m for m in range(3)] +
    ['amode_text', 'amode_gfx'] + ['amode_bit%d' % b for b in (1, 2, 3, 5, 6, 7)] +
    ['cursor_char', 'underline_row', 'gc_shift0_sl0_c256_0', 'gc_shift1_sl0_c256_0',
     'gc_shift0_sl0_c256_1', 'clock_w8_div0', 'clock_w8_div1', 'clock_w9_div0',
     'clock_w9_div1', 'pipe_text', 'pipe_gfx'] +
    ['skew_%d' % i for i in range(4)] + ['cskew_%d' % i for i in range(4)] +
    ['hdelay_%d' % i for i in range(4)] +
    ['line_compare_hit', 'frame_start', 'vretrace_start', 'vint_set', 'count_by_two',
     'count_by_four', 'hrtc_div2', 'crtc_word_mode', 'crtc_dword_mode', 'double_scan_line',
     'charmap_A', 'pal_write_ignored', 'pan_compat_hit'] +
    ['font_fetch_map%d' % m for m in range(8)])

ANY_OF = {
    'shift load (Clocking bit 2)': [['gc_shift0_sl1_c256_0', 'gc_shift1_sl1_c256_0']],
    'panning values 1-15': [['pan_%d_w8' % p, 'pan_%d_w9' % p] for p in range(1, 16)],
}

BIOS = ['entry%02x' % n for n in range(29) if n != 9]
EXEC = ['exec_post_color', 'exec_post_mono', 'exec_post_none', 'exec_mode12', 'exec_mode13']


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
    print('registers: %d; documented register bit values: %d required; other items: %d'
          % (len(REG_BITS), nbits, len(REQUIRED) + sum(len(g) for g in ANY_OF.values())))
    for k in REQUIRED:
        if not total.get(k):
            holes.append(k)
    for what, groups in ANY_OF.items():
        for g in groups:
            if not any(total.get(k) for k in g):
                holes.append('%s: %s' % (what, '/'.join(g)))
    if bios_dir:
        for e in BIOS + EXEC:
            if not os.path.exists(os.path.join(bios_dir, e + '.cov')):
                holes.append('BIOS run ' + e)
    shown = ['write_mode0', 'write_mode3', 'read_mode1', 'dac_entry_written', 'dac_read_0',
             'line_compare_hit', 'vint_set', 'double_scan_line', 'cursor_char', 'frame_start']
    print('  ' + ', '.join('%s %d' % (k, total.get(k, 0)) for k in shown))
    if holes:
        print('coverage holes (%d): %s' % (len(holes), ' '.join(holes[:80])))
    if '--require' in sys.argv and holes:
        print('FAIL: coverage')
        sys.exit(1)
    print('PASS: coverage' if not holes else 'NOTE: coverage holes')


if __name__ == '__main__':
    main()
