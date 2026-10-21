#!/usr/bin/env python3
"""Verify every implemented classic 74-series function from the frozen manifest."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/library'


def inventory():
    entries = json.loads((ROOT / 'manifest.json').read_text())
    modules = set()
    for chip in entries:
        if chip['status'] == 'excluded':
            if chip['number'] not in {31, 121, 122, 123, 124, 130, 221}:
                raise ValueError(f'Unexpected exclusion: {chip["part_number"]}')
            continue
        module = chip['module']
        if module in modules:
            raise ValueError(f'Duplicate module: {module}')
        modules.add(module)
        for field in ('rtl', 'testbench', 'specification'):
            if not (ROOT / chip[field]).is_file():
                raise ValueError(f'{module}: missing {field}: {chip[field]}')
        text = (ROOT / chip['rtl']).read_text()
        declarations = re.findall(r'^\s*module\s+(\w+)', text, re.M)
        if declarations != [module]:
            raise ValueError(f'{module}: expected one matching module, got {declarations}')
        if re.search(r'\b(?:TODO|FIXME)\b', text):
            raise ValueError(f'{module}: unresolved TODO/FIXME')
    actual = {p.stem for p in (ROOT / 'src').glob('ttl_*.sv')}
    if actual != modules:
        raise ValueError(f'Manifest/source mismatch: {actual ^ modules}')
    if len(modules) != 289 or len(entries) != 296:
        raise ValueError('Inventory cardinality changed; review the range and exclusions')
    return [entry for entry in entries if entry['status'] != 'excluded']


def invoke(command, log, *, cwd=None, timeout=180):
    with log.open('w') as output:
        try:
            completed = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT,
                                       cwd=cwd, timeout=timeout, check=False)
            return completed.returncode == 0
        except subprocess.TimeoutExpired:
            output.write(f'\nERROR: timeout after {timeout} seconds\n')
            return False


def check(chip, phase):
    module = chip['module']
    directory = WORK / module
    directory.mkdir(parents=True, exist_ok=True)
    sources = [str(ROOT / chip['rtl'])]
    if module == 'ttl_74x181':
        sources.insert(0, str(ROOT / 'src/alu_74181.sv'))
    started = time.monotonic()
    log = directory / f'{phase}.log'
    if phase == 'lint':
        command = ['verilator', '--lint-only', '-Wall', '--top-module', module, *sources]
        ok = invoke(command, log)
    elif phase == 'sim':
        command = ['xezim', '--simulate', '--sv2017', '--error-exit',
                   '--max-time', '100ms', '-s', f'tb_{module}', *sources,
                   str(ROOT / chip['testbench'])]
        ok = invoke(command, log, cwd=ROOT)
        ok = ok and bool(re.search(r'^PASS: tb_' + re.escape(module) + r'\b', log.read_text(), re.M))
    elif phase == 'synth':
        command = ['yosys', '-Q', '-T', '-p',
                   'read_verilog -sv ' + ' '.join(sources) +
                   f'; hierarchy -check -top {module}; synth -top {module}; check -assert; stat']
        ok = invoke(command, log)
    else:
        raise ValueError(phase)
    result = {'module': module, 'phase': phase, 'passed': ok,
              'source_digest': digest(chip, phase),
              'seconds': round(time.monotonic() - started, 3),
              'log': str(log.relative_to(ROOT))}
    (directory / f'{phase}.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'{"PASS" if ok else "FAIL"} {phase:5s} {module}', flush=True)
    return result


def digest(chip, phase):
    paths=[ROOT/chip['rtl']]
    if chip['module']=='ttl_74x181':
        paths.append(ROOT/'src/alu_74181.sv')
    if phase=='sim':
        paths.append(ROOT/chip['testbench'])
        paths.extend(sorted((ROOT/'tb/data').glob('*.hex')))
    paths.append(Path(__file__).resolve())
    return hashlib.sha256(b''.join(path.read_bytes() for path in paths)).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['inventory', 'all', 'lint', 'sim', 'synth'])
    parser.add_argument('--chip', help='Only check this manifest module')
    parser.add_argument('--jobs', type=int, default=int(os.getenv('TTL_JOBS', '4')))
    parser.add_argument('--failed', action='store_true', help='Retry missing or failed results only')
    args = parser.parse_args()
    chips = inventory()
    print(f'Inventory OK: {len(chips)} digital functions, 7 explicit analog/timing exclusions', flush=True)
    if args.phase == 'inventory':
        return 0
    if args.chip:
        chips = [c for c in chips if c['module'] == args.chip]
        if not chips:
            parser.error(f'No implemented module: {args.chip}')
    phases = ['lint', 'sim', 'synth'] if args.phase == 'all' else [args.phase]
    tasks = [(chip, phase) for chip in chips for phase in phases]
    if args.failed:
        tasks = [(c, p) for c, p in tasks if not (WORK / c['module'] / f'{p}.json').is_file()
                 or not json.loads((WORK / c['module'] / f'{p}.json').read_text())['passed']
                 or json.loads((WORK / c['module'] / f'{p}.json').read_text()).get('source_digest')!=digest(c,p)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        results = list(pool.map(lambda task: check(*task), tasks))
    failures = [r for r in results if not r['passed']]
    print(f'{len(results) - len(failures)}/{len(results)} checks passed', flush=True)
    if failures:
        for result in failures:
            print(f'  {result["module"]} {result["phase"]}: {result["log"]}')
    return int(bool(failures))


if __name__ == '__main__':
    sys.exit(main())
