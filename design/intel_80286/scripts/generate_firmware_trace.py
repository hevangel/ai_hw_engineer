#!/usr/bin/env python3
"""Execute the unchanged IBM AT ROM in an independent shared-ISA oracle.

Board fixture: zero-initialized RAM and byte I/O registers, keyboard status 0,
no external interrupts. This is a CPU regression, not an IBM AT platform model.
The regression reaches the original ROM-checksum success checkpoint before
timer hardware tests; the fixture is not a timer or full motherboard model.
"""
import hashlib
import json
from pathlib import Path
from generate_vectors import Generator, REGS, SEGS, UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_EFLAGS

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)


def decode(uc, pc):
    raw = bytes(uc.mem_read(pc,10))
    n = 0
    while n<10 and raw[n] in (0x26,0x2e,0x36,0x3e): n += 1
    if n==10: return None
    op=raw[n]
    modrm = op<=0x3b and op%8<4 or op in (0x80,0x81,0x83,0x84,0x85,0x86,0x87,
        0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f,0xc0,0xc1,0xc4,0xc5,0xc6,0xc7,
        0xd0,0xd1,0xd2,0xd3,0xf6,0xf7,0xfe,0xff)
    if modrm:
        m=raw[n+1]; extension=(m>>3)&7
        if op in (0xc0,0xc1,0xd0,0xd1,0xd2,0xd3) and extension==6: return None
        if op in (0xf6,0xf7) and extension not in (0,2,3): return None
        if op==0xfe and extension not in (0,1): return None
        if op==0xff and extension not in (0,1,2,4,6): return None
        if op in (0xc6,0xc7,0x8f) and extension!=0: return None
        if op in (0x8c,0x8e) and (extension>3 or op==0x8e and extension==1): return None
        if op in (0x8d,0xc4,0xc5) and m>=0xc0: return None
        return op,raw[n:]
    supported = (op<=0x3d and op%8 in (4,5) or 0x40<=op<=0x5f or 0x70<=op<=0x79 or
        0x7a<=op<=0x7f or 0x90<=op<=0x99 or 0xa0<=op<=0xa3 or 0xb0<=op<=0xbf or
        0xe0<=op<=0xe9 or 0xec<=op<=0xef or op in (0x06,0x0e,0x16,0x1e,0x07,0x17,0x1f,
        0x68,0x6a,0x9c,0x9d,0x9e,0x9f,0xa8,0xa9,0xc2,0xc3,0xea,0xeb,0xf4,0xf5,
        0xf8,0xf9,0xfa,0xfb,0xfc,0xfd))
    return (op,raw[n:]) if supported else None


def main():
    path=WORK_ROOT/'software/atbios.bin'
    rom=path.read_bytes()
    if hashlib.sha256(rom).hexdigest()!='74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f':
        raise ValueError('Original IBM AT ROM changed')
    dest=WORK_ROOT/'software/oracle_trace.txt'
    with dest.open('w') as out:
        g=Generator(out)
        g.uc.mem_write(0xf0000,rom)
        g.shadow.update((0xf0000+i,v) for i,v in enumerate(rom))
        for r in REGS+SEGS: g.uc.reg_write(r,0)
        g.uc.reg_write(UC_X86_REG_CS,0xf000)
        g.uc.reg_write(UC_X86_REG_EFLAGS,2)
        out.write(f'ROM IBM_AT_REV1 {path}\n')
        out.write('STEP fffff0 ea e05b 2 ffff f0000000 ffff 0 0 0 0 0 0 0 0\nFETCH fffff0 5\nCHECK\n')
        ip=0xe05b; count=1; valid_flags=0x8fd5
        while count<500000:
            cs=g.uc.reg_read(UC_X86_REG_CS)
            pc=cs*16+ip
            if pc==0xf0225:
                out.write('END\n')
                break
            decoded=decode(g.uc,pc)
            if decoded is None:
                raise ValueError(f'Unsupported instruction before required ROM-checksum checkpoint: {cs:04X}:{ip:04X}')
            op, raw=decoded
            if op==0xf4:
                raise ValueError(f'Original BIOS entered HLT/error path at {cs:04X}:{ip:04X}')
            before=[g.uc.reg_read(r) for r in REGS]
            g.bus.clear(); g.seen.clear()
            g.uc.emu_start(pc,0,count=1)
            if len(g.seen)!=1 or g.seen[0][0]!=pc: raise ValueError('Oracle instruction synchronization')
            flags=g.uc.reg_read(UC_X86_REG_EFLAGS)&65535
            ip=g.uc.reg_read(UC_X86_REG_IP)
            if op<=0x3d and op%8<=5 or op in (0x80,0x81,0x83):
                kind=(raw[1]>>3)&7 if op in (0x80,0x81,0x83) else op//8
                valid_flags|=0x8d5
                if kind in (1,4,6): valid_flags &= ~0x10
            if op in (0x84,0x85,0xa8,0xa9): valid_flags=(valid_flags|0x8c5)&~0x10
            if op in (0xc0,0xc1,0xd0,0xd1,0xd2,0xd3):
                extension=(raw[1]>>3)&7
                shift_count=(bytes(g.uc.mem_read(pc,g.seen[0][1]))[-1]&31) if op in (0xc0,0xc1) else before[1]&31 if op in (0xd2,0xd3) else 1
                if shift_count:
                    if extension>=4: valid_flags=(valid_flags|0xc5)&~0x10
                    if shift_count==1: valid_flags|=0x800
                    else: valid_flags&=~0x800
                    if extension in (4,5) and shift_count>=(16 if op&1 else 8): valid_flags&=~1
            if op==0x9e: valid_flags|=0xd5
            regs=[g.uc.reg_read(r) for r in REGS]
            segs=sum(g.uc.reg_read(r)<<(16*n) for n,r in enumerate(SEGS))
            values=[pc,op,ip,flags,valid_flags,segs,0xd5ff if op==0x9f else 0xffff]+regs
            out.write('STEP '+' '.join(f'{v:x}' for v in values)+'\n')
            out.write(f'FETCH {pc:x} {g.seen[0][1]:x}\n')
            for transfer in g.bus: out.write('BUS '+' '.join(f'{v:x}' for v in transfer)+'\n')
            out.write('CHECK\n')
            count+=1
        else: raise ValueError('Firmware regression reached instruction bound before unsupported boundary')
    manifest={'instructions':count,'stop_cs':f'{cs:04x}','stop_ip':f'{ip:04x}',
              'stop_bytes':bytes(g.uc.mem_read(pc,6)).hex(),'oracle':'Unicorn 2.1.4',
              'scope':'Original CPU firmware trace with zero RAM/simple I/O fixture; not full POST',
              'checkpoint':'Original ROM-checksum success, before PIT hardware test',
              'trace_sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
    (WORK_ROOT/'software/oracle_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: generated {count} unchanged IBM AT instruction states; ROM-checksum success checkpoint {cs:04X}:{ip:04X}')


if __name__=='__main__': main()
