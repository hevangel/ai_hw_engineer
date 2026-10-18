#!/usr/bin/env python3
"""Battery storage is restored only through the reset-only external interface."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    binary=str(ROOT/'work/obj/Vibm_ps2_model30')
    with tempfile.TemporaryDirectory(dir=ROOT/'work') as directory:
        image=Path(directory)/'rtc.bin'
        environment={**os.environ,'IBM_PS2_MODEL30_NVRAM_PATH':str(image)}
        subprocess.run([binary,str(ROOT/'work/reference'),'--board-tests',str(ROOT/'work/board.bin')],
                       env=environment,check=True,capture_output=True,text=True)
        saved=image.read_bytes()
        assert len(saved)==32 and saved[9]==0x87
        process=subprocess.run([binary,str(ROOT/'work/reference')],input='STATE\nRESET\nOFF\nQUIT\n',
                               env=environment,check=True,capture_output=True,text=True)
        states=[json.loads(line) for line in process.stdout.splitlines()]
        assert len(states)==3
        for state in states:
            assert state['cycles']==0 and state['instructions']==0
            assert state['rtc'][8:16]==list(saved[8:16])
            assert (state['cs'],state['ip'])==(65535,0)
        assert image.read_bytes()[8:16]==saved[8:16]
        image.write_bytes(saved[:-1])
        invalid=subprocess.run([binary,str(ROOT/'work/reference')],input='QUIT\n',env=environment,
                               capture_output=True,text=True)
        assert invalid.returncode!=0 and '32 bytes' in invalid.stderr
    print('PASS: CPU-written RTC battery RAM survives process restart and reset; invalid images rejected')

if __name__=='__main__':main()
