#!/usr/bin/env python3
"""Require focused system-register tests to detect compiled semantic defects."""
import argparse
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'system_mutations'
MUTATIONS = [
    ('clts_clears_em', "if (system_opcode==8'h06) msw[3]<=0;",
     "if (system_opcode==8'h06) msw[2]<=0;"),
    ('lmsw_leaks_reserved_bits', "msw<={12'hfff,rm_value[3:1],msw[0] | rm_value[0]};",
     'msw<=rm_value;'),
    ('pe_set_ignored', "msw<={12'hfff,rm_value[3:1],msw[0] | rm_value[0]};",
     "msw<={12'hfff,rm_value[3:1],msw[0]};"),
    ('sgdt_wrong_unused_byte',
     "system_image=modrm[3] ? {8'hff,idt_base,idt_limit} : {8'hff,gdt_base,gdt_limit};",
     "system_image=modrm[3] ? {8'h00,idt_base,idt_limit} : {8'h00,gdt_base,gdt_limit};"),
    ('six_byte_store_rotates_words', 'memory_data<=system_image;',
     'memory_data<={system_image[31:0],system_image[47:32]};'),
    ('table_store_retires_after_four', "memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, 6, 0, SYSTEM_DONE);",
     "memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, 4, 0, SYSTEM_DONE);"),
    ('lidt_loads_wrong_base_bytes', 'idt_base<=memory_result[39:16];',
     'idt_base<=memory_result[47:24];'),
    ('interrupt_ignores_idtr_base', "idt_base+{14'h0,event_vector_o,2'b00}",
     "{14'h0,event_vector_o,2'b00}"),
    ('idtr_limit_one_byte_too_large', "{7'h0,event_vector_o,2'b00}+17'd3)",
     "{7'h0,event_vector_o,2'b00}+17'd2)"),
]


def main(work_dir):
    work_dir.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'sim/Vintel_80286'), '--system'],
                              text=True, capture_output=True, check=True)
    (work_dir / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    results = []
    for name, old, new in MUTATIONS:
        dest = work_dir / name
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
                                *sources, str(ROOT / 'tb/bootstrap.cpp')],
                               text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286'), '--system'],
                             text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'System suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: system-register contracts detected {name}', flush=True)
    (work_dir / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-dir', type=Path, default=WORK,
                        help='result directory (defaults to work/system_mutations)')
    main(parser.parse_args().work_dir)
