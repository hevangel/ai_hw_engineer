#!/usr/bin/env python3
"""Fetch hash-pinned, optional reference artifacts into ignored work/ only."""
import hashlib
from pathlib import Path
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work'
CPU='https://raw.githubusercontent.com/mist64/perfect6502/09fc542877a84318291aa42dab143a3e2c3db974/'
APPLE='https://raw.githubusercontent.com/AppleWin/AppleWin/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/resource/'
FILES={
    'LICENSE':'29f44f6af3005961e76e712a8b0f36faf4d8c3d8e2592ca191876154adff2179',
    'netlist_6502.h':'7a5a28f64a0d464d18faecd3d715d96549bc5da8f05e6f468ef3dae97ef0f340',
    'netlist_sim.c':'19d1e30504fb13c27d79f8c8f01df5d080b30b621a60a548b1b84c614d7caed2',
    'netlist_sim.h':'fe483a7f43f973dfc388b02410a711ceb5b492ab08970429cc16a7cd0caf70bb',
    'types.h':'484747d5c63f0b4c1c8ed897ea52606bd7521b08f78a469582603e85a678f3bc',
}

def fetch(url,path,digest,text=False):
    if path.exists():data=path.read_bytes()
    else:
        print(f'Downloading {url}')
        request=urllib.request.Request(url,headers={'User-Agent':'Apple-II-board-reference-check'})
        with urllib.request.urlopen(request,timeout=60) as response:data=response.read()
    # Text-only canonicalization is specified so Windows staging preserves hashes.
    if text:data=(data.decode('utf-8-sig').replace('\r\n','\n').rstrip()+'\n').encode()
    actual=hashlib.sha256(data).hexdigest()
    if actual!=digest:raise SystemExit(f'Hash mismatch for {path.name}: {actual}')
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)
    return data

def main():
    print('Reference solver: MIT; Visual6502 netlist: CC BY-NC-SA 3.0. See board/DEPENDENCIES.md.')
    for name,digest in FILES.items():fetch(CPU+name,WORK/'reference'/name,digest,text=True)
    rom=fetch(APPLE+'Apple2.rom',WORK/'Apple2.rom',
        'f34e573b9de203203ac4a8c6cab7ab0f974facf13c40bf6e362fbb92197199f9')
    if len(rom)!=12288:raise SystemExit('Expected 12 KiB ROM socket image')
    for i,name in enumerate(['D0','D8','E0','E8','F0','F8']):
        (WORK/f'rom_{name}.hex').write_text(''.join(f'{b:02x}\n' for b in rom[2048*i:2048*(i+1)]),encoding='ascii')
    font=fetch(APPLE+'Apple2_Video.rom',WORK/'Apple2_Video.rom',
        '08f5d22230481019844492dde0a29a018cb193712a9e4a43770a3870608f28de')
    if len(font)!=2048:raise SystemExit('Expected 2 KiB EPROM font representation')
    # ASSUMPTION: EPROM bits 5..1 contain the original five glyph dots.
    # Address bits 2..0 are scan row, 8..3 are the 64-character code.
    # This representation conversion still requires original-2513 dump comparison.
    (WORK/'char_2513.hex').write_text(''.join(f'{(b>>1)&31:02x}\n' for b in font[:512]),encoding='ascii')
    print('Verified CPU reference and firmware; generated six socket images.')

if __name__=='__main__':main()
