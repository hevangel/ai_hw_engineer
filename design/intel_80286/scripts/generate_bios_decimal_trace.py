#!/usr/bin/env python3
"""Run the unchanged IBM AT hexadecimal-output helper in an external oracle.

This is a CPU-only routine-entry fixture, separate from the original-reset ROM
regression. A distinct bootstrap occupies the high reset window; the complete,
unchanged BIOS image occupies F0000..FFFFF. No BIOS byte is patched or replaced.
"""
import hashlib
import json
from pathlib import Path
from generate_vectors import Generator, word, UC_X86_REG_AX, UC_X86_REG_DI, UC_X86_REG_SP

from work_paths import get_work_root
ROOT=Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)


def main():
    rom=(WORK_ROOT/'software/atbios.bin').read_bytes()
    if hashlib.sha256(rom).hexdigest()!='74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f':
        raise ValueError('Original IBM AT ROM changed')
    # Original call site 0539 jumps to 0543; the helper stores to DS:DI and
    # ES:DI, advances DI twice and executes its original near RET at 0550.
    if rom[0x539:0x53b]!=bytes.fromhex('eb08') or rom[0x543:0x551]!=bytes.fromhex('04902714402788052688054747c3') or rom[0x224]!=0xf4:
        raise ValueError('Original IBM hex helper/caller/termination bytes changed')
    dest=WORK_ROOT/'software/decimal_trace.txt'
    with dest.open('w') as out:
        g=Generator(out)
        for nibble in range(16):
            regs=[0x5500|nibble,0x1234,0x2345,0x3456,0x8000,0x4567,0x5678,0x4000]
            g.case('ibm_at_hex_helper',bytes.fromhex('ea430500f0'),regs,lowflags=0,overflow=0,
                   masks=0xf7ff,segments=True,tail=b'',followup=16,
                   memory=[(0xf0000,rom),(0x38000,word(0x224))])
            character=b'0123456789ABCDEF'[nibble]
            if g.uc.reg_read(UC_X86_REG_AX)!=(0x5500|character) or g.uc.reg_read(UC_X86_REG_DI)!=0x4002 or g.uc.reg_read(UC_X86_REG_SP)!=0x8002:
                raise ValueError('Independent BIOS helper result/pointer contract failed')
            if g.shadow.get(0x14000)!=character or g.shadow.get(0x24000)!=character:
                raise ValueError('Independent BIOS helper did not write both display bytes')
            if bytes(g.uc.mem_read(0xf0000,len(rom)))!=rom:
                raise ValueError('BIOS helper fixture modified the original ROM image')
        if g.cases!=16 or g.steps!=464: raise ValueError('Incomplete original helper regression')
    manifest={'rom_sha256':hashlib.sha256(rom).hexdigest(),'cases':g.cases,'steps':g.steps,
              'entry':'F000:0543','near_return':'F000:0550','termination':'F000:0224',
              'trace_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),
              'scope':'Original BIOS hex-output helper with separate bootstrap and RAM return-frame fixture; not POST'}
    (dest.parent/'decimal_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: {g.cases} unchanged IBM AT hex-helper cases, {g.steps} independent instruction states')


if __name__=='__main__':main()
