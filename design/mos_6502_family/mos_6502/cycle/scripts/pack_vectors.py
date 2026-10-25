#!/usr/bin/env python3
"""Pack external cases without deriving any expected behavior from the RTL."""
import json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def state(s):
    return struct.pack('<HBBBBB',s['pc'],s['a'],s['x'],s['y'],s['s'],s['p'])

def main():
    manifest=json.loads((ROOT/'work/external/vectors_manifest.json').read_text())
    import hashlib
    with (ROOT/'work/vectors.bin').open('wb') as out:
        count=sum(item['cases'] for item in manifest['files'].values())
        out.write(struct.pack('<I',count))
        for op,item in manifest['files'].items():
            path=ROOT/'work/external'/f'{op}.json'
            assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
            cases=json.loads(path.read_text())
            assert len(cases)==item['cases']
            for case in cases:
                out.write(bytes([int(op,16)])); out.write(state(case['initial'])); out.write(state(case['final']))
                for which in ['initial','final']:
                    ram=case[which]['ram']; out.write(struct.pack('<H',len(ram)))
                    for address,value in ram: out.write(struct.pack('<HB',address,value))
                out.write(bytes([len(case['cycles'])]))
                for address,value,direction in case['cycles']:
                    out.write(struct.pack('<HBB',address,value,direction=='write'))
    print(f'Packed {count} independent NMOS cases')

if __name__=='__main__': main()
