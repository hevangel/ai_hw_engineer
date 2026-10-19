#!/usr/bin/env python3
"""Validate the historical Monitor's actual serialized screen output."""
from check_video import WORK,FONT,check_frame

screen=(WORK/'monitor_screen.hex').read_text().split()
if len(screen)!=1024: raise SystemExit('Incomplete Monitor text-write snapshot')
flash_text=(WORK/'monitor_flash.txt').read_text().strip()
if flash_text not in ('0','1'): raise SystemExit('Unknown Monitor flash phase')
flash=flash_text=='1'


def cell(row,column):
    index=(row%8)*128+(row//8)*40+column
    try: return int(screen[index],16)
    except ValueError: raise SystemExit(f'Unknown visible Monitor byte: row {row}, column {column}')


def expected(y):
    pixels=[]
    for x in range(40):
        value=cell(y//8,x)
        glyph=FONT[(value%64)*8+y%8]
        inverted=not (value&0x80 or value&0x40 and flash)
        bits=[0]+[(glyph>>bit)&1 for bit in range(4,-1,-1)]+[0]
        pixels.extend(str(int(bool(bit)^inverted)) for bit in bits for _ in range(2))
    return ''.join(pixels)


if __name__=='__main__':
    # Observe the original firmware's printed command/output, not just pixels
    # agreeing with writes that could have put the wrong text on screen.
    lines=[''.join(chr((cell(y,x)&0x3f)+(0x40 if cell(y,x)&0x3f<0x20 else 0))
                   for x in range(40)) for y in range(24)]
    # HOME/clear puts command output at the top. Fail if startup question
    # marks survive, even when a later scroll made all visible bytes known.
    for row in range(6,24):
        for column in range(40):
            if cell(row,column)!=0xa0:
                raise SystemExit(f'Monitor clear left nonblank cell at {row}/{column}')
    for row,required in ((0,'300:A5 5A'),(2,'*300.301'),(4,'0300- A5 5A')):
        if lines[row].rstrip()!=required:
            raise SystemExit(f'Historical Monitor output at row {row} differs: {lines[row]!r}')
    for row in (1,3):
        if any(cell(row,column)!=0xa0 for column in range(40)):
            raise SystemExit(f'Historical Monitor interline row {row} was not cleared')
    for line in lines:
        if line.strip(): print('Monitor:',line.rstrip())
    check_frame(WORK/'monitor_video.csv',expected,WORK/'monitor_video.png','historical Monitor video')
    print('PASS historical Monitor rendered deposit/examine commands')
