#!/usr/bin/env python3
"""Require cached-access tests to detect representative compiled faults."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'access_check_mutations'
MUTATIONS = [
    ('end_offset_wraps', "last_byte={1'b0,offset_i}+{1'b0,last_delta_i};",
     "last_byte={1'b0,(offset_i+last_delta_i)};"),
    ('expand_down_includes_limit', 'offset_i>limit_i', 'offset_i>=limit_i'),
    ('conforming_code_expands_down', 'expand_down=!access_i[3] && access_i[2];', 'expand_down=access_i[2];'),
    ('readable_code_writable', "1,3: permission_valid=!access_i[3] && access_i[1];", '1,3: permission_valid=access_i[1];'),
    ('execute_only_code_readable', '0: permission_valid=!access_i[3] || access_i[1];', "0: permission_valid=1'b1;"),
    ('ignores_unusable_cache', 'allow_o=cache_valid_i && access_i[4]', 'allow_o=access_i[4]'),
    ('stack_limit_raises_gp', "(stack_i ? 8'd12 : 8'd13)", "(stack_i ? 8'd13 : 8'd13)"),
    ('ffff_expand_down_is_full', '(offset_i>limit_i && !last_byte[16])',
     "(limit_i==16'hffff || (offset_i>limit_i && !last_byte[16]))"),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'access_check/Vintel_80286_access_check')],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    original = (ROOT / 'src/intel_80286_access_check.sv').read_text()
    results = []
    for name, old, new in MUTATIONS:
        if original.count(old) != 1:
            raise ValueError(f'Mutation must match once: {name}')
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        source = dest / 'intel_80286_access_check.sv'
        source.write_text(original.replace(old, new))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--Wno-UNUSEDSIGNAL', '--top-module', 'intel_80286_access_check',
                                '--Mdir', str(dest / 'obj'), str(source), str(ROOT / 'tb/access_check.cpp')],
                               text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286_access_check')], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'Access suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: cached-access tests detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
