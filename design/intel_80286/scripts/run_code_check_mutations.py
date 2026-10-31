#!/usr/bin/env python3
"""Require the ordinary CS checker suite to detect compiled semantic faults."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'code_check_mutations'
MUTATIONS = [
    ('accepts_data_as_code', '!rights[3] || !privilege_valid', '!privilege_valid'),
    ('nonconforming_rpl_reversed', 'selector_i[1:0]<=cpl_i', 'selector_i[1:0]>=cpl_i'),
    ('conforming_checks_rpl', 'rights[2] ? rights[6:5]<=cpl_i :',
     'rights[2] ? (rights[6:5]<=cpl_i && selector_i[1:0]<=cpl_i) :'),
    ('absence_precedes_bad_type', '!rights[3] || !privilege_valid',
     '(!rights[3] || !privilege_valid) && rights[7]'),
    ('bad_ip_precedes_bad_stack', 'call_i && !stack_ok_i',
     'call_i && !stack_ok_i && offset_i<=descriptor_i[15:0]'),
    ('cs_rpl_not_normalized', 'selector_o={selector_i[15:2],cpl_i};', 'selector_o=selector_i;'),
    ('accepts_system_descriptor', 'if (!rights[4]) special_o=1;', 'if (!rights[4]) cache_valid_o=1;'),
    ('rejects_inclusive_code_limit', 'offset_i>descriptor_i[15:0]', 'offset_i>=descriptor_i[15:0]'),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'code_check/Vintel_80286_code_check')],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    original = (ROOT / 'src/intel_80286_code_check.sv').read_text()
    results = []
    for name, old, new in MUTATIONS:
        if original.count(old) != 1:
            raise ValueError(f'Mutation must match once: {name}')
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        source = dest / 'intel_80286_code_check.sv'
        source.write_text(original.replace(old, new))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--top-module', 'intel_80286_code_check', '--Mdir', str(dest / 'obj'),
                                str(source), str(ROOT / 'tb/code_check.cpp')],
                               text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286_code_check')], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'Code-check suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: ordinary CS checks detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
