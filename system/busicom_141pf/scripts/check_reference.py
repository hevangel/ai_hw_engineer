#!/usr/bin/env python3
"""Replay the JSON on an external, unmodified V. Ilmer chips checkout.

Requires Rust and --chips pointing to the separately cloned reference crate.
Each example starts with a fresh board. This adapter does not implement a CPU.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from replay_manual import DEFAULT, decode_row, validate

PIN = '1bc3d5781474ef9d7e7305af91071a723797f222'
ROOT = Path(__file__).resolve().parents[1]


def compare(log, doc, profile):
    examples = {e['id']: e for e in doc['examples']}
    results, rows = [], []
    for line in log.splitlines():
        if line.startswith('#EXAMPLE '):
            eid = line.split()[1]
            results.append({'id': eid, 'status': 'PASS', 'checkpoints': 0, 'errors': []})
        elif line == '#RESET': rows = []
        elif line.startswith('ROW|'):
            _, value, a, b, red = line.split('|')
            rows.append(decode_row(list(value.rjust(15)) + [' ', a, b, red == 'true']))
        elif line.startswith('#STEP '):
            index = int(line.split()[1])
            step = examples[eid]['steps'][index]
        elif line.startswith('LAMPS|'):
            results[-1]['checkpoints'] += 1
            lamps = int(line.split('|')[1])
            expected = step.get('expect_profiles', {}).get(profile, step.get('expect', {}))
            errors = results[-1]['errors']
            if 'tape' in expected and rows[-len(expected['tape']):] != expected['tape']:
                errors.append({'step': index+1, 'expected_tape': expected['tape'], 'actual_tape': rows})
            for i, name in enumerate(('memory', 'overflow', 'negative')):
                if name in expected.get('lamps', {}) and bool(lamps & (1 << i)) != expected['lamps'][name]:
                    errors.append({'step': index+1, 'lamp': name, 'actual': bool(lamps & (1 << i))})
            results[-1]['status'] = 'FAIL' if errors else 'PASS'
            rows = []
    if len(results) != len(examples): raise RuntimeError('Incomplete external emulator run')
    if any(r['checkpoints'] != len(examples[r['id']]['steps']) for r in results):
        raise RuntimeError('Incomplete external emulator checkpoints')
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chips', type=Path, required=True)
    parser.add_argument('--profile', choices=['manual', 'recovered-rom'], default='manual')
    args = parser.parse_args()
    chips = args.chips.resolve()
    # Windows bind mounts may contain CRLF worktree text. Git's normalization
    # still rejects semantic edits while comparing it with the pinned commit.
    git = ['git', '-c', 'safe.directory='+str(chips), '-c', 'core.autocrlf=true',
           '-C', str(chips)]
    revision = subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(git + ['status', '--porcelain'], text=True).strip()
    if revision != PIN or dirty: parser.error('Use the pinned, unmodified chips checkout: '+PIN)
    doc = validate(json.loads(DEFAULT.read_text(encoding='utf-8')))
    work = ROOT / 'work/reference-oracle'
    (work/'src').mkdir(parents=True, exist_ok=True)
    # JSON quoted strings are valid TOML basic strings for these filesystem paths.
    (work/'Cargo.toml').write_text('[package]\nname="manual-oracle"\nversion="0.1.0"\nedition="2021"\n'
        '[dependencies]\nchips={path='+json.dumps(str(chips))+'}\narbitrary-int="=1.3.0"\n', encoding='utf-8')
    shutil.copyfile(ROOT/'scripts/reference_oracle.rs', work/'src/main.rs')
    schedule = []
    for example in doc['examples']:
        schedule += ['#EXAMPLE '+example['id'], '2 0 0 2000']
        switches = example['switches'].copy()
        for index, step in enumerate([{'keys':example['setup_keys']}] + example['steps']):
            switches.update(step.get('switches', {}))
            for key in step.get('keys', []):
                schedule.append(f"{switches['precision']} {switches['rounding']} {doc['key_codes'][key]} 400")
            schedule.append('#RESET' if index == 0 else '#STEP '+str(index-1))
    (work/'schedule.txt').write_text('\n'.join(schedule)+'\n', encoding='utf-8')
    with (work/'build.log').open('w', encoding='utf-8') as build_log:
        output = subprocess.check_output(['cargo', 'run', '--release', '--manifest-path', str(work/'Cargo.toml'),
            '--', str(ROOT/'spec/reference/rom_141pf_combined.bin'), str(work/'schedule.txt')],
            text=True, encoding='utf-8', stderr=build_log)
    (work/'trace.log').write_text(output, encoding='utf-8')
    results = compare(output, doc, args.profile)
    report = {'oracle_revision': revision, 'profile': args.profile, 'source': doc['source'], 'results': results}
    (work/'results.json').write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    for result in results: print(result['status'], result['id'])
    return int(any(r['status'] != 'PASS' for r in results))


if __name__ == '__main__': raise SystemExit(main())
