#!/usr/bin/env python3
"""Check CPU interrupt-test sensitivity; altered copies stay under ignored work/."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT=Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK=WORK_ROOT/'irq_mutations'
MUTATIONS=[
    ('intr_ignores_if', '.if_i(flags[9] &&', '.if_i(1\'b1 &&'),
    ('sti_shadow_missing',
     '.if_i(flags[9] && !sti_shadow && !(state==STRING_BOUNDARY && instruction_sti_shadow))',
     '.if_i(flags[9])'),
    ('ss_shadow_missing',
     '.inhibit_i(ss_shadow || (state==STRING_BOUNDARY && instruction_ss_shadow))',
     '.inhibit_i(1\'b0)'),
    ('iret_does_not_unblock_nmi', '.iret_i(state==FAR_RETURN_DONE && opcode==8\'hcf)', '.iret_i(1\'b0)'),
    ('rep_restart_skips_prefix', 'state==STRING_POLL ? instruction_ip : ip',
     'state==STRING_POLL ? instruction_ip+16\'d1 : ip'),
    ('hlt_restart_reexecutes_hlt', 'state==STRING_POLL ? instruction_ip : ip',
     'state==STRING_POLL ? instruction_ip : (halt_latch ? ip-16\'d1 : ip)'),
    ('hardware_entry_retires_instruction',
     'enter_event(async_vector,state==STRING_POLL ? instruction_ip : ip,1\'b0)',
     'enter_event(async_vector,state==STRING_POLL ? instruction_ip : ip,1\'b1)'),
    ('rep_cannot_be_interrupted',
     'if (repeat_valid && gpr[1]!=1 && (!string_compare || alu_flags[6]!=repeat_ne)) state<=STRING_BOUNDARY;',
     'if (repeat_valid && gpr[1]!=1 && (!string_compare || alu_flags[6]!=repeat_ne)) state<=STRING_START;'),
]


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    baseline=subprocess.run([str(WORK_ROOT/'sim/Vintel_80286'),'--interrupts'],
                            text=True,capture_output=True,check=True)
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
        # Disabled shadows deliberately leave unused history bits in mutants.
        # Baseline builds retain strict -Wall with no warning suppression.
        (dest/'build.log').write_text(build.stdout+build.stderr)
        if build.returncode: raise ValueError(f'Mutant must build: {name}')
        run=subprocess.run([str(dest/'obj/Vintel_80286'),'--interrupts'],text=True,capture_output=True)
        output=run.stdout+run.stderr
        (dest/'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output: raise ValueError(f'CPU interrupt tests missed: {name}')
        results.append({'mutation':name,'result':'detected','diagnostic':output.strip()})
        print(f'PASS: CPU interrupt tests detected {name}',flush=True)
    (WORK/'results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':main()
