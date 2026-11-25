#!/usr/bin/env python3
"""Generate and formally verify primary-input witnesses for deep core covers."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from audit_formal import (
    ASSUMPTION_FAILED_RE,
    CORE_MODULE,
    CORE_WITNESS_TASK,
    PRIMARY_INPUT_PORT_WIDTHS,
    count_smt2_asserts,
    digest,
    elaborated_core_cover_names,
    parse_reached_covers,
    sections,
    validate_smtc_file,
    validate_yw_file,
)
from work_paths import get_work_root

PORT_ORDER = tuple(PRIMARY_INPUT_PORT_WIDTHS.items())
SMTC_STATE_LINE_RE = re.compile(r'^state\s+(\d+)$')
SMTC_ASSUME_LINE_RE = re.compile(
    r'^assume\s+\(\s*=\s*\[([A-Za-z_][A-Za-z0-9_]*)\]\s+'
    r'(true|false|#b[01]+|#x[0-9a-fA-F]+)\s*\)$'
)


def _run(cmd, *, cwd=None, log_path=None):
    proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    combined = (proc.stdout or '') + (proc.stderr or '')
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(combined)
    if proc.returncode != 0:
        tail = '\n'.join(combined.splitlines()[-30:])
        raise RuntimeError(f'Command failed ({proc.returncode}): {" ".join(cmd)}\n{tail}')
    return combined


def _copy_core_sources(design_dir, out_dir):
    config_path = design_dir / 'formal/intel_80286.sby'
    config = sections(config_path)
    src_dir = out_dir / 'src'
    src_dir.mkdir(parents=True, exist_ok=True)
    copied = []
    for entry in config.get('files', []):
        if any(char.isspace() for char in entry) or any(c in entry for c in '*?[]$'):
            raise ValueError(f'{config_path}: unsupported file entry {entry}')
        original = (config_path.parent / entry).resolve()
        dest = src_dir / original.name
        shutil.copy2(original, dest)
        copied.append({'source': entry, 'snapshot': f'src/{original.name}', 'sha256': digest(original)})
    return copied


def _prepare_sim_model(prove_il, out_dir, prove_assert_count, expected_cover_count):
    model_dir = out_dir / 'model'
    model_dir.mkdir(parents=True, exist_ok=True)
    sim_prep_il = model_dir / 'sim_prep.il'
    sim_prep_stat = model_dir / 'sim_prep_stat.json'
    sim_prep_ys = model_dir / 'sim_prep.ys'
    # Keep every assertion and assumption (core + submodule) while removing
    # submodule covers so only core CPU covers remain in the lowered RTLIL.
    sim_prep_ys.write_text(
        f'read_rtlil {prove_il}\n'
        f'chformal -cover -remove */t:$check {CORE_MODULE}/t:$check %d\n'
        'memory_nordff\n'
        'async2sync\n'
        'chformal -lower\n'
        'opt_clean\n'
        f'tee -q -o {sim_prep_stat} stat -top {CORE_MODULE} -json\n'
        f'write_rtlil {sim_prep_il}\n'
    )
    _run(['yosys', '-ql', str(model_dir / 'sim_prep.log'), str(sim_prep_ys)])
    stat_doc = json.loads(sim_prep_stat.read_text())
    cells = stat_doc.get('design', {}).get('num_cells_by_type', {})
    if cells.get('$assert') != prove_assert_count:
        raise RuntimeError(
            f"Lowered model $assert count {cells.get('$assert')} != prove {prove_assert_count}")
    if not isinstance(cells.get('$assume'), int) or cells['$assume'] < 1:
        raise RuntimeError(f"Lowered model $assume count {cells.get('$assume')!r} < 1")
    if cells.get('$cover') != expected_cover_count:
        raise RuntimeError(
            f"Lowered model $cover count {cells.get('$cover')} != expected {expected_cover_count}")
    return sim_prep_il, sim_prep_stat


def _smtc_to_yw(smtc_path, yw_path):
    validate_smtc_file(smtc_path)
    steps = []
    current = None
    for raw in smtc_path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        state_match = SMTC_STATE_LINE_RE.match(line)
        if state_match:
            step_idx = int(state_match.group(1))
            if step_idx != len(steps):
                raise ValueError(f'{smtc_path}: non-sequential state index {step_idx}')
            current = {}
            steps.append(current)
            continue
        assume_match = SMTC_ASSUME_LINE_RE.match(line)
        if not assume_match or current is None:
            raise ValueError(f'{smtc_path}: malformed constraint line {line!r}')
        port, raw_val = assume_match.groups()
        width = PRIMARY_INPUT_PORT_WIDTHS[port]
        if raw_val == 'true':
            bits = '1'
        elif raw_val == 'false':
            bits = '0'
        elif raw_val.startswith('#b'):
            bits = raw_val[2:]
        else:
            bits = format(int(raw_val[2:], 16), f'0{len(raw_val[2:]) * 4}b')
        if len(bits) != width:
            raise ValueError(f'{smtc_path}: width mismatch for {port}: got {len(bits)}, expected {width}')
        current[port] = bits

    doc = {
        'format': 'Yosys Witness Trace',
        'generator': 'core_cover_witnesses',
        'clocks': [{'path': ['\\clk'], 'edge': 'posedge', 'offset': 0}],
        'signals': [
            {'path': [f'\\{port}'], 'width': width, 'offset': 0, 'init_only': False}
            for port, width in PORT_ORDER
        ],
        'steps': [
            {'bits': ''.join(step[port] for port, _ in reversed(PORT_ORDER))}
            for step in steps
        ],
    }
    yw_path.write_text(json.dumps(doc) + '\n')
    return validate_yw_file(yw_path)


def _build_and_run_generator(design_dir, out_dir):
    build_dir = out_dir / 'witness_gen'
    witness_dir = out_dir / 'witnesses'
    build_dir.mkdir(parents=True, exist_ok=True)
    witness_dir.mkdir(parents=True, exist_ok=True)
    sv_files = sorted(str(p) for p in (design_dir / 'src').glob('*.sv'))
    if not sv_files:
        raise RuntimeError('No RTL .sv files found under src/')
    gen_cpp = design_dir / 'tb/core_cover_witnesses.cpp'
    _run([
        'verilator', '--cc', '--exe', '--build', '-j', '4', '-Wall',
        '--top-module', CORE_MODULE, '--Mdir', str(build_dir),
        '-CFLAGS', '-std=c++17', '-o', 'core_cover_witnesses',
        *sv_files, str(gen_cpp),
    ], cwd=design_dir, log_path=build_dir / 'build.log')
    _run([str(build_dir / 'core_cover_witnesses'), str(witness_dir)],
         cwd=design_dir, log_path=witness_dir / 'generate.log')
    scenarios = json.loads((witness_dir / 'scenarios.json').read_text()).get('scenarios', [])
    if not scenarios:
        raise RuntimeError('No witness scenarios generated')
    for scenario in scenarios:
        smtc_path = witness_dir / scenario['smtc']
        smtc_states = validate_smtc_file(smtc_path)
        yw_steps = _smtc_to_yw(smtc_path, witness_dir / f"{scenario['name']}.yw")
        if smtc_states != yw_steps:
            raise RuntimeError(f"{scenario['name']}: step count mismatch {smtc_states} != {yw_steps}")
    return witness_dir, scenarios


def _verify_scenario(scenario, sim_prep_il, witness_dir, out_dir):
    name = scenario['name']
    targets = scenario['targets']
    group_dir = out_dir / 'groups' / name
    group_dir.mkdir(parents=True, exist_ok=True)

    smtc_dst = group_dir / 'witness.smtc'
    yw_dst = group_dir / 'witness.yw'
    shutil.copy2(witness_dir / scenario['smtc'], smtc_dst)
    shutil.copy2(witness_dir / f'{name}.yw', yw_dst)
    yw_steps = validate_yw_file(yw_dst)

    script_path = group_dir / 'sim.ys'
    log_path = group_dir / 'sim.log'
    summary_path = group_dir / 'summary.json'
    script_path.write_text(
        f'read_rtlil {sim_prep_il}\n'
        f'sim -q -assert -r {yw_dst} -summary {summary_path} {CORE_MODULE}\n'
    )
    proc = subprocess.run(['yosys', '-ql', str(log_path), str(script_path)], text=True, capture_output=True)
    log_text = log_path.read_text() if log_path.is_file() else ((proc.stdout or '') + (proc.stderr or ''))
    if proc.returncode != 0 or 'End of script.' not in log_text:
        tail = '\n'.join(log_text.splitlines()[-25:])
        raise RuntimeError(f'{name}: Yosys formal sim failed (rc={proc.returncode})\n{tail}')
    if ('ERROR:' in log_text or 'Failed assertion' in log_text or
            ASSUMPTION_FAILED_RE.search(log_text)):
        raise RuntimeError(f'{name}: assertion or assumption failure in Yosys formal sim log')

    summary = json.loads(summary_path.read_text())
    if summary.get('top') != CORE_MODULE:
        raise RuntimeError(f"{name}: unexpected summary top module {summary.get('top')!r}")
    if summary.get('steps') != yw_steps - 1:
        raise RuntimeError(f"{name}: summary steps {summary.get('steps')!r} != {yw_steps - 1}")
    entries = summary.get('assertions')
    if not isinstance(entries, list):
        raise RuntimeError(f'{name}: missing assertions list in summary')
    non_cover = [entry for entry in entries
                 if not isinstance(entry, dict) or entry.get('type') != '$cover']
    if non_cover:
        raise RuntimeError(f'{name}: non-cover entries in summary: {non_cover[:3]}')

    hit_steps = {}
    for entry in entries:
        path = entry.get('path')
        step = entry.get('step')
        if (isinstance(path, list) and len(path) == 1 and isinstance(path[0], str) and
                isinstance(step, int) and step >= 0):
            cname = path[0].lstrip('\\')
            hit_steps.setdefault(cname, []).append(step)

    reached = [target for target in targets if target in hit_steps]
    missing = [target for target in targets if target not in hit_steps]
    if missing:
        raise RuntimeError(f'{name}: missed target covers: {", ".join(missing)}')
    return {
        'name': name,
        'targets': targets,
        'reached': sorted(reached),
        'hit_steps': {target: hit_steps[target] for target in targets},
        'steps': yw_steps,
        'smtc': smtc_dst.relative_to(out_dir).as_posix(),
        'yw': yw_dst.relative_to(out_dir).as_posix(),
        'script': script_path.relative_to(out_dir).as_posix(),
        'log': log_path.relative_to(out_dir).as_posix(),
        'summary': summary_path.relative_to(out_dir).as_posix(),
    }


def run(design_dir, formal_work_dir, jobs):
    start = time.monotonic()
    prove_dir = formal_work_dir / f'{CORE_MODULE}_prove'
    cover_dir = formal_work_dir / f'{CORE_MODULE}_cover'
    prove_il = prove_dir / 'model/design.il'
    prove_json = prove_dir / 'model/design.json'
    prove_smt2 = prove_dir / 'model/design_smt2.smt2'
    blind_log = cover_dir / 'logfile.txt'
    for required in (prove_il, prove_json, prove_smt2, blind_log):
        if not required.is_file():
            raise FileNotFoundError(f'Missing prerequisite formal artifact: {required}')

    all_covers = elaborated_core_cover_names(prove_json)
    if not all_covers:
        raise RuntimeError(f'No elaborated CPU covers found in {prove_json}')
    prove_assert_count = count_smt2_asserts(prove_smt2)
    if prove_assert_count == 0:
        raise RuntimeError(f'No assertions found in {prove_smt2}')
    blind_reached = parse_reached_covers(blind_log)

    out_dir = formal_work_dir / CORE_WITNESS_TASK
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    sources = _copy_core_sources(design_dir, out_dir)
    sim_prep_il, sim_prep_stat = _prepare_sim_model(
        prove_il, out_dir, prove_assert_count, len(all_covers))
    witness_dir, scenarios = _build_and_run_generator(design_dir, out_dir)

    declared_targets = set()
    for scenario in scenarios:
        declared_targets.update(scenario['targets'])
    pre_missing = sorted(set(all_covers) - (blind_reached | declared_targets))
    if pre_missing:
        raise RuntimeError(
            f'Blind covers plus scenario declarations omit {len(pre_missing)} core covers: '
            f'{", ".join(pre_missing)}')

    groups = []
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        futures = {
            pool.submit(_verify_scenario, scenario, sim_prep_il, witness_dir, out_dir): scenario['name']
            for scenario in scenarios
        }
        for future in as_completed(futures):
            group = future.result()
            groups.append(group)
            print(
                f'PASS: witness {group["name"]} '
                f'({len(group["reached"])} targets, {group["steps"]} steps)'
            )
    groups.sort(key=lambda item: item['name'])

    witness_reached = set()
    for group in groups:
        witness_reached.update(group['reached'])
    union_reached = blind_reached | witness_reached
    missing_final = sorted(set(all_covers) - union_reached)
    if missing_final:
        raise RuntimeError(f'Unreached core covers ({len(missing_final)}): {", ".join(missing_final)}')

    elapsed = int(round(time.monotonic() - start))
    manifest = {
        'engine': 'yosys-sim',
        'core_module': CORE_MODULE,
        'model_il': sim_prep_il.relative_to(out_dir).as_posix(),
        'model_stat': sim_prep_stat.relative_to(out_dir).as_posix(),
        'prove_assert_count': prove_assert_count,
        'total_core_covers': len(all_covers),
        'blind_reached': sorted(set(all_covers) & blind_reached),
        'witness_reached': sorted(set(all_covers) & witness_reached),
        'sources': sources,
        'groups': groups,
        'elapsed_seconds': elapsed,
    }
    (out_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out_dir / 'PASS').write_text(
        f'Verified {len(witness_reached & set(all_covers))} deep covers across {len(groups)} groups '
        f'with Yosys formal sim -assert; total core covers reached: '
        f'{len(set(all_covers) & union_reached)}/{len(all_covers)}\n'
    )
    (out_dir / 'status').write_text(f'PASS 0 {elapsed}\n')
    print(
        f'PASS: {CORE_WITNESS_TASK} reached {len(set(all_covers) & union_reached)}/{len(all_covers)} '
        f'core covers ({len(blind_reached & set(all_covers))} blind + '
        f'{len(witness_reached & set(all_covers))} witnessed) in {elapsed} s'
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--design-dir', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--formal-work-dir', type=Path)
    parser.add_argument('--jobs', type=int, default=min(2, os.cpu_count() or 1))
    args = parser.parse_args()
    formal_dir = args.formal_work_dir or (get_work_root(args.design_dir) / 'formal')
    run(args.design_dir.resolve(), formal_dir.resolve(), args.jobs)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
