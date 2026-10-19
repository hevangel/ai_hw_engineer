#!/usr/bin/env python3
"""Compare observed board pixels to manual layout and an external expansion oracle.

No package state or RTL is read. Pixel expansion follows the pinned AppleWin
NTSC.cpp reference; scan timing and physical serial stages follow manual S-3/4/11.
The font comes from the independently downloaded and hash-checked ROM artifact.
"""
from pathlib import Path
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work'
SCENARIOS=[('text',1,False,False),('text',1,True,False),('text',2,False,False),
           ('lores',1,False,False),('lores',2,False,True),('hires',1,False,False),
           ('hires',2,False,False),('hires',1,False,True),('text',2,False,True)]
FONT=[int(s,16) for s in (WORK/'char_2513.hex').read_text().split()]


def text_byte(row,column,page):
    return (0,0x40,0x80)[column%3] | ((row*11+column*7+page*13)%64)


def hires_byte(y,column,page):
    return ((y*37+column*19+page*53)%128) | (0x80 if (y+column+page)%3==0 else 0)


def expected_line(y,mode,page,flash,mixed):
    pixels=[]
    if mixed and y>=160: mode='text'
    for x in range(40):
        if mode=='text':
            value=text_byte(y//8,x,page)
            glyph=FONT[(value%64)*8+y%8]
            inverted=not (value&0x80 or value&0x40 and flash)
            cell=[0]+[(glyph>>bit)&1 for bit in range(4,-1,-1)]+[0]
            pixels.extend(int(bool(bit)^inverted) for bit in cell for _ in range(2))
        elif mode=='hires':
            value=hires_byte(y,x,page)
            cell=[(value>>bit)&1 for bit in range(7) for _ in range(2)]
            # Revision 0 has no A11 delayed path: DL7 is ignored.
            # Gayler, Apple II Circuit Description, Appendix B, p.153.
            pixels.extend(cell)
        else:
            value=text_byte(y//8,x,page)
            color=(value>>(4 if y%8>=4 else 0))&15
            pixels.extend((color>>((x*14+i)%4))&1 for i in range(14))
    return ''.join(str(b) for b in pixels)


def png(path,rows):
    """Write actual observed monochrome samples, with each scanline doubled."""
    def chunk(kind,payload):
        return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    raw=b''.join(b'\0'+bytes(255 if b=='1' else 0 for b in row) for row in rows for _ in range(2))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',560,384,8,0,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))


def check_frame(path,oracle,output_path,label):
    samples=[]
    for record in path.read_text().splitlines():
        t,h,v,pixel,sync,latched=record.split(',')
        samples.append((int(h),int(v),pixel,sync,latched,float(t)))
    if len(samples)!=912*262: raise SystemExit(f'{label}: wrong sample count')
    # Start at H=24,V=256. There are two H=0 states, including the stretched
    # clock, so H=0 lasts 30 master clocks; other states each last 14.
    expected_h=[h for h in range(24,64) for _ in range(14)]+[0]*30+[h for h in range(1,24) for _ in range(14)]
    rasters=[]
    for line in range(262):
        v=256+line if line<256 else line-6
        next_v=256+line+1 if line<255 else (line-5 if line>=256 else 250)
        row=samples[line*912:(line+1)*912]
        for i,(h,actual_v,pixel,sync,latched,t) in enumerate(row):
            want_v=v if i<40*14 else next_v
            if h!=expected_h[i] or actual_v!=want_v:
                raise SystemExit(f'{label} line {line} sample {i}: scan state {h}/{actual_v}, expected {expected_h[i]}/{want_v}')
            # Original S-11: horizontal sync during H=8..15, vertical sync
            # when V4/V3/V2 are set and V1 is clear. No later-board narrowing.
            expected_sync=str(int(not(h<24 and h&8 or (want_v&0xe0)==0xe0 and not want_v&16)))
            if sync!=expected_sync: raise SystemExit(f'{label}: sync mismatch at line {line}, sample {i}')
            if (line>=192 or i<14 or i>=574) and pixel!='0':
                raise SystemExit(f'{label}: nonzero/unknown blanking at line {line}, sample {i}')
            if line*912+i and abs(t-samples[line*912+i-1][5]-69.842)>0.002:
                raise SystemExit(f'{label}: master-clock period mismatch')
        if line<192:
            # One character of pipeline latency: fetch/latch, parallel load,
            # then B10 serial output. The last cell spills into the first H=0.
            observed=''.join(p[2] for p in row[14:574])
            expected=oracle(line)
            if observed!=expected:
                errors=[i for i,(a,b) in enumerate(zip(observed,expected)) if a!=b]
                raise SystemExit(f'{label} line {line}: {len(errors)} pixel mismatches, first at {errors[:12]}')
            rasters.append(observed)
    png(output_path,rasters)
    print(f'PASS {label}: scan/blanking/sync and 107520 exact visible pixel samples')


if __name__=='__main__':
    for number,scenario in enumerate(SCENARIOS):
        check_frame(WORK/f'video_{number}.csv',lambda y:expected_line(y,*scenario),
                    WORK/f'video_{number}.png',f'digital video frame {number} {scenario}')
    print('PASS digital video: nine full frames, scan timing, text attributes/pages and graphics')
