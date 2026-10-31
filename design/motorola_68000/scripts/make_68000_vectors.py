"""Compile SingleStepTests 680x0 JSON vectors into a flat binary for the
Verilator replay testbench.

The suite's initial.ram/final.ram lists enumerate all NON-ZERO bytes of
the test's memory state; the instruction's opcode word (from the test
name, e.g. "d133 [ADD.b ...]") is injected at PC by the runner and is not
part of the lists. The precompiler therefore emits, per test:

  17 x u32   d0-d7, a0-a6, usp, ssp          (initial)
  u32        pc
  u16        sr
  u8         n_init   initial RAM patch count
  u8         n_fin    final RAM patch count
  n_init x (u32 addr, u8 data)
  n_fin  x (u32 addr, u8 data)
  u16        opcode word (injected at pc by the TB)
  u16        opcode_file_index
  u16        prefetch word at pc+2 (the extension-word source; the ram
             lists exclude the whole instruction image, so the ext word
             at pc+2 exists only in the generator's pipeline state)

plus a parallel final-state stream:
  17 x u32   d0-d7, a0-a6, usp, ssp          (final)
  u32        pc
  u16        sr
"""
import gzip
import json
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN_ROOT = HERE.parent
REF_DIR = (DESIGN_ROOT / 'references' / 'singlesteptests_680x0').resolve()
OUT_DIR = (DESIGN_ROOT / 'work' / 'sim').resolve()
if DESIGN_ROOT not in REF_DIR.parents or DESIGN_ROOT not in OUT_DIR.parents:
    raise RuntimeError('path escapes the design tree')

REG_KEYS = ['d0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd7',
            'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'usp', 'ssp']


def main():
    files = sorted(REF_DIR.glob('*.json.gz'))
    if not files:
        raise SystemExit('no vendored vector files found')
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    body = bytearray()
    finals = bytearray()
    index = bytearray()
    prefetch = bytearray()
    names = []
    name_ranges = {}
    n_tests = 0
    for f in files:
        data = json.loads(gzip.decompress(f.read_bytes()))
        name = f.stem.replace('.json', '')
        name_ranges[f'{name} (file {len(names)})'] = (n_tests,
                                                      n_tests + len(data))
        names.append(name)
        for t in data:
            index += struct.pack('<I', len(body))
            for k in REG_KEYS:
                body += struct.pack('<I', t['initial'][k] & 0xFFFFFFFF)
            body += struct.pack('<I', t['initial']['pc'] & 0xFFFFFFFF)
            body += struct.pack('<H', t['initial']['sr'] & 0xFFFF)
            body += struct.pack('<BB', len(t['initial']['ram']),
                                len(t['final']['ram']))
            for a, v in t['initial']['ram']:
                body += struct.pack('<IB', a & 0xFFFFFF, v & 0xFF)
            for a, v in t['final']['ram']:
                body += struct.pack('<IB', a & 0xFFFFFF, v & 0xFF)
            opcode_word = int(t['name'].split()[0], 16) & 0xFFFF
            body += struct.pack('<HH', opcode_word, len(names) - 1)
            pref = t['initial'].get('prefetch', [opcode_word, 0])
            prefetch += struct.pack('<H', pref[1] & 0xFFFF)
            # final state stream
            for k in REG_KEYS:
                finals += struct.pack('<I', t['final'][k] & 0xFFFFFFFF)
            finals += struct.pack('<I', t['final']['pc'] & 0xFFFFFFFF)
            finals += struct.pack('<H', t['final']['sr'] & 0xFFFF)
            n_tests += 1
    index += struct.pack('<I', len(body))   # end sentinel

    (OUT_DIR / 'm68k_prefetch.bin').write_bytes(prefetch)
    (OUT_DIR / 'm68k_tests.bin').write_bytes(body)
    (OUT_DIR / 'm68k_index.bin').write_bytes(index)
    (OUT_DIR / 'm68k_final.bin').write_bytes(finals)
    (OUT_DIR / 'm68k_names.json').write_text(
        json.dumps({'names': names, 'ranges': name_ranges}, indent=1))
    print(f'compiled {n_tests} tests from {len(files)} opcode files; '
          f'stream {len(body)} bytes, finals {len(finals)} bytes')


if __name__ == '__main__':
    main()
