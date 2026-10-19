#!/usr/bin/env python3
"""Unmodified IBM EDLIN/BASICA run on the RTL 8086 and real DOS/BIOS.

Only keyboard scan codes, external media and battery storage enter the
machine. The disk is a private copy of a previous guest-created DOS install.
EDLIN's exact CR/LF/1Ah and .BAK expectations follow IBM DOS 3.30 Reference,
April 1987, printed page 8-19. Application binaries are hash pinned below.
"""
import hashlib
import json
import re
import shutil

from historical_machine import HistoricalMachine, ROOT
from hdd_fat import files
from test_software import disk_file, SCAN, SHIFT


def basic_ready(text):
    # Original BASICA reserves the last row for its function-key legend.
    # Wait for the final console line, without treating that legend as output.
    lines=text.splitlines()
    if lines and lines[-1].startswith('1LIST'):lines.pop()
    return next((line.strip() for line in reversed(lines) if line.strip()),'')=='Ok'


def main():
    program=(ROOT/'tb/software/primes.bas').read_text(encoding='ascii')
    # Reject unsupported keys before spending time on the original cold POST.
    for char in program.replace('\n','\r'):
        assert SHIFT.get(char,char.lower()) in SCAN, f'Unmapped BASIC input: {char!r}'
    floppy = ROOT / 'work/reference/pcdos330.img'
    source = floppy.read_bytes()
    for name, digest in [
        (b'EDLIN   COM', 'e0f1a87b6a2a22e1b179b332cac2267737bca5ed4cb0e1eb6aa0762d53775fe2'),
        (b'BASICA  COM', 'eda343f25badffd4d9a2f2a2b051804984ff075c06ed4e3795a2b0ea8d4253cb'),
    ]:
        assert hashlib.sha256(disk_file(source, name)).hexdigest() == digest
    bundle = ROOT / 'work/real_software_harddisk.m30'
    rtc = ROOT / 'work/real_software_rtc.bin'
    shutil.copyfile(ROOT / 'work/historical-harddisk.m30', bundle)
    shutil.copyfile(ROOT / 'work/harddisk_software_rtc.bin', rtc)
    initial = files(bundle.read_bytes()[8:8+21307392])
    assert b'REAL86  TXT' not in initial and b'PRIMES  BAS' not in initial
    machine = HistoricalMachine('real_software', {
        'IBM_PS2_MODEL30_HDD_PATH': str(bundle),
        'IBM_PS2_MODEL30_NVRAM_PATH': str(rtc),
    })
    def wait(predicate, label, limit=120000000):
        return machine.wait(lambda s,t,h: s['keysQueued']==0 and predicate(s,t,h),label,limit)
    def type_text(text):
        machine.type(text, clocks_per_key=250000)
    def dos_prompt(text):
        return bool(re.search(r'C(?:\\)?>$',text.rstrip()))
    def dos(label):
        wait(lambda s,t,h: dos_prompt(t),label)
    def editor(label):
        wait(lambda s,t,h: t.rstrip().splitlines()[-1].strip()=='*',label)
    def ctrl_z():
        # Microsoft MS-DOS 2.0 EDLIN.ASM, INSERT/ENDINS, recognizes a
        # leading 1Ah. This drives the physical Ctrl+Z keys, not DOS state.
        for code in [29,44,172,157]: machine.command(f'KEY {code}')
        type_text('\r')
    def disk_files():
        path=ROOT/'work/real_software_current.img'
        machine.command(f'SAVE 2 {path}')
        return files(path.read_bytes())
    try:
        machine.command('EJECT 0'); machine.command('RESET')
        wait(lambda s,t,h: s['dma']>16384 and ('Enter new date' in t or dos_prompt(t)),
            'original BIOS/DOS C: boot for applications',300000000)
        assert machine.state['postErrors']==0 and machine.state['mediaReads']==0
        if not dos_prompt(machine.text()):
            type_text('\r')
            wait(lambda s,t,h:'Enter new time' in t or dos_prompt(t),'accept DOS date')
            if not dos_prompt(machine.text()):type_text('\r')
        dos('COMMAND.COM before application tests')
        machine.command(f'MOUNT 0 {floppy}')
        type_text('a:edlin c:real86.txt\r')
        editor('original EDLIN new file')
        type_text('i\r8086 REAL SOFTWARE\rSECOND LINE\r'); ctrl_z()
        editor('EDLIN finishes insertion'); type_text('e\r')
        dos('EDLIN saves new file and exits')
        original=b'8086 REAL SOFTWARE\r\nSECOND LINE\r\n\x1a'
        assert disk_files()[b'REAL86  TXT']==original
        print('PASS: independent FAT16 exact EDLIN file bytes including CR/LF/1Ah',flush=True)
        type_text('a:edlin c:real86.txt\r');editor('EDLIN reopens its file')
        type_text('2d\r2i\rREPLACED LINE\r');ctrl_z()
        editor('EDLIN deletes and inserts line two');type_text('e\r')
        dos('EDLIN saves edited file and backup')
        actual=disk_files()
        assert actual[b'REAL86  TXT']==b'8086 REAL SOFTWARE\r\nREPLACED LINE\r\n\x1a'
        assert actual[b'REAL86  BAK']==original
        print('PASS: EDLIN edits and original .BAK independently verified',flush=True)
        type_text('type c:real86.txt\r')
        wait(lambda s,t,h:dos_prompt(t) and 'REPLACED LINE' in t,'COMMAND.COM reads EDLIN file')
        type_text('a:basica\r')
        wait(lambda s,t,h:'Ok' in t and 'BASIC' in t.upper(),'original BASICA 3.30')
        type_text(program.replace('\n','\r'))
        # Independent trial division, rather than the BASIC sieve algorithm.
        primes=[n for n in range(2,1001) if all(n%d for d in range(2,n))]
        assert (len(primes),sum(primes))==(168,76127)
        def result(s,t,h):
            return bool(re.search(r'PRIMES\s+168\s+76127\b',t)) and basic_ready(t)
        type_text('run\r')
        wait(result,'BASICA floating-point/array prime sieve agrees with independent oracle',400000000)
        type_text('save "c:primes.bas"\r')
        wait(lambda s,t,h:basic_ready(t),'BASICA saves tokenized program')
        saved=disk_files()[b'PRIMES  BAS']
        assert saved.startswith(b'\xff') and len(saved)>100
        type_text('new\rcls\r')
        wait(lambda s,t,h:not re.search(r'PRIMES\s+168\s+76127\b',t) and basic_ready(t),
            'BASICA discards old program and clears prior result')
        type_text('load "c:primes.bas"\rrun\r')
        wait(result,'BASICA reloads DOS-saved program and repeats prime result',400000000)
        type_text('print int(sqr(2)*1000000)\r')
        wait(lambda s,t,h:re.search(r'\b1414213\b',t) and basic_ready(t),
            'BASICA software square-root arithmetic')
        type_text('system\r');dos('BASICA returns to original DOS')
        assert machine.state['postErrors']==0 and not machine.state['fault']
        machine.command('PAUSE')
        (ROOT/'work/real_software_final.json').write_text(json.dumps(machine.state))
        print('PASS: unmodified EDLIN, BASICA prime sieve/save/reload/square root on RTL 8086/DOS',flush=True)
    finally:
        (ROOT/'work/real_software_last.json').write_text(json.dumps(machine.state))
        machine.close()


if __name__=='__main__':main()
