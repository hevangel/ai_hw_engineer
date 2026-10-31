#!/usr/bin/env python3
"""Demonstrate that independent vectors detect representative semantic faults.

Mutants and build artifacts stay in ignored work/; RTL is never edited.
This is a small sensitivity check, not a coverage or completeness guarantee.
"""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'mutations'
VECTORS = WORK_ROOT / 'vectors/registers.txt'
MUTATIONS = [
    ('adc_ignores_carry', 'intel_80286_alu.sv',
     'with_carry = (operation_i == 2 || operation_i == 3) && flags_i[0];',
     'with_carry = (operation_i == 3) && flags_i[0];'),
    ('branch_sense_inverted', 'intel_80286.sv',
     'condition = base_condition ^ code[0];', 'condition = !(base_condition ^ code[0]);'),
    ('shift_count_four_bits', 'intel_80286.sv',
     'shifted_flags = shift_flags;', 'shift_count = shift_count & 5\'h0f;\n        shifted_flags = shift_flags;'),
    ('idiv_remainder_uses_quotient_sign', 'intel_80286_muldiv.sv',
     'negative_remainder<=dividend_negative;', 'negative_remainder<=dividend_negative^divisor_negative;'),
    ('bound_lower_endpoint_excluded', 'intel_80286.sv',
     '$signed(gpr[modrm[5:3]]) < $signed(memory_result[15:0])',
     '$signed(gpr[modrm[5:3]]) <= $signed(memory_result[15:0])'),
    ('xlat_index_sign_extended', 'intel_80286.sv',
     "(gpr[3]+{8'h0,gpr[0][7:0]})", "(gpr[3]+{{8{gpr[0][7]}},gpr[0][7:0]})"),
    ('rep_zero_count_accesses_element','intel_80286.sv',
     'if (repeat_valid && gpr[1]==0)', 'if (repeat_valid && gpr[1]==16\'hffff)'),
    ('rep_compares_previous_zf','intel_80286.sv',
     'alu_flags[6]!=repeat_ne', 'flags[6]!=repeat_ne'),
    ('string_direction_reversed','intel_80286.sv',
     'string_delta = flags[10] ?', 'string_delta = !flags[10] ?'),
    ('daa_high_threshold_9f','intel_80286_decimal.sv',
     "high_adjust=ax_i[7:0]>8'h99", "high_adjust=ax_i[7:0]>8'h9f"),
    ('aas_suppresses_low_borrow','intel_80286_decimal.sv',
     "ax_i-16'h0106", "ax_i-16'h0106+(ax_i[7:0]<6 ? 16'h0100 : 16'h0000)"),
    ('aad_preserves_ah','intel_80286_decimal.sv',
     "ax_o={8'h0,adjusted};", "ax_o={ax_i[15:8],adjusted};"),
    ('aam_sign_from_quotient','intel_80286.sv',
     'flags[7]<=md_ax[15];', 'flags[7]<=md_ax[7];'),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'sim/Vintel_80286'), '--vectors', str(VECTORS)],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    results = []
    for name, target, old, new in MUTATIONS:
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        sources = []
        for source in sorted((ROOT / 'src').glob('*.sv')):
            text = source.read_text()
            if source.name == target:
                if text.count(old) != 1:
                    raise ValueError(f'Mutation no longer matches exactly once: {name}')
                text = text.replace(old, new)
            copy = dest / source.name
            copy.write_text(text)
            sources.append(str(copy))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--top-module', 'intel_80286', '--Mdir', str(dest / 'obj'),
                                *sources, str(ROOT / 'tb/bootstrap.cpp')], text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile cleanly: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286'), '--vectors', str(VECTORS)],
                             text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if run.returncode == 0 or 'FAIL:' not in output or 'oracle case ' not in output:
            raise ValueError(f'Mutant was not detected by an oracle comparison: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: independent vectors detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
