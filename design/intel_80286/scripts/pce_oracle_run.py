#!/usr/bin/env python3
"""Run scenarios on the PCE-286 oracle and the RTL, compare, and report.

Usage: pce_oracle_run.py WORK_DIR [-k PATTERN] [--wait] [--jobs N]

For every scenario the per-boundary architectural trace, the port writes
and the final value of every written memory byte must agree. A scenario
matched by tb/pce_oracle/waivers.json is reported as WAIVED instead of
MISMATCH; each waiver must cite the source that shows the oracle is wrong
or the behavior undefined. Exit status is 1 when any unwaived mismatch
remains.
"""
import argparse
import concurrent.futures
import fnmatch
import json
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ['cs', 'ip', 'flags', 'ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di', 'es', 'ss', 'ds', 'msw', 'state']
# Defined 80286 FLAGS bits: CF PF AF ZF SF TF IF DF OF IOPL NT.
FLAGS_MASK = 0x7fd5
STATE_NAMES = {0: 'run', 1: 'halt', 2: 'shutdown', 3: 'stop'}


def parse_trace(path):
    steps, ports, memory, extra, end = [], [], {}, [], 'missing'
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == 'S':
            values = [int(v, 16) for v in parts[1:17]]
            values[2] &= FLAGS_MASK
            steps.append(tuple(values))
            extra.append(' '.join(parts[17:]))
        elif parts[0] == 'O':
            ports.append((int(parts[1], 16), int(parts[2], 16)))
        elif parts[0] == 'W':
            memory[int(parts[1], 16)] = int(parts[2], 16)
        elif parts[0] == 'END':
            end = parts[1]
    return steps, ports, memory, extra, end


def parse_scenario(path):
    memory = {}
    for line in Path(path).read_text().splitlines():
        if line.startswith('MEM '):
            _, address, data = line.split()
            for i, byte in enumerate(bytes.fromhex(data)):
                memory[int(address, 16) + i] = byte
    return memory


def show(step):
    return ' '.join(f'{name}={value:04x}' for name, value in zip(FIELDS, step))


def where(step):
    """Human label for a boundary: handler vector, or CS:IP."""
    if step[0] == 0x38 and step[1] % 4 <= 1:
        return f'vector {step[1] // 4}'
    return f'{step[0]:04x}:{step[1]:04x}'


def compare(scenario, oracle_path, rtl_path):
    initial = parse_scenario(scenario)
    o_steps, o_ports, o_mem, _, o_end = parse_trace(oracle_path)
    r_steps, r_ports, r_mem, r_extra, r_end = parse_trace(rtl_path)
    problems, notes = [], []
    i = j = 0
    while i < len(o_steps) and j < len(r_steps):
        if o_steps[i] == r_steps[j]:
            i += 1; j += 1
            continue
        # The RTL reports a trap and its instruction as two boundaries
        # where the oracle reports one, and the reverse for some repeats.
        if j + 1 < len(r_steps) and r_steps[j + 1] == o_steps[i]:
            notes.append(f'skipped RTL boundary {j}')
            j += 1
            continue
        if i + 1 < len(o_steps) and o_steps[i + 1] == r_steps[j]:
            notes.append(f'skipped oracle step {i}')
            i += 1
            continue
        differing = [name for name, a, b in zip(FIELDS, o_steps[i], r_steps[j]) if a != b]
        problems.append({
            'kind': 'state', 'step': i, 'fields': differing,
            'signature': f'oracle {where(o_steps[i])} / rtl {where(r_steps[j])}'
                         if {'cs', 'ip'} & set(differing) else 'state ' + ','.join(differing),
            'before': show(o_steps[i - 1]) if i else 'reset',
            'oracle': show(o_steps[i]), 'rtl': show(r_steps[j]) + ' [' + r_extra[j] + ']'})
        break
    else:
        if i < len(o_steps) or j < len(r_steps):
            problems.append({'kind': 'length', 'signature': f'trace length: oracle ends {o_end}, rtl ends {r_end}',
                             'oracle': f'{len(o_steps)} steps, END {o_end}', 'rtl': f'{len(r_steps)} boundaries, END {r_end}'})
    if not problems and o_end != r_end:
        problems.append({'kind': 'end', 'signature': f'end: oracle {o_end}, rtl {r_end}', 'oracle': o_end, 'rtl': r_end})
    if o_ports != r_ports:
        problems.append({'kind': 'ports', 'signature': 'port writes', 'oracle': str(o_ports[:8]), 'rtl': str(r_ports[:8])})
    diffs = []
    for address in sorted(set(o_mem) | set(r_mem)):
        a = o_mem.get(address, initial.get(address, 0))
        b = r_mem.get(address, initial.get(address, 0))
        if a != b:
            diffs.append((address, a, b))
    if diffs:
        accessed_only = all(0x1000 <= address < 0x3000 and address % 8 == 5 and (a ^ b) == 1 for address, a, b in diffs)
        problems.append({'kind': 'memory',
                         'signature': 'descriptor accessed bit only' if accessed_only else 'memory',
                         'bytes': [f'{address:06x}: oracle {a:02x} rtl {b:02x}' for address, a, b in diffs[:24]],
                         'count': len(diffs)})
    return problems, notes


def run_one(args):
    scenario, work, wait = args
    name = scenario.stem
    oracle_trace = work / 'trace' / f'{name}.oracle'
    rtl_trace = work / 'trace' / f'{name}.rtl'
    for command in ([str(work / 'pce286_oracle'), str(scenario), str(oracle_trace)],
                    [str(work / 'rtl' / 'replay'), str(scenario), str(rtl_trace), '1' if wait else '0']):
        result = subprocess.run(command, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            return name, [{'kind': 'tool', 'signature': 'tool failure', 'oracle': ' '.join(command),
                           'rtl': result.stderr[-400:]}], []
    problems, notes = compare(scenario, oracle_trace, rtl_trace)
    return name, problems, notes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('work')
    parser.add_argument('-k', default='*')
    parser.add_argument('--wait', action='store_true', help='stall READY three of every four cycles')
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    work = Path(args.work).resolve()
    (work / 'trace').mkdir(parents=True, exist_ok=True)
    detail_dir = work / 'mismatch'
    detail_dir.mkdir(exist_ok=True)
    for old in detail_dir.glob('*.txt'):
        old.unlink()
    waivers = json.loads((ROOT / 'tb/pce_oracle/waivers.json').read_text())
    scenarios = sorted(p for p in (work / 'scn').glob('*.scn') if fnmatch.fnmatch(p.stem, args.k))
    results = {}
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        for name, problems, notes in pool.map(run_one, [(s, work, args.wait) for s in scenarios]):
            status, waiver = 'PASS', None
            if problems:
                waiver = next((w for w in waivers if fnmatch.fnmatch(name, w['match'])), None)
                status = 'WAIVED' if waiver else 'MISMATCH'
                lines = [f'scenario: {name}', f'status: {status}', f'scenario file: {work}/scn/{name}.scn',
                         f'traces: {work}/trace/{name}.oracle  {work}/trace/{name}.rtl', '']
                if waiver:
                    lines += [f'waiver: {waiver["reason"]}', f'source: {waiver["source"]}', '']
                for problem in problems:
                    lines.append(f'[{problem["kind"]}] {problem["signature"]}')
                    for key in ('step', 'fields', 'before', 'oracle', 'rtl', 'count'):
                        if key in problem:
                            lines.append(f'  {key}: {problem[key]}')
                    lines += ['  ' + b for b in problem.get('bytes', [])]
                (detail_dir / f'{name}.txt').write_text('\n'.join(lines) + '\n')
            results[name] = {'status': status, 'problems': problems, 'notes': notes}
    (work / 'results.json').write_text(json.dumps(results, indent=1) + '\n')
    counts = Counter(r['status'] for r in results.values())
    groups = defaultdict(list)
    for name, result in results.items():
        if result['status'] == 'MISMATCH':
            groups[(name.split('.')[0], result['problems'][0]['signature'])].append(name)
    report = [f'PCE-286 oracle comparison: {len(results)} scenarios, {counts["PASS"]} PASS, '
              f'{counts["MISMATCH"]} MISMATCH, {counts["WAIVED"]} WAIVED', '']
    family_totals = Counter(name.split('.')[0] for name in results)
    by_status = Counter((name.split('.')[0], r['status']) for name, r in results.items())
    for fam in sorted(family_totals):
        report.append(f'  {fam:24s} {by_status[(fam, "PASS")]:5d} pass {by_status[(fam, "WAIVED")]:4d} waived '
                      f'{by_status[(fam, "MISMATCH")]:4d} mismatch  of {family_totals[fam]}')
    report.append('')
    report.append('Mismatch groups (family, first difference), largest first:')
    for (fam, signature), names in sorted(groups.items(), key=lambda item: -len(item[1])):
        report.append(f'  {len(names):4d}  {fam}: {signature}   e.g. {names[0]}')
    text = '\n'.join(report) + '\n'
    (work / 'report.txt').write_text(text)
    print(text)
    print(f'details: {detail_dir}/<scenario>.txt   results: {work}/results.json')
    raise SystemExit(1 if counts['MISMATCH'] else 0)


if __name__ == '__main__':
    main()
