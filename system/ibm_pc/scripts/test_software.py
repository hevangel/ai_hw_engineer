#!/usr/bin/env python3
"""Boot original firmware/PC DOS; type through real scan-code IRQs, no hooks."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LETTERS = dict(zip('qwertyuiopasdfghjklzxcvbnm',
                   [16,17,18,19,20,21,22,23,24,25,30,31,32,33,34,35,36,37,38,44,45,46,47,48,49,50]))
SCAN = {**LETTERS, **dict(zip('1234567890',range(2,12))),
        ' ':57,'\r':28,'-':12,'=':13,',':51,'.':52,'/':53,';':39,'[':26,']':27}
SHIFT = {':':';','"':"'",'*':'8','(':'9',')':'0','+':'=','?':'/','!':'1'}
SCAN["'"] = 40

def screen(state):
    ram = bytes.fromhex(state['vram'])
    cols = 80 if state['mode'] & 1 else 40
    start = ((state['crtc'][12]<<8)|state['crtc'][13])*2
    return '\n'.join(''.join(chr(ram[(start+2*(row*cols+col))&16383])
        if 32<=ram[(start+2*(row*cols+col))&16383]<127 else ' '
        for col in range(cols)) for row in range(25))

def disk_file(image,name):
    """Independent FAT12 check using the archive's PC160K volume geometry."""
    for position in range(3*512,7*512,32):
        entry=image[position:position+32]
        if entry[:11]==name:
            cluster=int.from_bytes(entry[26:28],'little')
            size=int.from_bytes(entry[28:32],'little');data=bytearray();visited=set()
            while len(data)<size:
                assert 2<=cluster<0xff0 and cluster not in visited,'invalid FAT12 chain'
                visited.add(cluster);start=(7+cluster-2)*512
                data.extend(image[start:start+512]);offset=512+cluster+cluster//2
                pair=int.from_bytes(image[offset:offset+2],'little')
                cluster=pair>>4 if cluster&1 else pair&0xfff
            return bytes(data[:size])
    raise AssertionError('missing FAT12 file '+repr(name))

def main():
    ROOT.joinpath('work').mkdir(exist_ok=True)
    with (ROOT/'work/software_trace.log').open('w') as errors:
        process = subprocess.Popen([str(ROOT/'work/obj/Vibm_pc'),str(ROOT/'work/reference')],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors, text=True,bufsize=1)
        frames=[]
        def command(line):
            process.stdin.write(line+'\n');process.stdin.flush()
            data=process.stdout.readline()
            if not data:
                raise RuntimeError('RTL simulator exited; inspect software_trace.log')
            state=json.loads(data)
            assert not state['fault'] and state['postErrors']==0, 'BIOS/CPU diagnostic'
            return state
        state=command('STATE')
        def wait(predicate,limit=40000000,label='screen'):
            nonlocal state
            stop=state['cycles']+limit
            seen=[]
            while True:
                text=screen(state);seen.append(text);frames.append(text)
                if predicate(state,text,'\n'.join(seen)):
                    print(f'PASS: {label} at {state["cycles"]} clocks, {state["instructions"]} instructions',flush=True)
                    return '\n'.join(seen)
                assert 'bad-disk unusable' not in text.lower(), f'{label}: DOS reported a bad disk\n{text}'
                if state['cycles']>=stop:
                    raise AssertionError(f'{label} timeout at {state["cs"]:04x}:{state["ip"]:04x}\n{text}')
                state=command('RUN 1000000')
        def type_text(text):
            nonlocal state
            for char in text:
                shifted=char in SHIFT or char.isupper()
                key=SCAN[SHIFT.get(char,char.lower())]
                if shifted: state=command('KEY 42')
                state=command(f'KEY {key}');state=command(f'KEY {key|128}')
                if shifted: state=command('KEY 170')
        try:
            assert (state['cs'],state['ip'],state['instructions'])==(65535,0,0)
            first=command('STEP')
            assert (first['cs'],first['ip'],first['instructions'])==(0xf000,0xe05b,1)
            state=command('RESET')
            wait(lambda s,t,h:"Enter today's date" in t,180000000,'unchanged IBM POST and PC DOS disk boot')
            assert state['mediaReads']>8192 and state['dma']>state['refresh']>1000
            type_text('10-14-81\r')
            wait(lambda s,t,h:s['keysQueued']==0 and 'Version 1.00' in t and
                 t.rstrip().endswith('A>'),label='keyboard date entry and original COMMAND.COM prompt')
            type_text('dir\r')
            listing=wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'COMMAND\s+COM',h) and
                         t.rstrip().endswith('A>'),label='DIR through FDC/DMA and FAT12')
            assert re.search(r'IBMBIO\s+COM|BASICA\s+COM|DONKEY\s+BAS',listing)
            type_text('chkdsk\r')
            wait(lambda s,t,h:s['keysQueued']==0 and ('bytes' in h.lower()) and
                 t.rstrip().endswith('A>'),label='original CHKDSK.COM')
            type_text('format b:\r')
            wait(lambda s,t,h:'Insert new diskette for drive B:' in t and
                 'strike any key when ready' in t,label='original FORMAT.COM prompt')
            type_text('\r')
            wait(lambda s,t,h:s['keysQueued']==0 and 'Format complete' in h and
                 'Format another (Y/N)?' in t,240000000,'FORMAT all 40 tracks through FDC/DMA')
            type_text('n')
            wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('A>'),label='FORMAT returns to DOS')
            writes=state['mediaWrites']
            type_text('copy time.com b:clock.com\r')
            wait(lambda s,t,h:s['keysQueued']==0 and s['mediaWrites']>writes and
                 t.rstrip().endswith('A>'),label='COPY writes drive B through DMA and FDC')
            type_text('dir b:\r')
            wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'CLOCK\s+COM',t) and
                 t.rstrip().endswith('A>'),label='read back drive B directory')
            command(f'SAVE 1 {ROOT}/work/copied_workdisk.img')
            assert disk_file((ROOT/'work/copied_workdisk.img').read_bytes(),b'CLOCK   COM')==\
                disk_file((ROOT/'work/reference/pcdos100.img').read_bytes(),b'TIME    COM')
            print('PASS: independent FAT12 byte comparison of DOS-created file',flush=True)
            type_text('basic\r')
            wait(lambda s,t,h:'Ok' in t and ('Basic' in t or 'BASIC' in t),label='original BASIC.COM and Cassette BASIC ROM')
            type_text('print 6*7\r')
            wait(lambda s,t,h:s['keysQueued']==0 and re.search(r'\b42\b',t) and
                 t.rsplit('\n',1)[0].rstrip().endswith('Ok'),label='BASIC expression through keyboard IRQs')
            type_text('system\r')
            wait(lambda s,t,h:s['keysQueued']==0 and t.rstrip().endswith('A>'),label='BASIC returns to DOS')
            before=state['mediaReads']
            type_text('basica donkey\r')
            wait(lambda s,t,h:s['keysQueued']==0 and 'DONKEY' in t and
                 'Press space bar to continue' in t,80000000,'original DONKEY title and start prompt')
            type_text(' ')
            wait(lambda s,t,h:s['keysQueued']==0 and (s['mode']&2) and
                 state['mediaReads']>before and len(set(bytes.fromhex(s['vram'])))>6,
                 80000000,'original DONKEY.BAS in CGA graphics')
            first_frame=state['vram']
            type_text(' ')
            state=command('RUN 3000000')
            assert state['keysQueued']==0 and state['mode']&2 and state['vram']!=first_frame
            (ROOT/'work/software_final.json').write_text(json.dumps(state,indent=2)+'\n')
            (ROOT/'work/software_frames.txt').write_text('\n\n--- FRAME ---\n\n'.join(frames))
            print('PASS: full IBM PC historical software regression, no CPU/BIOS/DOS interception',flush=True)
        finally:
            if process.poll() is None:
                process.stdin.write('QUIT\n');process.stdin.flush();process.wait(timeout=10)

if __name__=='__main__':
    main()
