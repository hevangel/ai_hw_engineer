#!/usr/bin/env python3
"""Require descriptor transaction tests to reject compiled protocol defects."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT=Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK=WORK_ROOT/'segment_load_mutations'
MUTATIONS=[
    ('reads_only_six_bytes','if (byte_index==7) state<=VALIDATE;',
     'if (byte_index==5) state<=VALIDATE;'),
    ('accessed_write_wrong_byte','state==WRITE_ACCESSED ? 24\'d5',
     'state==WRITE_ACCESSED ? 24\'d4'),
    ('publishes_before_accessed_write',
     'VALIDATE: if (check_fault) complete_load(); else state<=WRITE_ACCESSED;',
     'VALIDATE: complete_load();'),
    ('skips_already_accessed_write',
     'VALIDATE: if (check_fault) complete_load(); else state<=WRITE_ACCESSED;',
     'VALIDATE: if (check_fault || descriptor[40]) complete_load(); else state<=WRITE_ACCESSED;'),
    ('uses_live_table_base','descriptor_address<=saved_table_base+{8\'h0,check_offset};',
     'descriptor_address<=gdt_base_i+{8\'h0,check_offset};'),
    ('new_start_exposes_partial_selector','descriptor<=0; byte_index<=0; state<=PRECHECK;',
     'descriptor<=0; byte_index<=0; state<=PRECHECK; selector_o<=selector_i;'),
    ('accessed_bit_not_set','assign bus_wdata_o=check_accessed;',
     'assign bus_wdata_o=check_access;'),
]


def main():
    WORK.mkdir(parents=True,exist_ok=True)
    original=(ROOT/'src/intel_80286_segment_load.sv').read_text()
    baseline=subprocess.run([str(WORK_ROOT/'segment_load/Vintel_80286_segment_load')],
                            text=True,capture_output=True,check=True)
    (WORK/'baseline.log').write_text(baseline.stdout+baseline.stderr)
    results=[]
    for name,old,new in MUTATIONS:
        if original.count(old)!=1: raise ValueError(f'Mutation must match once: {name}')
        dest=WORK/name
        dest.mkdir(exist_ok=True)
        source=dest/'intel_80286_segment_load.sv'
        source.write_text(original.replace(old,new))
        checker=dest/'intel_80286_segment_check.sv'
        checker.write_text((ROOT/'src/intel_80286_segment_check.sv').read_text())
        build=subprocess.run(['verilator','--cc','--exe','--build','-j','2','-Wall',
                              '--Wno-UNUSEDSIGNAL','--top-module','intel_80286_segment_load',
                              '--Mdir',str(dest/'obj'),str(checker),str(source),str(ROOT/'tb/segment_load.cpp')],
                             text=True,capture_output=True)
        (dest/'build.log').write_text(build.stdout+build.stderr)
        if build.returncode: raise ValueError(f'Mutant must compile: {name}')
        run=subprocess.run([str(dest/'obj/Vintel_80286_segment_load')],text=True,capture_output=True)
        output=run.stdout+run.stderr
        (dest/'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output: raise ValueError(f'Loader suite missed: {name}')
        results.append({'mutation':name,'result':'detected','diagnostic':output.strip()})
        print(f'PASS: descriptor transaction tests detected {name}',flush=True)
    (WORK/'results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':main()
