#!/usr/bin/env python3
"""Original BASICA CGA graphics and original BIOS native MCGA services.

BASICA/GW-BASIC SCREEN modes are 0..10, independently documented at
https://robhagemans.github.io/pcbasic/doc/2.0/ . Do not confuse those
language modes with later QuickBASIC modes 11/13. Original DEBUG assembles
and executes INT 10h for the native MCGA tests; no CPU state is injected.
"""
import json
from historical_machine import HistoricalMachine,ROOT
from test_software import prompt


def main():
    machine=HistoricalMachine('display_software',{
        'IBM_PS2_MODEL30_NO_HDD':'1',
        'IBM_PS2_MODEL30_NVRAM_PATH':str(ROOT/'work/software_rtc.bin')})
    def wait(predicate,label,limit=60000000):
        return machine.wait(lambda s,t,h:s['keysQueued']==0 and predicate(s,t,h),label,limit)
    # Bitmap character output is slower than the 16-byte BIOS key buffer.
    # Pace actual scan codes like a typist so the regression cannot overrun it.
    def type_text(text):machine.type(text,clocks_per_key=250000)
    def dos(label):wait(lambda s,t,h:prompt(t),label)
    def boot(label):
        wait(lambda s,t,h:s['mediaReads']>16384 and s['dma']>16384 and
            ('Enter new date' in t or prompt(t)),label,300000000)
        assert machine.state['postErrors']==0,'configured clock must pass unchanged POST'
        if not prompt(machine.text()):
            type_text('\r')
            wait(lambda s,t,h:'Enter new time' in t or prompt(t),'accept retained DOS date')
            if not prompt(machine.text()):type_text('\r')
        dos('original COMMAND.COM with configured battery clock')
    try:
        boot('configured original BIOS and DOS boot')
        type_text('basica\r')
        wait(lambda s,t,h:'Ok' in t and 'BASIC' in t.upper(),'original BASICA 3.30',100000000)
        type_text('screen 2\r')
        wait(lambda s,t,h:s['graphicsMode']==1 and bool(s['mode']&16),'BASICA CGA-compatible 640x200')
        # Keep the drawing away from BASIC's legitimate console echo/Ok text.
        type_text('line (200,80)-(300,180),1,bf\r')
        def rectangle(s,t,h):
            v=bytes.fromhex(s['vram'])
            return all(v[32768+(y%2)*8192+(y//2)*80+25:32768+(y%2)*8192+(y//2)*80+25+12]==bytes([255])*12
                and v[32768+(y%2)*8192+(y//2)*80+25+12]&248==248 for y in range(80,181))
        wait(rectangle,'BASICA exact interleaved monochrome rectangle')
        type_text('screen 0\rsystem\r')
        dos('BASICA returns to DOS text mode')
        type_text('debug\r')
        wait(lambda s,t,h:t.rstrip().endswith('-'),'original DEBUG graphics harness')
        for mode,pixels in [(0x13,[(0,0,42),(100,100,42),(319,199,43)]),
                            (0x11,[(0,0,1),(100,100,1),(639,479,1)])]:
            code=['a100',f'mov ax,{mode:04x}','int 10']
            for x,y,color in pixels:
                code.extend([f'mov ax,{0xc00+color:04x}','xor bx,bx',
                    f'mov cx,{x:04x}',f'mov dx,{y:04x}','int 10'])
            code.extend(['xor ah,ah','int 16','mov ax,0003','int 10','int 20','','g=100'])
            type_text('\r'.join(code)+'\r')
            expected=bytearray(64000 if mode==0x13 else 38400)
            for x,y,color in pixels:
                if mode==0x13:expected[y*320+x]=color
                else:expected[y*80+x//8]|=128>>(x%8)
            wait(lambda s,t,h:s['graphicsMode']==(3 if mode==0x13 else 2) and
                bytes.fromhex(s['vram'])[:len(expected)]==expected,
                f'original BIOS mode {mode:02x}h and exact pixel framebuffer',100000000)
            (ROOT/f'work/display_mode_{mode:02x}.json').write_text(json.dumps(machine.state))
            type_text(' ')
            wait(lambda s,t,h:s['graphicsMode']==0 and t.rstrip().endswith('-'),
                'BIOS key wait returns to DEBUG in text mode')
        type_text('q\r');dos('DEBUG returns to DOS')
        machine.command('RESET');boot('configured clock survives CPU/board reset')
        print('PASS: original BASICA graphics, BIOS MCGA 13h/11h exact pixels and configured reboot',flush=True)
    finally:
        (ROOT/'work/display_software_final.json').write_text(json.dumps(machine.state))
        machine.close()


if __name__=='__main__':main()
