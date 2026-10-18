"""Drive unchanged historical software through RTL and keyboard scan codes."""
import json
import os
from pathlib import Path
import subprocess
from test_software import screen,SCAN,SHIFT

ROOT=Path(__file__).resolve().parents[1]

class HistoricalMachine:
    def __init__(self,name,environment=None):
        self.name=name
        self.frames=[]
        env={key:value for key,value in os.environ.items() if key not in
            ('IBM_PS2_MODEL30_NO_HDD','IBM_PS2_MODEL30_NVRAM_PATH',
             'IBM_PS2_MODEL30_HDD_PATH','IBM_PS2_MODEL30_IO_TRACE')}
        env.update(environment or {})
        self.log=(ROOT/f'work/{name}_trace.log').open('w',encoding='utf-8')
        self.process=subprocess.Popen([str(ROOT/'work/obj/Vibm_ps2_model30'),
            str(ROOT/'work/reference')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
            stderr=self.log,text=True,bufsize=1,env=env)
        self.state=self.command('RESET')

    def command(self,line):
        self.process.stdin.write(line+'\n');self.process.stdin.flush()
        raw=self.process.stdout.readline()
        if not raw:raise RuntimeError(f'RTL exited; inspect {self.name}_trace.log')
        self.state=json.loads(raw)
        if line.startswith('RUN ') or line=='RESET':
            (ROOT/f'work/{self.name}_current.json').write_text(json.dumps(self.state))
        assert not self.state.get('error'),self.state.get('error')
        assert not self.state['fault'],'CPU fault'
        return self.state

    def text(self):return screen(self.state)

    def wait(self,predicate,label,limit=60000000):
        stop=self.state['cycles']+limit
        seen=[]
        while True:
            text=self.text();seen.append(text);self.frames.append(text)
            if predicate(self.state,text,'\n'.join(seen)):
                print(f'PASS: {label} at {self.state["cycles"]} clocks; '
                    f'DMA {self.state["dma"]}, HDD writes {self.state["hardDiskWrites"]}',flush=True)
                (ROOT/f'work/{self.name}_progress.json').write_text(json.dumps(self.state))
                return '\n'.join(seen)
            if self.state['cycles']>=stop:
                raise AssertionError(f'{label} timeout at {self.state["cs"]:04x}:'
                    f'{self.state["ip"]:04x}\n{text}')
            self.command('RUN 1000000')
            if self.state['cycles']%50000000==0:
                print(f'RUN: {label}, {self.state["cycles"]} clocks',flush=True)

    def type(self,text,clocks_per_key=0):
        assert self.state['scanSet']==1,'original BIOS must select set 1'
        for char in text:
            if char=='\x1b':key=1;shifted=False
            else:
                shifted=char in SHIFT or char.isupper()
                key=SCAN[SHIFT.get(char,char.lower())]
            if shifted:self.command('KEY 42')
            self.command(f'KEY {key}');self.command(f'KEY {key|128}')
            if shifted:self.command('KEY 170')
            if clocks_per_key:self.command(f'RUN {clocks_per_key}')
        self.command('RUN 1000000')

    def close(self):
        (ROOT/f'work/{self.name}_frames.txt').write_text('\n\n--- FRAME ---\n\n'.join(self.frames))
        if self.process.poll() is None:
            self.process.stdin.write('QUIT\n');self.process.stdin.flush();self.process.wait(timeout=15)
        self.log.close()
