#!/usr/bin/env python3
"""Compile faulty copies to test #UD linkage and physical TEST-alias sensitivity."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'undefined_mutations'
ENTRY = "enter_event(8'd6,instruction_ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START;"
MUTATIONS = (
    ('wrong_vector', ENTRY, "enter_event(8'd7,instruction_ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START;", 'ud'),
    ('wrong_saved_pc', ENTRY, "enter_event(8'd6,ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START;", 'ud'),
    ('fault_retires', ENTRY, "enter_event(8'd6,instruction_ip,1'b1,1'b1,1'b0,16'd0); state<=EVENT_START;", 'ud'),
    ('missing_test_alias',
     "((opcode == 8'hf6 || opcode == 8'hf7) && modrm[5:3] <= 1)",
     "((opcode == 8'hf6 || opcode == 8'hf7) && modrm[5:3] == 0)", 'alias'),
)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    alias_sample = WORK / 'alias_sample.txt'
    with (WORK_ROOT / 'hardware/vectors.txt').open() as source:
        record = []
        for line in source:
            record.append(line)
            if line.strip() != 'END':
                continue
            if int(record[0].split()[3], 16) in (0xf6, 0xf7):
                alias_sample.write_text(''.join(record))
                break
            record = []
        else:
            raise ValueError('Pinned physical TEST-alias sample missing')
    arguments = {'ud': ['--ud'], 'alias': ['--hardware', str(alias_sample)]}
    baseline = WORK_ROOT / 'sim/Vintel_80286'
    for mode, args in arguments.items():
        run = subprocess.run([str(baseline), *args], capture_output=True, text=True, timeout=60)
        (WORK / f'baseline_{mode}.log').write_text(run.stdout + run.stderr)
        if run.returncode or 'PASS:' not in run.stdout:
            raise RuntimeError(f'Baseline {mode} failed')
    results = []
    for name, old, new, mode in MUTATIONS:
        destination = WORK / name
        destination.mkdir(exist_ok=True)
        sources = []
        for source in sorted((ROOT / 'src').glob('*.sv')):
            content = source.read_text()
            if source.name == 'intel_80286.sv':
                if content.count(old) != 1:
                    raise ValueError(f'Mutation must match exactly once: {name}')
                content = content.replace(old, new)
            copy = destination / source.name
            copy.write_text(content)
            sources.append(str(copy))
        build = subprocess.run([
            'verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
            '--top-module', 'intel_80286', '--Mdir', str(destination / 'obj'),
            *sources, str(ROOT / 'tb/bootstrap.cpp')], capture_output=True, text=True)
        (destination / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise RuntimeError(f'Mutant must compile: {name}')
        run = subprocess.run([str(destination / 'obj/Vintel_80286'), *arguments[mode]],
                             capture_output=True, text=True, timeout=60)
        output = run.stdout + run.stderr
        (destination / 'run.log').write_text(output)
        if run.returncode == 0 or 'FAIL:' not in output:
            raise RuntimeError(f'Undetected mutant: {name}')
        results.append({'mutation': name, 'mode': mode, 'diagnostic': output.strip()})
        print(f'PASS: detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
