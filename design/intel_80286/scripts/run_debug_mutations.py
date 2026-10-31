#!/usr/bin/env python3
"""Require exact debug-trap contracts to detect four representative CPU defects."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT=Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK=WORK_ROOT/'debug_mutations'
MUTATIONS=[
    ('tf_uses_post_instruction_flags','assign async_step = instruction_tf &&','assign async_step = flags[8] &&'),
    ('software_int_steps_handler','state==BOUNDARY && retire_o && !event_o','state==BOUNDARY && retire_o'),
    ('rep_has_no_element_step','(state==STRING_BOUNDARY && element_o)','(1\'b0)'),
    ('hlt_loses_step_boundary','8\'hf4: begin state <= BOUNDARY; halt_latch<=1; end',
     '8\'hf4: begin state <= HALTED; halt_latch<=1; end'),
]


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    baseline=subprocess.run([str(WORK_ROOT/'sim/Vintel_80286'),'--debug'],text=True,capture_output=True,check=True)
    (WORK/'baseline.log').write_text(baseline.stdout+baseline.stderr)
    results=[]
    for name,old,new in MUTATIONS:
        dest=WORK/name
        dest.mkdir(exist_ok=True)
        sources=[]
        for source in sorted((ROOT/'src').glob('*.sv')):
            content=source.read_text()
            if source.name=='intel_80286.sv':
                if content.count(old)!=1: raise ValueError(f'Mutation must match once: {name}')
                content=content.replace(old,new)
            copy=dest/source.name
            copy.write_text(content)
            sources.append(str(copy))
        build=subprocess.run(['verilator','--cc','--exe','--build','-j','2','-Wall',
                              '--Wno-UNUSEDSIGNAL','--top-module','intel_80286',
                              '--Mdir',str(dest/'obj'),*sources,str(ROOT/'tb/bootstrap.cpp')],
                             text=True,capture_output=True)
        (dest/'build.log').write_text(build.stdout+build.stderr)
        if build.returncode: raise ValueError(f'Mutant must compile: {name}')
        run=subprocess.run([str(dest/'obj/Vintel_80286'),'--debug'],text=True,capture_output=True)
        output=run.stdout+run.stderr
        (dest/'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output: raise ValueError(f'Debug suite missed: {name}')
        results.append({'mutation':name,'result':'detected','diagnostic':output.strip()})
        print(f'PASS: exact debug contracts detected {name}',flush=True)
    (WORK/'results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':main()
