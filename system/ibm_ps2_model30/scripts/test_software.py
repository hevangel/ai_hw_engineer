#!/usr/bin/env python3
"""Original ROM/DOS regression: all CPU, interrupts and disk commands run in RTL."""
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LETTERS = dict(zip('qwertyuiopasdfghjklzxcvbnm',
    [16,17,18,19,20,21,22,23,24,25,30,31,32,33,34,35,36,37,38,44,45,46,47,48,49,50]))
SCAN = {**LETTERS, **dict(zip('1234567890', range(2,12))),
        ' ':57,'\r':28,'-':12,'=':13,',':51,'.':52,'/':53,';':39,'[':26,']':27,"'":40}
SHIFT = {':':';','"':"'",'*':'8','(':'9',')':'0','+':'=','?':'/','!':'1','<':',','>':'.'}


def screen(state):
    ram = bytes.fromhex(state['vram'])
    cols = 80 if state['mode'] & 1 else 40
    start = ((state['crtc'][12]<<8)|state['crtc'][13])*2
    return '\n'.join(''.join(chr(c) if 32<=c<127 else ' ' for c in
        (ram[32768+((start+2*(row*cols+col))&32767)] for col in range(cols)))
        for row in range(25))


def disk_file(image, name):
    """Independent BPB/FAT12 reader; compare DOS-written bytes, not just its output."""
    word = lambda offset: int.from_bytes(image[offset:offset+2], 'little')
    size, cluster_sectors, reserved, fats = word(11), image[13], word(14), image[16]
    roots, fat_sectors = word(17), word(22)
    assert size==512 and cluster_sectors and fats==2
    root = (reserved+fats*fat_sectors)*size
    data = root+((roots*32+size-1)//size)*size
    for position in range(root, root+roots*32, 32):
        entry = image[position:position+32]
        if entry[:11]!=name:
            continue
        cluster = int.from_bytes(entry[26:28], 'little')
        length = int.from_bytes(entry[28:32], 'little')
        result, visited = bytearray(), set()
        while len(result)<length:
            assert 2<=cluster<0xff0 and cluster not in visited, 'invalid FAT12 chain'
            visited.add(cluster)
            offset = data+(cluster-2)*cluster_sectors*size
            result.extend(image[offset:offset+cluster_sectors*size])
            offset = reserved*size+cluster+cluster//2
            pair = int.from_bytes(image[offset:offset+2], 'little')
            cluster = pair>>4 if cluster&1 else pair&0xfff
        return bytes(result[:length])
    raise AssertionError('missing FAT12 file '+repr(name))


def prompt(text):
    return bool(re.search(r'A(?:\\)?>$', text.rstrip()))


def main():
    frames = []
    environment = {key:value for key,value in os.environ.items()
                   if key not in ('IBM_PS2_MODEL30_NVRAM_PATH','IBM_PS2_MODEL30_HDD_PATH','IBM_PS2_MODEL30_IO_TRACE')}
    environment['IBM_PS2_MODEL30_NO_HDD']='1'
    if os.environ.get('IBM_PS2_MODEL30_SOFTWARE_TRACE'):
        environment['IBM_PS2_MODEL30_IO_TRACE']='1'
    with (ROOT/'work/software_trace.log').open('w') as errors:
        process = subprocess.Popen([str(ROOT/'work/obj/Vibm_ps2_model30'), str(ROOT/'work/reference')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors, text=True,
            bufsize=1, env=environment)
        def command(line):
            process.stdin.write(line+'\n'); process.stdin.flush()
            data = process.stdout.readline()
            if not data:
                raise RuntimeError('RTL simulator exited; inspect software_trace.log')
            result = json.loads(data)
            assert not result['fault'] and result['postErrors']<=1, 'CPU/POST failure'
            return result
        state = command('RESET')
        def wait(predicate, limit=60000000, label='screen'):
            nonlocal state
            stop = state['cycles']+limit
            seen = []
            while True:
                text = screen(state); seen.append(text); frames.append(text)
                if predicate(state,text,'\n'.join(seen)):
                    print(f'PASS: {label} at {state["cycles"]} clocks, {state["instructions"]} instructions', flush=True)
                    (ROOT/'work/software_progress.json').write_text(json.dumps(state)+'\n')
                    return '\n'.join(seen)
                if 'Format failure' in text:
                    raise AssertionError('Original FORMAT reports failure\n'+text)
                if state['cycles']>=stop:
                    raise AssertionError(f'{label} timeout at {state["cs"]:04x}:{state["ip"]:04x}\n{text}')
                state = command('RUN 1000000')
                if state['cycles']%50000000==0:
                    print(f'RUN: {label}, {state["cycles"]} clocks, DMA {state["dma"]}',flush=True)
        def type_text(text):
            nonlocal state
            assert state['scanSet']==1, 'original BIOS must select scan set 1'
            for char in text:
                shifted = char in SHIFT or char.isupper()
                key = SCAN[SHIFT.get(char,char.lower())]
                if shifted: state=command('KEY 42')
                state=command(f'KEY {key}'); state=command(f'KEY {key|128}')
                if shifted: state=command('KEY 170')
            state=command('RUN 1000000')
        try:
            assert (state['cs'],state['ip'],state['instructions'])==(65535,0,0)
            state=command('STEP')
            assert (state['cs'],state['ip'],state['instructions'])==(0xf000,0xe05b,1)
            state=command('RESET')
            wait(lambda s,t,h:'640KB OK' in t and '161-Set Date and Time' in t and
                 'RESUME' in t,190000000,'unchanged IBM POST; expected fresh-battery setup notice only')
            assert state['postErrors']==1
            state=command('KEY 59'); state=command('KEY 187')
            wait(lambda s,t,h:'Enter new date' in t or prompt(t),150000000,'PC DOS 3.30 floppy boot')
            assert state['mediaReads']>16384 and state['dma']>16384 and state['refresh']>1000
            if not prompt(screen(state)):
                type_text('10-15-87\r')
                wait(lambda s,t,h:'Enter new time' in t or prompt(t),label='DOS date entry')
                if not prompt(screen(state)):
                    type_text('12:34:56\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='original COMMAND.COM prompt')
            type_text('date\r')
            wait(lambda s,t,h:'Enter new date' in t,label='original DOS DATE command')
            type_text('10-15-87\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='original DOS DATE updates its system date')
            type_text('time\r')
            wait(lambda s,t,h:'Enter new time' in t,label='original DOS TIME command')
            type_text('12:34:56\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='original DOS TIME updates its system time')
            # With an invalid cold-battery checksum, DOS's boot-time RTC
            # probe disables hardware clock updates (original IBMBIO 35D6).
            # Use unmodified DEBUG.COM to execute IBM's documented INT 1A
            # setters in real RTL; no CPU registers or BIOS bytes are injected.
            type_text('debug\r')
            wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('-'),
                 label='original DEBUG.COM')
            type_text('a100\rmov ah,5\rmov cx,1987\rmov dx,1015\rint 1a\r'
                      'mov ah,3\rmov cx,1234\rmov dx,5600\rint 1a\rint 20\r\r'
                      'g=100\rq\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),
                 label='DEBUG executes original BIOS RTC date/time services')
            assert state['rtc'][9]==0x87 and state['rtc'][6:8]==[0x15,0x10]
            assert state['rtc'][3:5]==[0x34,0x12]
            type_text('dir\r')
            wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'COMMAND\s+COM',h) and
                 prompt(t),label='DIR through FDC/DMA and FAT12')
            type_text('chkdsk\r')
            wait(lambda s,t,h:s['keysQueued']==0 and 'bytes' in h.lower() and prompt(t),
                 label='original CHKDSK.COM')
            type_text('format b:\r')
            wait(lambda s,t,h:'Insert new diskette for drive B:' in t and
                 re.search(r'strike (?:any key|ENTER) when ready',t,re.I),label='original FORMAT.COM prompt')
            type_text('\r')
            wait(lambda s,t,h:'Format complete' in h and ('Volume label' in t or
                 re.search(r'Format another.*\(Y/N\)',t,re.I)),900000000,'FORMAT all 80 cylinders and both heads')
            if 'Volume label' in screen(state):
                type_text('\r')
                wait(lambda s,t,h:re.search(r'Format another.*\(Y/N\)',t,re.I),label='formatted 720K volume label')
            # 720K FAT12 reserves 14 sectors and uses 1,426 data sectors.
            assert '730112' in ''.join(frames[-30:]).replace(',','').replace(' ','')
            assert state['mediaWrites']>=737280, 'FORMAT must write every physical sector'
            type_text('n\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='FORMAT returns to DOS')
            writes=state['mediaWrites']
            type_text('copy chkdsk.com b:check.com\r')
            wait(lambda s,t,h:s['keysQueued']==0 and s['mediaWrites']>writes and prompt(t),
                 label='COPY writes drive B through DMA and FDC')
            type_text('dir b:\r')
            wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'CHECK\s+COM',t) and prompt(t),
                 label='read back drive B directory')
            command(f'SAVE 1 {ROOT}/work/copied_workdisk.img')
            image=(ROOT/'work/copied_workdisk.img').read_bytes()
            word=lambda offset:int.from_bytes(image[offset:offset+2],'little')
            assert len(image)==737280 and (word(19),word(24),word(26))==(1440,9,2)
            assert disk_file(image,b'CHECK   COM')==\
                disk_file((ROOT/'work/reference/pcdos330.img').read_bytes(),b'CHKDSK  COM')
            print('PASS: independent FAT12 comparison of DOS-created file',flush=True)
            type_text('basica\r')
            wait(lambda s,t,h:'Ok' in t and 'BASIC' in t.upper(),100000000,'original BASICA interpreter')
            type_text('print 6*7\r')
            wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'\b42\b',t),label='BASIC expression')
            type_text('system\r')
            wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='return from BASICA to DOS')
            command(f'SAVE 0 {ROOT}/work/software_bootdisk.img')
            (ROOT/'work/software_final.json').write_text(json.dumps(state)+'\n')
            (ROOT/'work/software_rtc.bin').write_bytes(bytes(state['rtc']))
            state=command('RESET')
            wait(lambda s,t,h:s['mediaReads']>16384 and s['dma']>16384 and
                 (prompt(t) or 'Enter new date' in t),260000000,
                 'configured clock survives reset; unchanged POST and DOS reboot')
            assert state['postErrors']==0
            if not prompt(screen(state)):
                type_text('\r')
                wait(lambda s,t,h:prompt(t) or 'Enter new time' in t,label='reboot retains the configured date')
                if not prompt(screen(state)):
                    type_text('\r')
                wait(lambda s,t,h:s['keysQueued']==0 and prompt(t),label='reboot returns to COMMAND.COM')
            print('PASS: Model 30 DOS/floppy/BASIC regression, no CPU/BIOS/DOS interception',flush=True)
        finally:
            (ROOT/'work/software_last_state.json').write_text(json.dumps(state))
            if process.poll() is None:
                command(f'SAVE 1 {ROOT}/work/software_last_floppy.img')
            (ROOT/'work/software_frames.txt').write_text('\n\n--- FRAME ---\n\n'.join(frames))
            if process.poll() is None:
                process.stdin.write('QUIT\n'); process.stdin.flush(); process.wait(timeout=10)


if __name__=='__main__':main()
