"""Convert a Motorola S-record file into a 64 KiB mem.hex image for the
Verilator testbenches. Single-shot pathlib write into <design>/work/sim.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN_ROOT = HERE.parent
OUT_DIR = (DESIGN_ROOT / 'work' / 'sim').resolve()
if DESIGN_ROOT not in OUT_DIR.parents:
    raise RuntimeError('work dir escapes the design tree')


def s19_to_image(path):
    image = bytearray(65536)
    start = None
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line.startswith('S'):
            continue
        typ = line[1]
        count = int(line[2:4], 16)
        data = bytes.fromhex(line[4:4 + count * 2])
        # data = [addr bytes..., payload..., checksum]
        if typ == '1':
            addr = (data[0] << 8) | data[1]
            payload = data[2:-1]
        elif typ == '2':
            addr = (data[0] << 16) | (data[1] << 8) | data[2]
            payload = data[3:-1]
        elif typ == '9':
            start = (data[0] << 8) | data[1]
            continue
        elif typ in ('0', '5', '6', '7', '8'):
            continue
        else:
            continue
        for i, b in enumerate(payload):
            image[(addr + i) & 0xFFFF] = b
    if start is not None:
        # the harness convention starts at the S9 address; the RTL takes
        # it from the reset vector at FFFE/FFFF
        image[0xFFFE] = (start >> 8) & 0xFF
        image[0xFFFF] = start & 0xFF
    return image


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else '6809_functional_test.s19'
    for cand in (Path(src), HERE.parent / 'references' / 'reyco2000_6809' / src):
        if cand.exists():
            src_path = cand
            break
    else:
        raise SystemExit(f'S-record not found: {src}')
    image = s19_to_image(src_path)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / 'mem.hex').write_text(
        ''.join(f'{b:02x}\n' for b in image))
    print(f'loaded {src_path.name} -> {OUT_DIR / "mem.hex"}')


if __name__ == '__main__':
    main()
