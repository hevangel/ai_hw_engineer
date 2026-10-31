#!/usr/bin/env python3
"""Require connected-core tests to reject compiled reference-routing defects."""
import argparse
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'reference_mutations'
MUTATIONS = [
    ('fetch_asserts_write',
     'assign bus_write_o = state == BUS && memory_write;',
     'assign bus_write_o = (state == BUS && memory_write) || bus_fetch_o;'),
    ('wrong_segment_role', 'memory_role<=role;', "memory_role<=role ^ 2'd1;"),
    ('wrong_operand_offset', 'memory_offset<=offset_value;', "memory_offset<=offset_value+16'd1;"),
    ('rmw_loses_write_check', 'memory_kind<=3;', 'memory_kind<=0;'),
    ('io_marked_segmented', 'memory_segmented<=segmented;', "memory_segmented<=1'b1;"),
    ('fetch_uses_ds', ".role_i(2'd1),.kind_i(2'd2)", ".role_i(2'd3),.kind_i(2'd2)"),
    ('writeback_ignores_override',
     "memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,data}, COMMIT_MEMORY);",
     "memory_start(1'b1, 2'd3, rm_offset, 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,data}, COMMIT_MEMORY);"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', choices=[entry[0] for entry in MUTATIONS], nargs='+',
                        help='Run selected mutants and retain separate filtered results')
    args = parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'sim/Vintel_80286'), '--references'],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    results = []
    for name, old, new in MUTATIONS:
        if args.only and name not in args.only:
            continue
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        sources = []
        for source in sorted((ROOT / 'src').glob('*.sv')):
            content = source.read_text()
            if source.name == 'intel_80286.sv':
                if content.count(old) != 1:
                    raise ValueError(f'Mutation must match once: {name}')
                content = content.replace(old, new)
            copy = dest / source.name
            copy.write_text(content)
            sources.append(str(copy))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--top-module', 'intel_80286', '--Mdir', str(dest / 'obj'),
                                *sources, str(ROOT / 'tb/bootstrap.cpp')], text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286'), '--references'], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if run.returncode == 0 or 'FAIL:' not in output:
            raise ValueError(f'Routing suite missed: {name}')
        if name == 'fetch_asserts_write' and 'instruction fetch asserted write/I/O controls' not in output:
            raise ValueError(f'Fetch-write mutant failed for an unrelated reason: {output}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: core reference tests detected {name}', flush=True)
    (WORK / ('results_filtered.json' if args.only else 'results.json')).write_text(
        json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
