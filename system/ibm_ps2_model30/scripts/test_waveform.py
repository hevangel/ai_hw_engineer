#!/usr/bin/env python3
"""Recording must preserve the exact RTL state of an ordinary clock run."""
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def main():
    machines=[]
    try:
        for name in ('recorded','ordinary'):
            machines.append(subprocess.Popen(
                [str(ROOT/'work/obj/Vibm_ps2_model30'),str(ROOT/'work/reference')],
                env={**os.environ,'IBM_PS2_MODEL30_FST_PATH':str(ROOT/f'work/{name}.fst')},
                stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,bufsize=1))
        def command(index,line):
            machine=machines[index]
            machine.stdin.write(line+'\n');machine.stdin.flush()
            return json.loads(machine.stdout.readline())
        for i in range(2):command(i,'RESET')
        version=0
        for warmup in (0,1000000):
            for i in range(2):command(i,f'RUN {warmup}')
            for clocks in (1,4096,65536):
                before=command(0,'STATE')['cycles']
                recorded=command(0,f'CAPTURE {clocks}')
                ordinary=command(1,f'RUN {clocks}')
                version+=1
                assert recorded['captureVersion']==version
                assert recorded['captureStart']==before and recorded['cycles']==before+clocks
                for state in (recorded,ordinary):
                    for key in ('captureStart','captureCycles','captureVersion'):state.pop(key)
                assert recorded==ordinary,'capture changed CPU, RAM/video, keyboard or peripheral state'
        print('PASS: six bounded FST captures equal ordinary RTL execution, including CPU registers/PC, VRAM and peripheral counters')
    finally:
        for machine in machines:
            if machine.poll() is None:
                machine.stdin.write('QUIT\n');machine.stdin.flush();machine.wait(timeout=10)

if __name__=='__main__':main()
