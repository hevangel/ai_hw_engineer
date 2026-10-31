#!/usr/bin/env python3
"""Detect representative protected-load defects using external-source contracts."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT=Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK=WORK_ROOT/'segment_mutations'
MUTATIONS=[
    ('ldt_index_zero_is_null','null_selector=selector_i[15:2]==0;',
     'null_selector=selector_i[15:3]==0;'),
    ('table_limit_excludes_last_byte','descriptor_last<={1\'b0,table_limit_i}',
     'descriptor_last<{1\'b0,table_limit_i}'),
    ('conforming_code_uses_data_privilege',
     '(access_byte[3] && access_byte[2]) || (rpl<=dpl && cpl_i<=dpl)',
     '(rpl<=dpl && cpl_i<=dpl)'),
    ('stack_not_present_uses_np','stack_i ? 8\'d12 : 8\'d11','8\'d11'),
    ('presence_precedes_type_privilege','if (!type_valid || !privilege_valid)',
     'if ((!type_valid || !privilege_valid) && access_byte[7])'),
    ('descriptor_base_bytes_reversed','base_o=descriptor_i[39:16];',
     'base_o={descriptor_i[23:16],descriptor_i[31:24],descriptor_i[39:32]};'),
]


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    original=(ROOT/'src/intel_80286_segment_check.sv').read_text()
    baseline=subprocess.run([str(WORK_ROOT/'segment_check/Vintel_80286_segment_check')],
                            text=True,capture_output=True,check=True)
    (WORK/'baseline.log').write_text(baseline.stdout+baseline.stderr)
    results=[]
    for name,old,new in MUTATIONS:
        if original.count(old)!=1: raise ValueError(f'Mutation must match once: {name}')
        dest=WORK/name
        dest.mkdir(exist_ok=True)
        source=dest/'intel_80286_segment_check.sv'
        source.write_text(original.replace(old,new))
        build=subprocess.run(['verilator','--cc','--exe','--build','-j','2','-Wall',
                              '--Wno-UNUSEDSIGNAL','--top-module','intel_80286_segment_check',
                              '--Mdir',str(dest/'obj'),str(source),str(ROOT/'tb/segment_check.cpp')],
                             text=True,capture_output=True)
        (dest/'build.log').write_text(build.stdout+build.stderr)
        if build.returncode: raise ValueError(f'Mutant must compile: {name}')
        run=subprocess.run([str(dest/'obj/Vintel_80286_segment_check')],text=True,capture_output=True)
        output=run.stdout+run.stderr
        (dest/'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output: raise ValueError(f'Segment suite missed: {name}')
        results.append({'mutation':name,'result':'detected','diagnostic':output.strip()})
        print(f'PASS: external-source segment contracts detected {name}',flush=True)
    (WORK/'results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':main()
