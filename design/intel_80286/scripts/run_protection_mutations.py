#!/usr/bin/env python3
"""Compile isolated CPU copies and require protection contracts to catch defects."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'protection_mutations'
SOURCE = 'intel_80286.sv'
MUTATIONS = (
    (
        'wordspan_wrong_vector',
        "if (rm_memory && opcode != 8'h8d && ((wide && ea_offset == 16'hffff) ||\n"
        "                        (system_table && ea_offset>16'hfffa) ||\n"
        "                        ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) && ea_offset > 16'hfffc))) begin\n"
        "                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
        "if (rm_memory && opcode != 8'h8d && ((wide && ea_offset == 16'hffff) ||\n"
        "                        (system_table && ea_offset>16'hfffa) ||\n"
        "                        ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) && ea_offset > 16'hfffc))) begin\n"
        "                        enter_event(6,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
    ),
    (
        'wordspan_wrong_saved_ip',
        "if (rm_memory && opcode != 8'h8d && ((wide && ea_offset == 16'hffff) ||\n"
        "                        (system_table && ea_offset>16'hfffa) ||\n"
        "                        ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) && ea_offset > 16'hfffc))) begin\n"
        "                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
        "if (rm_memory && opcode != 8'h8d && ((wide && ea_offset == 16'hffff) ||\n"
        "                        (system_table && ea_offset>16'hfffa) ||\n"
        "                        ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) && ea_offset > 16'hfffc))) begin\n"
        "                        enter_event(13,ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
    ),
    (
        'overlength_wrong_vector',
        "else if (({1'b0,instruction_bytes} + remaining_bytes) > 10) begin\n"
        "                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
        "else if (({1'b0,instruction_bytes} + remaining_bytes) > 10) begin\n"
        "                        enter_event(6,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;",
    ),
    (
        'idtr_fallback_wrong_saved_ip',
        "event_packet.saved_ip<=event_packet.instruction_retired ? instruction_ip : event_packet.saved_ip;",
        "event_packet.saved_ip<=event_packet.instruction_retired ? ip : event_packet.saved_ip;",
    ),
)


def run_contract(executable, mode, output_path):
    run = subprocess.run(
        [str(executable), mode], capture_output=True, text=True, timeout=180)
    output = run.stdout + run.stderr
    output_path.write_text(output)
    if run.returncode or 'PASS:' not in output:
        raise RuntimeError(f'{mode} baseline failed; see {output_path}\n{output.strip()}')
    return output


def build_mutant(name, old, new):
    destination = WORK / name
    destination.mkdir(parents=True, exist_ok=True)
    sources = []
    for source in sorted((ROOT / 'src').glob('*.sv')):
        content = source.read_text()
        if source.name == SOURCE:
            matches = content.count(old)
            if matches != 1:
                raise ValueError(f'{name}: expected one source match, found {matches}')
            content = content.replace(old, new, 1)
        copy = destination / source.name
        copy.write_text(content)
        sources.append(str(copy))

    build = subprocess.run([
        'verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
        '--top-module', 'intel_80286', '--Mdir', str(destination / 'obj'),
        *sources, str(ROOT / 'tb/bootstrap.cpp')],
        capture_output=True, text=True, timeout=900)
    (destination / 'build.log').write_text(build.stdout + build.stderr)
    if build.returncode:
        raise RuntimeError(f'{name}: strict Verilator build failed; see {destination / "build.log"}')
    return destination


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = WORK_ROOT / 'sim/Vintel_80286'
    run_contract(baseline, '--protection', WORK / 'baseline.log')

    results = []
    for name, old, new in MUTATIONS:
        destination = build_mutant(name, old, new)
        run = subprocess.run(
            [str(destination / 'obj/Vintel_80286'), '--protection'],
            capture_output=True, text=True, timeout=180)
        output = run.stdout + run.stderr
        (destination / 'run.log').write_text(output)
        if run.returncode == 0 or 'FAIL:' not in output:
            raise RuntimeError(f'{name}: protection suite missed the mutant')
        results.append({
            'mutation': name,
            'result': 'detected',
            'diagnostic': output.strip(),
        })
        print(f'PASS: protection suite detected {name}', flush=True)

    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
