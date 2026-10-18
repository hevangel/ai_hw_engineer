#!/usr/bin/env python3
"""DMA capture equivalence and complete disk/ID/check-field persistence."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]

def main():
    with tempfile.TemporaryDirectory(dir=ROOT/'work',prefix='hdd-test-') as temporary:
        directory=Path(temporary)
        processes=[]
        def start(name,fixture=False):
            environment={key:value for key,value in os.environ.items() if key not in
                ('IBM_PS2_MODEL30_NO_HDD','IBM_PS2_MODEL30_NVRAM_PATH','IBM_PS2_MODEL30_IO_TRACE')}
            environment.update(IBM_PS2_MODEL30_HDD_PATH=str(directory/f'{name}.m30'),
                IBM_PS2_MODEL30_FST_PATH=str(directory/f'{name}.fst'))
            args=[str(ROOT/'work/obj/Vibm_ps2_model30'),str(ROOT/'work/reference')]
            if fixture:args.extend(['--fixture',str(ROOT/'work/harddisk.bin')])
            process=subprocess.Popen(args,env=environment,stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,text=True,bufsize=1)
            processes.append(process)
            return process
        def command(process,line):
            process.stdin.write(line+'\n');process.stdin.flush()
            raw=process.stdout.readline();assert raw,'simulator exited'
            return json.loads(raw)
        try:
            machines=[start(name,True) for name in ('recorded','ordinary')]
            for process in machines:
                command(process,'RESET');state=command(process,'RUN 50000')
                assert state['hardDiskBusy'] and state['dma']>0,'capture must start during disk DMA'
            for clocks in (1,4096,65536):
                recorded=command(machines[0],f'CAPTURE {clocks}')
                ordinary=command(machines[1],f'RUN {clocks}')
                for state in (recorded,ordinary):
                    for key in ('captureStart','captureCycles','captureVersion'):state.pop(key)
                assert recorded==ordinary,'recording changed CPU/RAM/DMA/disk state'
                if recorded['hardDiskWrites']:
                    assert (directory/'recorded.m30').exists(),'capture pauses and saves media after its last clock'
            for index,process in enumerate(machines):
                command(process,f'SAVE 2 {directory}/{index}.m30')
                command(process,'PAUSE')
            bundle=(directory/'0.m30').read_bytes()
            assert bundle==(directory/'1.m30').read_bytes()
            assert bundle==(directory/'recorded.m30').read_bytes()
            assert bundle[:8]==b'M30DISK1' and len(bundle)==21806800
            assert bundle[8+67*512:8+69*512]==bytes(range(256))*4
            command(machines[0],f'SAVE 2 {directory}/raw.img')
            assert (directory/'raw.img').read_bytes()==bundle[8:8+21307392]
            restarted=start('recorded')
            command(restarted,f'SAVE 2 {directory}/restarted.m30')
            assert (directory/'restarted.m30').read_bytes()==bundle
            corrupt=bytearray(bundle);corrupt[100]^=1
            (directory/'corrupt.m30').write_bytes(corrupt)
            result=command(restarted,f'MOUNT 2 {directory}/corrupt.m30')
            assert 'checksum' in result['error']
            command(restarted,f'SAVE 2 {directory}/after-reject.m30')
            assert (directory/'after-reject.m30').read_bytes()==bundle
            result=command(restarted,'EJECT 0')
            assert not result['diskInserted']&1
            result=command(restarted,f'MOUNT 0 {ROOT}/work/reference/boot.img')
            assert result['diskInserted']&1
            print('PASS: HDD DMA waveform equals ordinary execution, complete media/check/ID export, atomic persistence across process restart, corrupt-bundle rejection without mutation, floppy eject/reinsert')
        finally:
            for process in processes:
                if process.poll() is None:
                    process.stdin.write('QUIT\n');process.stdin.flush();process.wait(timeout=15)
if __name__=='__main__':main()
