#!/usr/bin/env python3
"""Require real-cache tests to detect compiled update/publication defects."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'cache_mutations'
MUTATIONS = [
    ('mov_es_does_not_reload_base', "es_base<={4'h0,rm_value,4'h0};", 'es_base<=es_base;'),
    ('mov_ss_does_not_reload_base', "ss_base<={4'h0,rm_value,4'h0};", 'ss_base<=ss_base;'),
    ('pop_ds_uses_wrong_word', "ds_base<={4'h0,memory_result[15:0],4'h0};",
     "ds_base<={4'h0,memory_result[31:16],4'h0};"),
    ('lds_uses_offset_as_selector', "ds_base<={4'h0,memory_result[31:16],4'h0};",
     "ds_base<={4'h0,memory_result[15:0],4'h0};"),
    ('les_keeps_old_base', "es_base<={4'h0,memory_result[31:16],4'h0};", 'es_base<=es_base;'),
    ('publishes_base_before_mov_commit', 'PREPARE: begin',
     "PREPARE: begin if (opcode==8'h8e && modrm[4:3]==0) es_base<={4'h0,rm_value,4'h0};"),
    ('wrong_real_cache_attributes', "cache_access<=32'h93939393;", "cache_access<=32'h93939b93;"),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'sim/Vintel_80286'), '--caches'],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    results = []
    for name, old, new in MUTATIONS:
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
        run = subprocess.run([str(dest / 'obj/Vintel_80286'), '--caches'], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'Cache suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: real-cache tests detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
