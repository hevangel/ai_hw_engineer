#!/usr/bin/env python3
"""Qualification probes for NVC (VHDL) and Accellera SystemC in the extended EDA image.

Run inside the image built from eda_extended/Dockerfile, from the repository root:

    python3 scripts/check_extended_eda.py --work-dir scratchpad/eda-extended

The corpus under eda_extended/nvc and eda_extended/systemc is the shared reference
for the later Rust ports: each case has source, a case description and an expected
output that is either produced by an independent Python model (reference.py) or
derived by hand from the language reference manual and stated in the case.
Generated files, binaries and logs stay in the ignored work directory.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent / 'eda_extended'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', default='scratchpad/eda-extended')
parser.add_argument('--tools', default='versions,nvc,systemc,interop')
args = parser.parse_args()
work = Path(args.work_dir).resolve()
work.mkdir(parents=True, exist_ok=True)
(work / 'logs').mkdir(exist_ok=True)
selected = set(args.tools.split(','))
results = []


def execute(command, cwd, timeout=600):
    try:
        run = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, timeout=timeout)
        return run.returncode, run.stdout, run.stderr
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, '', str(error)


def keep_lines(text, drop_info=False):
    lines = [line for line in text.replace('\r', '').split('\n') if line.strip()]
    if drop_info:
        lines = [line for line in lines if not line.startswith('Info:')]
    return lines


def check(tool, name, command, cwd, exit_code=0, marker=None, forbidden=None,
          expected_file=None, drop_info=False):
    """exit_code: an int, or 'nonzero'. marker/forbidden are searched in stdout+stderr."""
    code, out, err = execute(command, cwd)
    combined = out + err
    (work / 'logs' / f'{tool}-{name}.log').write_text(
        f'$ {" ".join(map(str, command))}\nexit={code}\n--- stdout\n{out}\n--- stderr\n{err}\n', encoding='utf-8')
    passed = code is not None
    if passed:
        passed = (code != 0) if exit_code == 'nonzero' else (code == exit_code)
    if passed and marker:
        passed = marker in combined
    if passed and forbidden:
        passed = forbidden not in combined
    if passed and expected_file:
        want = keep_lines(Path(expected_file).read_text(encoding='utf-8'))
        passed = keep_lines(out, drop_info) == want
    results.append(dict(tool=tool, check=name, command=[str(c) for c in command], returncode=code,
                        expectedExit=exit_code, passed=passed, log=f'logs/{tool}-{name}.log'))
    print(('PASS' if passed else 'FAIL') + ' ' + tool + ' ' + name, flush=True)
    return passed


def case_json(directory):
    return json.loads((directory / 'case.json').read_text(encoding='utf-8'))


if 'versions' in selected:
    check('versions', 'nvc', ['nvc', '--version'], work, marker='nvc 1.23.1')
    check('versions', 'nvc-llvm', ['nvc', '--version'], work, marker='Using LLVM 21')
    check('versions', 'systemc-library', ['bash', '-c', 'test -f /opt/systemc/lib/libsystemc.a && test -f /opt/systemc/include/systemc && echo SYSTEMC LIBRARY PRESENT'], work, marker='SYSTEMC LIBRARY PRESENT')
    check('versions', 'compiler', ['g++', '--version'], work, marker='g++')

if 'nvc' in selected:
    nvc_dir = work / 'nvc'
    for directory in sorted(p for p in (ROOT / 'nvc' / 'corpus').iterdir() if p.is_dir()):
        description = case_json(directory)
        std, top = description['std'], description['top']
        sources = [str(p) for p in sorted(directory.glob('*.vhd'))]
        case_work = nvc_dir / directory.name
        case_work.mkdir(parents=True, exist_ok=True)
        name = directory.name
        if not check('nvc', name + '-analyse', ['nvc', f'--std={std}', '-a', *sources], case_work):
            continue
        if not check('nvc', name + '-elaborate', ['nvc', f'--std={std}', '-e', top], case_work):
            continue
        run_command = ['nvc', f'--std={std}', '-r', top]
        if description.get('wave'):
            run_command.append(f'--wave={name}.fst')
        check('nvc', name + '-simulate', run_command, case_work, expected_file=directory / 'expected.txt')
        if description.get('wave'):
            check('nvc', name + '-waveform-written', ['bash', '-c', f'test -s {name}.fst && echo WAVEFORM WRITTEN'], case_work, marker='WAVEFORM WRITTEN')
            check('nvc', name + '-vcd-format', ['nvc', f'--std={std}', '-r', top, '--format=vcd', f'--wave={name}.vcd'], case_work,
                  expected_file=directory / 'expected.txt')
            check('nvc', name + '-vcd-written', ['bash', '-c', f'grep -q "\\$var" {name}.vcd && echo VCD WRITTEN'], case_work, marker='VCD WRITTEN')
    negative = ROOT / 'nvc' / 'negative'
    neg = nvc_dir / 'negative'
    neg.mkdir(parents=True, exist_ok=True)
    check('nvc', 'syntax-error-rejected', ['nvc', '--std=08', '-a', str(negative / 'syntax_error.vhd')], neg,
          exit_code='nonzero', marker='unexpected end while parsing port clause')
    check('nvc', 'missing-entity-fails-elaboration', ['bash', '-c', f'nvc --std=08 -a {negative}/missing_entity.vhd && nvc --std=08 -e top_missing'], neg,
          exit_code='nonzero', marker='NOT_DEFINED not found in library WORK')
    check('nvc', 'failure-severity-nonzero-exit', ['bash', '-c', f'nvc --std=08 -a {negative}/assert_failure.vhd && nvc --std=08 -e assert_failure && nvc --std=08 -r assert_failure'], neg,
          exit_code='nonzero', marker='intentional failure', forbidden='after failure')
    # Observed behavior of this pinned NVC: an error-severity assertion does not stop the
    # simulation but still makes the process exit nonzero; --exit-severity changes both.
    prefix = f'nvc --std=08 -a {negative}/assert_error.vhd && nvc --std=08 -e assert_error && nvc --std=08 -r assert_error'
    check('nvc', 'error-severity-continues-but-exits-nonzero', ['bash', '-c', prefix], neg,
          exit_code='nonzero', marker='after error')
    check('nvc', 'exit-severity-error-stops-immediately', ['bash', '-c', prefix + ' --exit-severity=error'], neg,
          exit_code='nonzero', forbidden='after error')
    check('nvc', 'exit-severity-failure-ignores-error', ['bash', '-c', prefix + ' --exit-severity=failure'], neg,
          exit_code=0, marker='after error')
    check('nvc', 'vhdl2008-construct-rejected-under-std93', ['nvc', '--std=93', '-a', str(negative / 'std2008_only.vhd')], neg,
          exit_code='nonzero', marker='unexpected all')
    check('nvc', 'vhdl2008-construct-accepted-under-std08', ['nvc', '--std=08', '-a', str(negative / 'std2008_only.vhd')], neg)
    vhpi = nvc_dir / 'vhpi'
    vhpi.mkdir(parents=True, exist_ok=True)
    counter = ROOT / 'nvc' / 'corpus' / 'counter'
    check('nvc', 'vhpi-plugin-builds', ['gcc', '-shared', '-fPIC', '-I/opt/nvc/include', '-o', 'hello_vhpi.so', str(ROOT / 'nvc' / 'vhpi' / 'hello_vhpi.c')], vhpi)
    check('nvc', 'vhpi-plugin-loads', ['bash', '-c', f'nvc --std=08 -a {counter}/01_counter.vhd {counter}/02_tb_counter.vhd && nvc --std=08 -e tb_counter && nvc --std=08 -r tb_counter --load=./hello_vhpi.so'], vhpi,
          marker='VHPI STARTUP PASS')

if 'systemc' in selected:
    sc_dir = work / 'systemc'
    sc_dir.mkdir(parents=True, exist_ok=True)

    def build(source, binary):
        return check('systemc', binary + '-compile',
                     ['g++', '-std=c++17', '-O1', '-Wall', '-I/opt/systemc/include', str(source),
                      '-L/opt/systemc/lib', '-lsystemc', '-pthread', '-o', binary], sc_dir)

    for directory in sorted(p for p in (ROOT / 'systemc' / 'corpus').iterdir() if p.is_dir()):
        name = directory.name
        if build(directory / (name + '.cpp'), name):
            check('systemc', name + '-simulate', ['./' + name], sc_dir,
                  expected_file=directory / 'expected.txt', drop_info=True)
    check('systemc', 'counter-vcd-written', ['bash', '-c', 'test -s counter.vcd && grep -q "\\$var" counter.vcd && echo VCD WRITTEN'], sc_dir, marker='VCD WRITTEN')
    check('systemc', 'banner-version', ['./delta_events'], sc_dir, marker='SystemC 3.0.2-Accellera')
    negative = ROOT / 'systemc' / 'negative'
    for name, code, marker, forbidden in [
        ('fatal', 'nonzero', 'intentional fatal report', 'after fatal'),
        ('assert_fail', 'nonzero', 'assertion failed: 1 + 1 == 3', 'after assert'),
        ('error_throw', 'nonzero', 'intentional error report', 'after error'),
        ('exit_code', 3, 'returning 3', None),
        ('unbound_port', 'nonzero', 'complete binding failed: port not bound', 'simulation started'),
    ]:
        if build(negative / (name + '.cpp'), name):
            check('systemc', name + '-reports-failure', ['./' + name], sc_dir, exit_code=code,
                  marker=marker, forbidden=forbidden)

if 'interop' in selected:
    # Waveform interoperability with the Surfer server: files written by NVC and by
    # SystemC must be accepted by Surver. This is file-level interoperability only;
    # no SV/VHDL or SV/SystemC co-simulation adapter is qualified.
    probes = [('nvc-fst', work / 'nvc' / 'counter' / 'counter.fst', 18101, 'Fst'),
              ('nvc-vcd', work / 'nvc' / 'counter' / 'counter.vcd', 18103, 'Vcd'),
              ('systemc-vcd', work / 'systemc' / 'counter.vcd', 18102, 'Vcd')]
    for label, path, port, fmt in probes:
        token = f'interop-token-{port}'
        script = (f'cd {path.parent} && (surver --port {port} --token {token} {path.name} > surver-{label}.log 2>&1 & echo $! > surver-{label}.pid)'
                  f' && sleep 3 && body=$(curl -s -m 5 http://127.0.0.1:{port}/{token}/get_status); kill $(cat surver-{label}.pid) 2>/dev/null; echo "$body"')
        check('interop', 'surver-loads-' + label, ['bash', '-c', script], work, marker=f'"format":"{fmt}"')

summary = dict(recordedAt=datetime.now(timezone.utc).isoformat(), checks=results,
               passed=all(item['passed'] for item in results))
(work / 'results.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print('Results:', work / 'results.json', flush=True)
sys.exit(0 if summary['passed'] else 1)
