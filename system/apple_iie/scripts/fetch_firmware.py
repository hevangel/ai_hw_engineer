#!/usr/bin/env python3
from pathlib import Path
import hashlib, urllib.request
ROOT=Path(__file__).resolve().parents[1]
BASE='https://raw.githubusercontent.com/AppleWin/AppleWin/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/resource/'
FILES={'Apple2e.rom':('1fb812584c6633fa16b77b20915986ed1178d1e6fc07a647f7ee8d4e6ab9d40b',16384),
       'Apple2e_Enhanced_Video.rom':('52c3b87900ac939f6525402cab1ccfd8f8259290fc6df54da48fb4c98ae3ed0f',4096)}
work=ROOT/'work'; work.mkdir(exist_ok=True)
for name,(digest,size) in FILES.items():
    path=work/name
    data=path.read_bytes() if path.exists() else urllib.request.urlopen(BASE+name,timeout=60).read()
    if len(data)!=size or hashlib.sha256(data).hexdigest()!=digest:
        raise SystemExit('Firmware checksum/size mismatch: '+name)
    path.write_bytes(data)
    (work/('rom.hex' if name=='Apple2e.rom' else 'font.hex')).write_text(''.join(f'{b:02x}\n' for b in data))
print('PASS pinned original NMOS IIe ROM and external enhanced character representation')
