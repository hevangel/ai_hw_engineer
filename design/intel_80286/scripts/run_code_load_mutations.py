#!/usr/bin/env python3
"""Check CS transaction-test sensitivity; altered RTL stays in ignored work/."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'code_load_mutations'
MUTATIONS = [
    ('reads_only_six_bytes', 'if (byte_index==7) state<=VALIDATE;', 'if (byte_index==5) state<=VALIDATE;'),
    ('accessed_byte_wrong_address', "? 24'd5 :", "? 24'd4 :"),
    ('publishes_before_write_ready', 'WRITE_ACCESSED: if (bus_ready_i) complete_load();',
     'WRITE_ACCESSED: complete_load();'),
    ('writes_system_descriptor',
     'VALIDATE: if (check_fault || check_special) complete_load();\n                          else if (check_valid) state<=WRITE_ACCESSED;',
     'VALIDATE: if (check_fault) complete_load();\n                          else state<=WRITE_ACCESSED;'),
    ('skips_already_accessed_write', 'else if (check_valid) state<=WRITE_ACCESSED;',
     'else if (check_valid) begin if (descriptor[40]) complete_load(); else state<=WRITE_ACCESSED; end'),
    ('uses_live_target_offset', '.offset_i(saved_offset)', '.offset_i(offset_i)'),
    ('publishes_partial_request_context', 'IDLE: if (start_i) begin',
     'IDLE: if (start_i) begin request_selector_o<=selector_i;'),
    ('clears_accessed_bit', 'assign bus_wdata_o=check_accessed;', "assign bus_wdata_o=check_accessed^8'h01;"),
    ('loses_special_access_byte', "special_descriptor_o<=check_special ? descriptor : 48'h0;",
     "special_descriptor_o<=check_special ? {8'h00,descriptor[39:0]} : 48'h0;"),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    baseline = subprocess.run([str(WORK_ROOT / 'code_load/Vintel_80286_code_load')],
                              text=True, capture_output=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    original = (ROOT / 'src/intel_80286_code_load.sv').read_text()
    results = []
    for name, old, new in MUTATIONS:
        if original.count(old) != 1:
            raise ValueError(f'Mutation must match once: {name}')
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        source = dest / 'intel_80286_code_load.sv'
        source.write_text(original.replace(old, new))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--Wno-UNUSEDSIGNAL', '--top-module', 'intel_80286_code_load',
                                '--Mdir', str(dest / 'obj'), str(ROOT / 'src/intel_80286_code_check.sv'),
                                str(source), str(ROOT / 'tb/code_load.cpp')], text=True, capture_output=True)
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286_code_load')], text=True, capture_output=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'CS load suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: CS transaction checks detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
