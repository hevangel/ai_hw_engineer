#!/usr/bin/env python3
"""Require the protected event regression to catch event-path defects."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
SOURCE = 'intel_80286.sv'

MUTATIONS = (
    (
        'wrong_saved_pc',
        'event_packet.saved_ip,EVENT_FRAME_IP);',
        "event_packet.saved_ip+16'd1,EVENT_FRAME_IP);",
    ),
    (
        'missing_error_code',
        'if (event_packet.error_present)\n'
        '                        event_frame_word(event_stack_active ? event_tss_stack_sp-16\'d12 :\n'
        '                                         event_packet.saved_sp-16\'d8,\n'
        '                                         event_packet.error_code,EVENT_FRAME_ERROR);',
        'if (1\'b0)\n'
        '                        event_frame_word(event_stack_active ? event_tss_stack_sp-16\'d12 :\n'
        '                                         event_packet.saved_sp-16\'d8,\n'
        '                                         event_packet.error_code,EVENT_FRAME_ERROR);',
    ),
    (
        'early_handler_cs_cache_commit',
        'event_target_selector<=code_load_selector; event_target_base<=code_load_base;',
        'event_target_selector<=code_load_selector; event_target_base<=code_load_base;\n'
        '                        cs<=code_load_selector; cs_base<=code_load_base;\n'
        '                        cache_limits[31:16]<=code_load_limit; cache_access[15:8]<=code_load_access;\n'
        '                        cache_valid[1]<=1;',
    ),
    (
        'ignored_segment_permission_failure',
        'MEMORY_CHECK: begin\n                    if (data_reference_allow) begin',
        'MEMORY_CHECK: begin\n                    if (data_reference_allow || data_reference_fault) begin',
    ),
    (
        'software_int_dpl_polarity_reversed',
        'event_packet.software_interrupt &&\n'
        '                                 cs[1:0]>event_gate[46:45]',
        'event_packet.software_interrupt &&\n'
        '                                 cs[1:0]<=event_gate[46:45]',
    ),
    (
        'interrupt_gate_preserves_if',
        "(event_gate[43:40]==4'h6 ? 16'hfcff : 16'hfeff)",
        "16'hfeff",
    ),
)

MUTATION_SUITES = {
    'wrong_saved_pc': ('protected-segments', 'protected-event-outer'),
    'missing_error_code': ('protected-segments', 'protected-event-outer'),
    'early_handler_cs_cache_commit': ('protected-event-outer',),
    'ignored_segment_permission_failure': ('protected-segments',),
    'software_int_dpl_polarity_reversed': ('protected-event-outer',),
    'interrupt_gate_preserves_if': ('protected-event-outer',),
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def build_mutant(work, name, old, new):
    destination = work / name
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
    return destination / 'obj/Vintel_80286'


def run(executable, output_path, *, suite, expected_failure):
    result = subprocess.run(
        [str(executable), f'--{suite}'], capture_output=True,
        text=True, timeout=180)
    output = result.stdout + result.stderr
    output_path.write_text(output)
    if expected_failure:
        if result.returncode == 0 or 'FAIL:' not in output:
            raise RuntimeError(f'protected-event fixture missed a mutation; see {output_path}')
    elif result.returncode or 'PASS:' not in output:
        raise RuntimeError(f'protected-event baseline failed; see {output_path}\n{output.strip()}')
    return output.strip()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path,
                        default=WORK_ROOT / 'sim/Vintel_80286',
                        help='source-matched Verilator runner binary')
    parser.add_argument('--work-dir', type=Path,
                        help='fresh evidence directory for mutant builds/logs')
    parser.add_argument('--suite', choices=('all', 'protected-segments',
                                            'protected-event-outer'),
                        default='all',
                        help='directed regression(s) used to reject each mutant')
    args = parser.parse_args(argv)
    baseline = args.baseline.resolve()
    work = (args.work_dir.resolve() if args.work_dir else
            WORK_ROOT / ('protected_event_mutations_' +
                         datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')))
    if not baseline.is_file():
        parser.error(f'runner binary does not exist: {baseline}')
    try:
        work.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        parser.error(f'evidence directory already exists: {work}')
    print(f'Mutation evidence directory: {work}', flush=True)
    suites = (('protected-segments', 'protected-event-outer')
              if args.suite == 'all' else (args.suite,))
    for suite in suites:
        run(baseline, work / f'baseline_{suite}.log', suite=suite,
            expected_failure=False)
    runner_manifest = baseline.parent / 'build_manifest.json'
    manifest_data = None
    if runner_manifest.is_file():
        manifest_data = json.loads(runner_manifest.read_text())
        if manifest_data.get('binary_sha256') != sha256(baseline):
            raise RuntimeError(f'runner binary does not match {runner_manifest}')
    results = []
    selected_mutations = [
        mutation for mutation in MUTATIONS
        if any(suite in suites for suite in MUTATION_SUITES[mutation[0]])
    ]
    for name, old, new in selected_mutations:
        executable = build_mutant(work, name, old, new)
        mutation_suites = [suite for suite in MUTATION_SUITES[name]
                           if suite in suites]
        diagnostics = []
        for suite in mutation_suites:
            diagnostic = run(executable, work / name / f'{suite}.log',
                             suite=suite, expected_failure=True)
            diagnostics.append({'suite': suite, 'diagnostic': diagnostic})
        results.append({'mutation': name, 'result': 'detected',
                        'binary_sha256': sha256(executable),
                        'runs': diagnostics})
        print(f'PASS: {name} detected by {", ".join(mutation_suites)}', flush=True)
    manifest = {
        'suite': args.suite,
        'suites': suites,
        'baseline': str(baseline),
        'baseline_sha256': sha256(baseline),
        'runner_manifest': str(runner_manifest) if manifest_data else None,
        'runner_fingerprint': manifest_data.get('fingerprint') if manifest_data else None,
        'results': results,
    }
    (work / 'results.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
