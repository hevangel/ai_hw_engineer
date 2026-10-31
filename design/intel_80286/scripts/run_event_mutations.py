#!/usr/bin/env python3
"""Require transaction tests to reject event-controller defects, after clean builds."""
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'event_mutations'
MUTATIONS = [
    ('held_nmi_repeats', 'nmi_i && !nmi_previous', 'nmi_i'),
    ('nmi_masked_by_if', '(!nmi_blocked_o || iret_i)', 'if_i && (!nmi_blocked_o || iret_i)'),
    ('blocked_nmi_discarded', 'if (nmi_edge) nmi_pending_o<=1;',
     'if (nmi_edge && !nmi_blocked_o) nmi_pending_o<=1;'),
    ('nmi_unblocked_by_delivery', 'if (iret_i) nmi_blocked_o<=0;',
     'if (iret_i || event_ready_i) nmi_blocked_o<=0;'),
    ('ack_without_ready', 'ACKNOWLEDGE: if (ack_ready_i)', 'ACKNOWLEDGE: if (1\'b1)'),
    ('vector_changes_during_delivery', 'DELIVER: if (event_ready_i) state<=IDLE;',
     'DELIVER: begin event_vector_o<=ack_vector_i; if (event_ready_i) state<=IDLE; end'),
    ('step_loses_priority', 'if (step_i) begin event_vector_o<=1;',
     'if (step_i && !nmi_pending_o) begin event_vector_o<=1;'),
]


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'src/intel_80286_event_control.sv').read_text()
    baseline = subprocess.run([str(WORK_ROOT / 'event_control/Vintel_80286_event_control')],
                              capture_output=True, text=True, check=True)
    (WORK / 'baseline.log').write_text(baseline.stdout + baseline.stderr)
    results = []
    for name, old, new in MUTATIONS:
        if source.count(old) != 1:
            raise ValueError(f'Mutation must match exactly once: {name}')
        dest = WORK / name
        dest.mkdir(exist_ok=True)
        copy = dest / 'intel_80286_event_control.sv'
        copy.write_text(source.replace(old, new))
        build = subprocess.run(['verilator', '--cc', '--exe', '--build', '-j', '2', '-Wall',
                                '--Wno-UNUSEDSIGNAL', '--top-module', 'intel_80286_event_control',
                                '--Mdir', str(dest / 'obj'), str(copy), str(ROOT / 'tb/event_control.cpp')],
                               capture_output=True, text=True)
        # Mutations may deliberately remove the only use of an input/history
        # bit. Only that warning is suppressed for mutants; baseline is -Wall.
        (dest / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise ValueError(f'Mutant must compile: {name}')
        run = subprocess.run([str(dest / 'obj/Vintel_80286_event_control')],
                             capture_output=True, text=True)
        output = run.stdout + run.stderr
        (dest / 'run.log').write_text(output)
        if not run.returncode or 'FAIL:' not in output:
            raise ValueError(f'Transaction suite missed: {name}')
        results.append({'mutation': name, 'result': 'detected', 'diagnostic': output.strip()})
        print(f'PASS: transaction suite detected {name}', flush=True)
    (WORK / 'results.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
