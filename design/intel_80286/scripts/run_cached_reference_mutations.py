#!/usr/bin/env python3
"""Require the independent routing suite to reject compiled frontend defects."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'cached_reference_mutations'
MUTATIONS = [
    ('wrong_base_role', ('selected_base=bases_i[23:0];','selected_base=bases_i[47:24];'),
     ('selected_base=bases_i[47:24];','selected_base=bases_i[23:0];')),
    ('wrong_limit_role', ('selected_limit=limits_i[15:0];','selected_limit=limits_i[31:16];'),
     ('selected_limit=limits_i[31:16];','selected_limit=limits_i[15:0];')),
    ('wrong_permission_role', ('selected_access=access_i[4:1];','selected_access=access_i[12:9];'),
     ('selected_access=access_i[12:9];','selected_access=access_i[4:1];')),
    ('trust_other_segments', 'trusted_cs_i && role_i==1 && kind_i==2', 'trusted_cs_i && kind_i==2'),
    ('trust_cs_data', 'trusted_cs_i && role_i==1 && kind_i==2', 'trusted_cs_i && role_i==1'),
    ('trusted_unusable_cs', 'usable_i[1] && final_byte', 'final_byte'),
    ('trusted_span_wrap', "final_byte={1'b0,offset_i}+{1'b0,last_delta_i};",
     "final_byte={1'b0,16'(offset_i+last_delta_i)};"),
    ('wrong_stack_fault_role', '.stack_i(role_i==2)', '.stack_i(role_i==3)'),
    ('fault_address_escapes', "allow_o ? selected_base+{8'h0,offset_i} : 24'd0", "selected_base+{8'h0,offset_i}"),
    ('physical_offset_lost', "selected_base+{8'h0,offset_i}", 'selected_base'),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'cached_reference/Vintel_80286_cached_reference')],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    source = (ROOT / 'src/intel_80286_cached_reference.sv').read_text()
    results = []
    for name, old, new in MUTATIONS:
        old_values = old if isinstance(old, tuple) else (old,)
        new_values = new if isinstance(new, tuple) else (new,)
        mutated = source
        for index, old_value in enumerate(old_values):
            if mutated.count(old_value) != 1:
                raise ValueError(f'Mutation must match once: {name}')
            mutated = mutated.replace(old_value, f'__mutation_{index}__')
        for index, new_value in enumerate(new_values):
            mutated = mutated.replace(f'__mutation_{index}__', new_value)
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        mutant = dest / 'intel_80286_cached_reference.sv'
        mutant.write_text(mutated)
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--top-module', 'intel_80286_cached_reference', '--Mdir', str(dest / 'obj'),
                                str(ROOT / 'src/intel_80286_access_check.sv'), str(mutant),
                                str(ROOT / 'tb/cached_reference.cpp')], text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286_cached_reference')], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if run.returncode == 0 or 'FAIL:' not in output:
            raise ValueError(f'Routing suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: cache-reference tests detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
