from pathlib import Path
import ctypes,json,os
root=Path(__file__).resolve().parents[1];lib=ctypes.CDLL(str(root/'work/panel.so'))
fixture=root/'work/transport_unit';(fixture/'work').mkdir(parents=True,exist_ok=True)
os.chdir(fixture);Path('work/keys').write_bytes(b'AZ')
f=lib.panel_cycle
call=lambda a=0xffff,w=0,v=0:f(a,w,0xc2e1,v,0xc1,0xc2,0,3,2,1,1)
assert call(0xc000)&255==0xc1
for _ in range(4):call()
assert call(0xc010)&128==0
for _ in range(8):call()
assert call(0xc000)&255==0xda
for _ in range(5):call()
call(0xc010)
for _ in range(8):call()
assert call(0xc000)&128==0
with Path('work/keys').open('ab') as p:p.write(b'Q')
assert call(0xc000)&255==0xd1
Path('work/reset').touch();assert call()&384==256
for _ in range(7680):call(v=1)
raw=Path('work/frame.bin').read_bytes();assert len(raw)==38400 and raw[:5]==bytes([0xc1,0xc2,0,19,3])
assert json.loads(Path('work/state.json').read_text())['frames']==1
print('PASS DPI transport: ordered keys, EOF append, release/reset, complete frames and valid JSON')