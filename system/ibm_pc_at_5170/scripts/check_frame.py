#!/usr/bin/env python3
"""Read the text on a captured video frame and compare it with the expected screen.

usage: check_frame.py ADAPTER_ROM_BIN FRAME_PPM EXPECTED_TXT [PNG_OUT]

The frame is what post_runner rebuilt from the card's monitor connector,
80 x 25 characters:
  640 x 350  EGA, 8 x 14 dots per character;
  720 x 400  VGA, 9 x 16 dots per character: the 8 x 16 font, with the
             glyphs the ROM's 9-dot table replaces, plus a ninth column
             that is background, or repeats the eighth column for the
             line-graphics characters C0h-DFh.
Every character cell must be exactly one glyph of that font as stored in
the adapter's own ROM, in two colors (one cell may also carry the cursor);
the decoded rows, with trailing blanks removed, must equal EXPECTED_TXT.
This checks the whole display path (BIOS character writes, video memory,
font, attribute and timing logic) against the ROM's font, not against the
card model.
"""
import struct
import sys
import zlib
from pathlib import Path

COLS, ROWS = 80, 25
# Glyph 01h (the smiling face) of IBM's 8 x 14 and 8 x 16 fonts, used to
# find the font table in the ROM; glyph 00h before it is blank.
GLYPH_01 = {
    14: bytes([0x00, 0x00, 0x7e, 0x81, 0xa5, 0x81, 0x81, 0xbd, 0x99, 0x81, 0x7e, 0x00, 0x00, 0x00]),
    16: bytes([0x00, 0x00, 0x7e, 0x81, 0xa5, 0x81, 0x81, 0xbd, 0x99, 0x81, 0x81, 0x7e, 0x00, 0x00, 0x00, 0x00]),
}
# Frame size -> (dots per character, lines per character).
FORMATS = {(640, 350): (8, 14), (720, 400): (9, 16)}


def read_ppm(path):
    data = Path(path).read_bytes()
    magic, size, depth, pixels = data.split(b'\n', 3)
    width, height = (int(v) for v in size.split())
    if magic != b'P6' or depth != b'255' or len(pixels) != width * height * 3:
        raise ValueError('not a binary PPM')
    return width, height, pixels


def write_png(path, width, height, pixels):
    def chunk(tag, body):
        return struct.pack('>I', len(body)) + tag + body + struct.pack('>I', zlib.crc32(tag + body))
    raw = b''.join(b'\0' + pixels[y*width*3:(y+1)*width*3] for y in range(height))
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) +
                           chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def main():
    if len(sys.argv) not in (4, 5):
        raise SystemExit(__doc__)
    rom = Path(sys.argv[1]).read_bytes()
    width, height, pixels = read_ppm(sys.argv[2])
    if (width, height) not in FORMATS:
        raise ValueError(f'frame is {width} x {height}; expected one of {sorted(FORMATS)}')
    CW, CH = FORMATS[(width, height)]
    key = bytes(CH) + GLYPH_01[CH]
    at = rom.find(key)
    if at < 0 or rom.find(key, at + 1) >= 0:
        raise ValueError(f'8 x {CH} font not found exactly once in the ROM')
    # Each glyph as CH rows of CW dots, most significant bit first.
    # In 9-dot modes the BIOS replaces some glyphs from the table that
    # follows the font in the ROM: entries of a character code and CH
    # rows, ended by code 00h.
    patch = {}
    if CW == 9:
        i = at + CH*256
        while rom[i]:
            patch[rom[i]] = rom[i + 1: i + 1 + CH]
            i += 1 + CH
        if not patch:
            raise ValueError('no 9-dot glyph table after the font in the ROM')

    def rows_of(c):
        rows = patch.get(c, rom[at + CH*c: at + CH*(c + 1)])
        if CW == 8:
            return tuple(rows)
        return tuple((r << 1) | ((r & 1) if 0xc0 <= c <= 0xdf else 0) for r in rows)
    font = {rows_of(c): c for c in reversed(range(256))}
    full = (1 << CW) - 1
    if len(sys.argv) == 5:
        write_png(sys.argv[4], width, height, pixels)
    px = [pixels[i:i+3] for i in range(0, len(pixels), 3)]

    rows, cursors = [], 0
    for r in range(ROWS):
        text = ''
        for c in range(COLS):
            cell = [px[(r*CH + y)*width + c*CW: (r*CH + y)*width + c*CW + CW] for y in range(CH)]
            colors = sorted(set(p for line in cell for p in line))
            if len(colors) > 2:
                raise ValueError(f'more than two colors in the cell at row {r}, column {c}')
            # The darker color is the background.
            glyph = tuple(sum((p == colors[-1] and len(colors) == 2) << (CW - 1 - x) for x, p in enumerate(line))
                          for line in cell)
            code = font.get(glyph)
            if code is None:
                # The cursor: full-width lines over one glyph.
                under = [k for g, k in font.items() if all(a == b or a == full for a, b in zip(glyph, g))]
                if not under:
                    raise ValueError(f'the cell at row {r}, column {c} is not a glyph of the ROM font')
                code = min(under, key=lambda k: (k not in (0, 0x20), k))
                cursors += 1
            text += chr(code) if 0x20 <= code < 0x7f else ' ' if code in (0, 0xff) else '?'
        rows.append(text.rstrip())
    if cursors > 1:
        raise ValueError(f'{cursors} cells are not plain glyphs; at most one cursor is expected')
    while rows and not rows[-1]:
        rows.pop()
    expected = [line.rstrip() for line in Path(sys.argv[3]).read_text().splitlines() if not line.startswith('#')]
    while expected and not expected[-1]:
        expected.pop()
    if rows != expected:
        raise ValueError('screen differs from the expected text:\n' + '\n'.join(rows))
    print(f'PASS: {width} x {height} frame reads as 80 x 25 text of the 8 x {CH} font in the adapter ROM and equals the expected '
          f'screen ({len(rows)} rows): ' + ' / '.join(row.strip() for row in rows if row))


if __name__ == '__main__':
    try:
        main()
    except ValueError as error:
        print(f'FAIL: {error}', file=sys.stderr)
        raise SystemExit(1)
