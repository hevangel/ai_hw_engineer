#!/usr/bin/env python3
"""IBM PC AT BIOS access sequences for the RT/CMOS chip.

The sequences are the port 70h/71h accesses of the IBM PC AT BIOS
(Technical Reference 6280070, March 1984, "BIOS Listing", Test 1 and the
BIOS1/BIOS2 modules dated 11/22/83 and 01/10/84), in program order. They are
applied through the AT board adapter of tb/mc146818_tb.cpp: an OUT to port
70h is an address strobe with AD = data AND 3Fh (bit 7 is the NMI mask
flip-flop, bit 6 is unused), an IN/OUT at port 71h is a data strobe.
Listing addresses are offsets in segment F000h.

usage:
  bios_replay.py gen OUTDIR       write bios_cold.txt and bios_warm.txt
  bios_replay.py check TRACE NAME  apply the listing's own decisions to the
                                   values the RTL returned (TRACE is the RTL
                                   trace) and print what the BIOS would do

Only port-access sequences and the values the listed code compares are
reproduced here; no BIOS code or ROM image is used.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WARM_IMAGE = os.path.join(HERE, '..', 'tb', 'nvram', 'at_cmos_valid.hex')


def load_image(path):
    sys.path.insert(0, HERE)
    from mc146818_model import load_image as li
    return li(path)


def c10a(b_expect, c_expect):
    # Test 1, C10A "INSURE THAT CMOS CLOCK INTERRUPTS ARE DISABLED",
    # 01AD-01CC: MOV AL,8Bh / OUT 70h,AL (01AF) / IN AL,71h (01B3) /
    # AND AH,07h / OUT 70h,8Bh / OUT 71h,AL / OUT 70h,8Ch / IN AL,71h.
    # These are the BIOS's first RT/CMOS accesses after a cold reset.
    return ['# C10A 01AD-01CC: read B, clear SET/PIE/AIE/UIE/SQWE, read C',
            'O70 8B', 'I71 %02X' % b_expect,
            'O70 8B', 'O71 %02X' % (b_expect & 0x07),
            'O70 8C', 'I71 %02X' % c_expect,
            'O70 8B', 'I71 %02X' % (b_expect & 0x07)]   # read-back (bench check, not in BIOS)


def checkpoint02():
    # Test 1, checkpoint 02 "VERIFY AND CLEAR SHUTDOWN FLAG", 01E6-020D:
    # CX=9, AH=1; C10B: OUT 70h,8Fh / OUT 71h,AH / OUT 70h,8Fh / IN AL,71h /
    # CMP AL,AH / JNZ ERR01 (HLT) / RCL AH,1 / LOOP C10B. RCL through the
    # carry that CMP cleared walks 01,02,...,80 and then 00.
    s = ['# checkpoint 02 01E6-020D: rolling bit through the shutdown byte 0Fh']
    ah = 1
    for _ in range(9):
        s += ['O70 8F', 'O71 %02X' % ah, 'O70 8F', 'I71 %02X' % ah]
        ah = (ah << 1) & 0xFF
    return s


def gen_cold():
    """Power-on with the default image (all zero: battery lost)."""
    s = ['# IBM PC AT cold boot with a dead battery (default all-zero image)']
    s += c10a(0x00, 0x00)
    s += checkpoint02()
    # Test 1 TEST.12 checkpoint 16, CMOS (0727-0733): OUT 70h,8Dh /
    # IN AL,71h / TEST AL,80h / JZ CMOS1A. VRT=0 means the battery was lost.
    s += ['# checkpoint 16: battery status (register D)', 'O70 8D', 'I71 00']
    # CMOS1A checkpoint 17: IN diag (8Eh), OR AH,BAD_BAT (80h), write back.
    s += ['# CMOS1A checkpoint 17: set BAD_BAT in diagnostic byte 0Eh',
          'O70 8E', 'I71 00', 'O70 8E', 'O71 80', 'O70 8E', 'I71 80']
    # Checkpoint 19: shutdown byte = 01 before the memory-size shutdown.
    s += ['# checkpoint 19: shutdown return 1', 'O70 8F', 'O71 01', 'O70 8F', 'I71 01']
    # After the reset, Test 1 C7B/C7C (0172-0181 area) reads the shutdown
    # byte and clears it: OUT 70h,8Fh / IN AL,71h / ... OUT 70h,8Fh /
    # OUT 71h,00h.
    s += ['# C7B/C7C: read shutdown byte after processor shutdown, then clear',
          'O70 8F', 'I71 01', 'O70 8F', 'O71 00', 'O70 8F', 'I71 00']
    # SET_TOD (BIOS2 00DF-00E9): OUT 70h,0Eh / IN AL,71h / AND AL,C4h / JNZ
    # POD_DONE: bad battery -> timer set to zero, no clock read.
    s += ['# SET_TOD: CMOS validity (0Eh AND C4h) is nonzero -> no clock read',
          'O70 0E', 'I71 80']
    # INITIALIZE_STATUS (BIOS2, INT 1Ah set time/date): A=26h, B=82h,
    # read C, read D.
    s += ['# INITIALIZE_STATUS: A=26h, B=82h, read C and D',
          'O70 0A', 'O71 26', 'O70 0B', 'O71 82', 'O70 0C', 'I71 00',
          'O70 0D', 'I71 80']
    # RTC set (INT 1Ah AH=03h/05h) writes time/date with SET=1, then
    # clears SET (B AND 7Fh): 23:59:58 31 Dec 84, Monday.
    for a, v in ((0x00, 0x58), (0x02, 0x59), (0x04, 0x23), (0x06, 0x02),
                 (0x07, 0x31), (0x08, 0x12), (0x09, 0x84)):
        s += ['O70 %02X' % a, 'O71 %02X' % v]
    s += ['O70 0B', 'I71 82', 'O70 0B', 'O71 02']
    # Let two seconds pass (divider was running since A=26h).
    s += ['T 65536', 'O70 00', 'I71 00', 'O70 04', 'I71 00', 'O70 07', 'I71 01',
          'O70 08', 'I71 01', 'O70 09', 'I71 85', 'O70 06', 'I71 03']
    # INT 15h AH=83h EVENT_WAIT (BIOS1): OUT 70h,0Bh / IN AL,71h / AND 7Fh /
    # OR 40h / OUT 70h,0Bh / OUT 71h,AL -> PIE on, 976.562 us periodic.
    s += ['# EVENT_WAIT: enable PIE', 'O70 0B', 'I71 02', 'O70 0B', 'O71 42']
    s += ['O70 0C', 'I71', 'T 32', 'Q 0']
    # RTC_INT (INT 70h, BIOS2): DL=0Ah; PORT_INC -> OUT 70h,0Bh / IN (enables);
    # PORT_INC -> OUT 70h,0Ch / IN (source); AND AL,AH; TEST AL,40h.
    s += ['# RTC_INT: read B then C; C read releases IRQ 8',
          'O70 0B', 'I71 42', 'O70 0C', 'I71 C0', 'Q 1', 'T 32', 'Q 0',
          'O70 0B', 'I71 42', 'O70 0C', 'I71 C0', 'Q 1']
    # RTC_INT when the wait count expires turns PIE off: B AND BFh.
    s += ['O70 0B', 'I71 42', 'O70 0B', 'O71 02', 'T 64', 'Q 1']
    s += ['DUMP']
    return s


def gen_warm():
    """Power-on with a battery-good configured image."""
    img = load_image(WARM_IMAGE)
    s = ['# IBM PC AT boot with a valid configuration (tb/nvram/at_cmos_valid.hex)']
    # Processor-shutdown return path first (C7B 0158-0169 region): the BIOS
    # reads the shutdown byte; 00 = soft reset/unexpected shutdown.
    s += ['# C7B: read shutdown byte', 'O70 8F', 'I71 %02X' % img[0x0F],
          'O70 8F', 'O71 00']
    s += c10a(img[0x0B], 0x00)
    s += checkpoint02()
    s += ['# checkpoint 16: battery good', 'O70 8D', 'I71 80']
    # CMOS1 (0752 area): read diag (0Eh) and keep W_MEM_SIZE, then sum
    # CMOS_BEGIN (90h) .. CMOS_END (ADh) and compare with 2Eh:2Fh.
    s += ['# CMOS1: diagnostic byte, clear it (cold reset path)',
          'O70 8E', 'I71 %02X' % img[0x0E], 'O70 8E', 'O71 00']
    s += ['# CMOS2 loop 90h-ADh, then checksum bytes AEh (high), AFh (low)']
    for a in range(0x10, 0x2E):
        s += ['O70 %02X' % (0x80 | a), 'I71 %02X' % img[a]]
    s += ['O70 AE', 'I71 %02X' % img[0x2E], 'O70 AF', 'I71 %02X' % img[0x2F]]
    # E20B: diagnostic status for the memory-size check; memory size bytes.
    s += ['# E20B: diagnostic status and configured base memory size',
          'O70 8E', 'I71 00', 'O70 96', 'I71 %02X' % img[0x16],
          'O70 95', 'I71 %02X' % img[0x15]]
    # SET_TOD: validity (0Eh AND C4h = 0), then UIP wait (register A bit 7),
    # then seconds/minutes/hours, each compared against 59h/59h/23h.
    s += ['# SET_TOD: validity byte', 'O70 0E', 'I71 00']
    # Arrive exactly at the start of an update (UIP rises after 16384 ticks
    # from power-on since the image has DV=010) so the poll loop must wait.
    s += ['T 16384', 'POLL 0A 80 00 65535 1']
    s += ['O70 00', 'I71 %02X' % (img[0x00] + 1), 'O70 02', 'I71 %02X' % img[0x02],
          'O70 04', 'I71 %02X' % img[0x04]]
    s += ['DUMP']
    return s


def gen(outdir):
    os.makedirs(outdir, exist_ok=True)
    for name, fn in (('bios_cold', gen_cold), ('bios_warm', gen_warm)):
        with open(os.path.join(outdir, name + '.txt'), 'w') as f:
            f.write('\n'.join(fn()) + '\n')


def reads(trace):
    return [(int(f[1], 16), None if f[2] == 'Z' else int(f[2], 16))
            for f in (ln.split() for ln in open(trace)) if f[0] == 'R']


def check(trace, name):
    """Re-apply the listing's decisions to the RTL's read values."""
    r = reads(trace)
    i = 0
    if name == 'bios_warm':
        i += 1
    # C10A: B read, C read.
    b = r[i][1]
    print('  C10A: register B = %02X, register C = %02X' % (b, r[i + 1][1]))
    i += 3
    # checkpoint 02: CMP AL,AH must be equal on all 9 passes else HLT.
    ah = 1
    for k in range(9):
        a, v = r[i]
        if a != 0x0F or v != ah:
            raise SystemExit('FAIL: checkpoint 02 pass %d read %s, BIOS halts (ERR01)'
                             % (k, v))
        ah = (ah << 1) & 0xFF
        i += 1
    print('  checkpoint 02: 9 rolling-bit passes equal (01..80, 00); no HLT')
    d = r[i][1]
    i += 1
    if name == 'bios_cold':
        if d & 0x80:
            raise SystemExit('FAIL: dead-battery image reported VRT=1')
        print('  checkpoint 16: register D = %02X -> CMOS1A, BAD_BAT set' % d)
    else:
        if not d & 0x80:
            raise SystemExit('FAIL: battery-good image reported VRT=0')
        i += 1                                    # diag read
        total = 0
        for a in range(0x10, 0x2E):
            assert r[i][0] == a          # trace shows the latched AD5-AD0
            total += r[i][1]
            i += 1
        stored = (r[i][1] << 8) | r[i + 1][1]
        i += 2
        if total == 0 or total != stored:
            raise SystemExit('FAIL: CMOS checksum %04X vs stored %04X (BAD_CKSUM)'
                             % (total, stored))
        print('  checkpoint 16: VRT=1; CMOS2 sum 10h-2Dh = %04X equals 2Eh:2Fh' % total)
        i += 3
        if r[i][1] & 0xC4:
            raise SystemExit('FAIL: SET_TOD sees invalid CMOS')
        i += 1
        polls = 0
        while r[i][0] == 0x0A:
            polls += 1
            last = r[i][1]
            i += 1
        if last & 0x80 or polls > 65535:
            raise SystemExit('FAIL: UIP never cleared (CMOS CLOCK STUCK)')
        sec, mnt, hr = r[i][1], r[i + 1][1], r[i + 2][1]
        if sec > 0x59 or mnt > 0x59 or hr > 0x23:
            raise SystemExit('FAIL: SET_TOD limits (TOD_ERROR)')
        print('  SET_TOD: UIP cleared after %d reads of register A; time %02X:%02X:%02X'
              ' within the 23:59:59 limits' % (polls, hr, mnt, sec))
    print('PASS: %s follows the listing\'s success path' % name)


if __name__ == '__main__':
    if sys.argv[1] == 'gen':
        gen(sys.argv[2])
    else:
        check(sys.argv[2], sys.argv[3])
