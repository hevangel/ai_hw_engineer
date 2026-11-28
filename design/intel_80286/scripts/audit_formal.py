#!/usr/bin/env python3
"""Reject incomplete, stale-source or stale-configuration formal evidence.

Supports the deliberately simple task/file syntax used by this design. Unknown
syntax fails closed instead of pretending to interpret the full SBY language.
This audits saved evidence; it does not run or replace SymbiYosys.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from work_paths import get_work_root

CORE_MODULE = 'intel_80286'
CORE_PROPERTY_SOURCE = 'intel_80286_props.sv'
CORE_WITNESS_TASK = 'intel_80286_cover_witnesses'
PRIMARY_INPUT_PORT_WIDTHS = {
    'rst_n': 1,
    'bus_ready_i': 1,
    'bus_rdata_i': 16,
    'intr_i': 1,
    'nmi_i': 1,
    'inta_ready_i': 1,
    'inta_vector_i': 8,
    'busy_i': 1,
    'error_n_i': 1,
    'pereq_i': 1,
}
PRIMARY_INPUT_PORTS = frozenset(PRIMARY_INPUT_PORT_WIDTHS)
TOTAL_INPUT_WITNESS_BITS = sum(PRIMARY_INPUT_PORT_WIDTHS.values())
SMTC_STATE_RE = re.compile(r'^state\s+(0|[1-9][0-9]*)$')
SMTC_ASSUME_RE = re.compile(
    r'^assume\s+\(\s*=\s*\[([A-Za-z_][A-Za-z0-9_]*)\]\s+'
    r'(true|false|#b[01]+|#x[0-9a-fA-F]+)\s*\)$'
)
REACHED_COVER_RE = re.compile(
    r'Reached cover statement in step \d+ at ' + CORE_MODULE +
    r':\s+(\S+)(?:\s+\((\S+)\))?'
)
SMT2_ASSERT_RE = re.compile(r'^; yosys-smt2-assert ', re.M)
ASSUMPTION_FAILED_RE = re.compile(r'Assumption\b.*\bfailed')


def sections(path):
    result = {}
    current = None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('[') and line.endswith(']'):
            current = line[1:-1]
            if current not in {'tasks', 'options', 'engines', 'script', 'files'}:
                raise ValueError(f'{path}: unsupported section {current}')
            if current in result:
                raise ValueError(f'{path}: repeated section {current}')
            result[current] = []
        elif current is None:
            raise ValueError(f'{path}: content outside a section')
        else:
            result[current].append(line)
    return result


def task_config(config, task):
    resolved = {}
    for section, lines in config.items():
        if section == 'tasks':
            continue
        selected = []
        for line in lines:
            conditional = re.match(r'^([\w]+):\s*(.*)$', line)
            if conditional:
                label, line = conditional.groups()
                if label not in config['tasks']:
                    raise ValueError(f'unsupported task condition: {label}')
                if label != task:
                    continue
            selected.append(line)
        resolved[section] = selected
    return resolved


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _elaborated_core_check_cells(path):
    """Return CPU ``$check`` cells emitted by ``CORE_PROPERTY_SOURCE``.

    Yosys 0.69 writes formal properties as ``$check`` cells in a JNY
    ``modules`` / ``cell_sorts`` inventory.  The ``src`` attribute identifies
    the source file that emitted each check.  Restricting both the module and
    source prevents component properties or unrelated checks from satisfying
    the CPU's property-presence requirement.
    """
    try:
        design = json.loads(path.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f'{path}: cannot read Yosys model JSON: {error}') from error
    modules = design.get('modules') if isinstance(design, dict) else None
    if not isinstance(modules, list):
        raise ValueError(f'{path}: Yosys model has no module inventory')
    core_modules = [module for module in modules
                    if isinstance(module, dict) and module.get('name') == CORE_MODULE]
    if len(core_modules) != 1:
        raise ValueError(f'{path}: expected one {CORE_MODULE} module, found {len(core_modules)}')
    sorts = core_modules[0].get('cell_sorts')
    if not isinstance(sorts, list):
        raise ValueError(f'{path}: {CORE_MODULE} has no cell inventory')

    matched = []
    for cell_sort in sorts:
        if not isinstance(cell_sort, dict) or cell_sort.get('type') != '$check':
            continue
        cells = cell_sort.get('cells')
        if not isinstance(cells, list):
            continue
        for cell in cells:
            if not isinstance(cell, dict):
                continue
            attributes = cell.get('attributes')
            parameters = cell.get('parameters')
            if not isinstance(attributes, dict) or not isinstance(parameters, dict):
                continue
            source = attributes.get('src')
            flavor = parameters.get('FLAVOR')
            if (not isinstance(source, str) or not isinstance(flavor, str) or
                    flavor not in {'assert', 'cover'}):
                continue
            source_file = source.split(':', 1)[0].replace('\\', '/').rsplit('/', 1)[-1]
            if source_file == CORE_PROPERTY_SOURCE:
                matched.append((cell.get('name'), flavor, source))
    return matched


def elaborated_core_properties(path):
    """Count CPU assertions/covers retained in the top module's Yosys JSON."""
    counts = {'assert': 0, 'cover': 0}
    for _, flavor, _ in _elaborated_core_check_cells(path):
        counts[flavor] += 1
    return counts


def elaborated_core_cover_names(path):
    """Return {cell_name: src} for every elaborated CPU cover cell."""
    covers = {}
    for name, flavor, source in _elaborated_core_check_cells(path):
        if flavor != 'cover':
            continue
        if not isinstance(name, str) or not name:
            raise ValueError(f'{path}: unnamed cover cell at {source}')
        covers[name] = source
    return covers


def count_smt2_asserts(path):
    """Count emitted ``; yosys-smt2-assert`` entries in an SMT2 model."""
    return len(SMT2_ASSERT_RE.findall(path.read_text()))


def parse_reached_covers(log_path):
    """Extract reached CPU cover cell names from an sby/smtbmc logfile."""
    reached = set()
    for match in REACHED_COVER_RE.finditer(log_path.read_text()):
        reached.add(match.group(2) or match.group(1))
    return reached


def validate_smtc_file(path):
    """Verify a witness .smtc file constrains only the 10 CPU primary inputs."""
    states = 0
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if SMTC_STATE_RE.match(line):
            states += 1
            continue
        assume = SMTC_ASSUME_RE.match(line)
        if not assume:
            raise ValueError(f'{path}:{lineno}: disallowed .smtc directive: {line}')
        port = assume.group(1)
        if port not in PRIMARY_INPUT_PORTS:
            raise ValueError(f'{path}:{lineno}: non-primary-input constraint [{port}]')
    if states == 0:
        raise ValueError(f'{path}: no state blocks in .smtc file')
    return states


def validate_yw_file(path):
    """Verify a witness .yw file drives only the 10 CPU primary inputs from reset."""
    try:
        doc = json.loads(path.read_text())
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f'{path}: invalid witness JSON: {error}') from error
    if not isinstance(doc, dict) or doc.get('format') != 'Yosys Witness Trace':
        raise ValueError(f'{path}: invalid Yosys Witness Trace header')
    if doc.get('clocks') != [{'path': ['\\clk'], 'edge': 'posedge', 'offset': 0}]:
        raise ValueError(f'{path}: unexpected clock definition')
    signals = doc.get('signals')
    if not isinstance(signals, list) or not signals:
        raise ValueError(f'{path}: missing witness signals list')

    seen = set()
    bit_pos = TOTAL_INPUT_WITNESS_BITS
    rst_slice = None
    for sig in signals:
        if not isinstance(sig, dict):
            raise ValueError(f'{path}: malformed signal entry')
        sig_path = sig.get('path')
        if not isinstance(sig_path, list) or len(sig_path) != 1 or not isinstance(sig_path[0], str):
            raise ValueError(f'{path}: non-primary-input signal path {sig_path!r}')
        port = sig_path[0].lstrip('\\')
        if port not in PRIMARY_INPUT_PORT_WIDTHS or port in seen:
            raise ValueError(f'{path}: disallowed or duplicate witness signal {sig_path[0]}')
        expected_width = PRIMARY_INPUT_PORT_WIDTHS[port]
        if sig.get('width') != expected_width or sig.get('offset') != 0 or sig.get('init_only') is not False:
            raise ValueError(f'{path}: invalid signal metadata for {port}')
        seen.add(port)
        next_pos = bit_pos - expected_width
        if port == 'rst_n':
            rst_slice = (next_pos, bit_pos)
        bit_pos = next_pos

    if seen != PRIMARY_INPUT_PORTS or bit_pos != 0 or rst_slice is None:
        raise ValueError(f'{path}: incomplete primary-input signal set')

    steps = doc.get('steps')
    if not isinstance(steps, list) or not steps:
        raise ValueError(f'{path}: missing witness steps')
    for idx, step in enumerate(steps):
        if not isinstance(step, dict):
            raise ValueError(f'{path}: step {idx} is not an object')
        bits = step.get('bits')
        if (not isinstance(bits, str) or len(bits) != TOTAL_INPUT_WITNESS_BITS or
                not set(bits) <= {'0', '1'}):
            raise ValueError(f'{path}: step {idx} has invalid or non-binary bits')
    if steps[0]['bits'][rst_slice[0]:rst_slice[1]] != '0':
        raise ValueError(f'{path}: step 0 does not hold rst_n low')
    return len(steps)


def _safe_relpath(base, rel):
    if not isinstance(rel, str) or not rel or Path(rel).is_absolute():
        raise ValueError(f'invalid relative witness artifact path: {rel!r}')
    resolved = (base / rel).resolve()
    base_resolved = base.resolve()
    if resolved != base_resolved and base_resolved not in resolved.parents:
        raise ValueError(f'witness artifact escapes directory: {rel!r}')
    return resolved


def _check_source_snapshots(source_config, expected, run_dir):
    errors = []
    files = []
    for entry in expected.get('files', []):
        # Current configurations copy one relative source to its basename.
        # Reject aliases/globs/commands rather than silently skipping them.
        if any(char.isspace() for char in entry) or any(c in entry for c in '*?[]$'):
            raise ValueError(f'{source_config}: unsupported file entry {entry}')
        original = source_config.parent / entry
        snapshot = run_dir / 'src' / original.name
        try:
            if not original.read_text().strip() or not snapshot.read_text().strip():
                errors.append(f'empty source or snapshot: {entry}')
            current_hash = digest(original)
            saved_hash = digest(snapshot)
            files.append({'source': entry, 'sha256': current_hash})
            if current_hash != saved_hash:
                errors.append(f'stale source snapshot: {entry}')
        except OSError as error:
            errors.append(f'source snapshot: {error}')
    if not expected.get('files'):
        errors.append('empty source inventory')
    return files, errors


def audit_core_cover_witnesses(source_config, config, core_root):
    """Fail-closed audit for witnessed deep core covers and full cover union."""
    witness_dir = core_root / CORE_WITNESS_TASK
    errors = []
    try:
        status = (witness_dir / 'status').read_text().split()[0]
        if status != 'PASS' or not (witness_dir / 'PASS').is_file():
            errors.append(f'not completed successfully: {status}')
    except (OSError, IndexError):
        errors.append('missing completion status')

    expected = task_config(config, 'prove')
    files, snapshot_errors = _check_source_snapshots(source_config, expected, witness_dir)
    errors.extend(snapshot_errors)

    all_covers = {}
    try:
        all_covers = elaborated_core_cover_names(core_root / 'intel_80286_prove/model/design.json')
        if not all_covers:
            errors.append(f'no elaborated CPU cover cells in {CORE_MODULE} from {CORE_PROPERTY_SOURCE}')
    except ValueError as error:
        errors.append(f'elaborated core cover inventory: {error}')

    prove_asserts = None
    try:
        prove_asserts = count_smt2_asserts(core_root / 'intel_80286_prove/model/design_smt2.smt2')
        if prove_asserts == 0:
            errors.append('prove SMT2 model contains zero assertions')
    except (OSError, UnicodeError) as error:
        errors.append(f'prove SMT2 model: {error}')

    blind_reached = set()
    try:
        blind_reached = parse_reached_covers(core_root / 'intel_80286_cover/logfile.txt')
    except (OSError, UnicodeError) as error:
        errors.append(f'blind core cover log: {error}')

    witness_reached = set()
    try:
        manifest = json.loads((witness_dir / 'manifest.json').read_text())
        if not isinstance(manifest, dict):
            raise ValueError('witness manifest must be a JSON object')
        model_il = _safe_relpath(witness_dir, manifest.get('model_il'))
        if not model_il.is_file() or model_il.stat().st_size == 0:
            errors.append('missing or empty lowered witness model')
        model_stat_path = _safe_relpath(witness_dir, manifest.get('model_stat'))
        stat_doc = json.loads(model_stat_path.read_text())
        cells_by_type = stat_doc.get('design', {}).get('num_cells_by_type')
        if not isinstance(cells_by_type, dict):
            errors.append('witness model stat missing num_cells_by_type')
        else:
            if prove_asserts is not None and cells_by_type.get('$assert') != prove_asserts:
                errors.append(
                    f"witness model $assert count {cells_by_type.get('$assert')} != prove {prove_asserts}")
            assumes = cells_by_type.get('$assume')
            if not isinstance(assumes, int) or assumes < 1:
                errors.append('witness model missing $assume cells')
            if all_covers and cells_by_type.get('$cover') != len(all_covers):
                errors.append(
                    f"witness model $cover count {cells_by_type.get('$cover')} != expected {len(all_covers)}")
        groups = manifest.get('groups')
        if not isinstance(groups, list) or not groups:
            errors.append('witness manifest has no scenario groups')
            groups = []
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        errors.append(f'witness manifest: {error}')
        groups = []

    for group in groups:
        if not isinstance(group, dict):
            errors.append('invalid witness group entry')
            continue
        gname = group.get('name', '<unnamed>')
        targets = group.get('targets')
        if not isinstance(targets, list) or not targets:
            errors.append(f'group {gname}: empty targets')
            continue
        try:
            smtc_path = _safe_relpath(witness_dir, group.get('smtc'))
            yw_path = _safe_relpath(witness_dir, group.get('yw'))
            script_path = _safe_relpath(witness_dir, group.get('script'))
            log_path = _safe_relpath(witness_dir, group.get('log'))
            summary_path = _safe_relpath(witness_dir, group.get('summary'))

            smtc_states = validate_smtc_file(smtc_path)
            yw_steps = validate_yw_file(yw_path)
            if smtc_states != yw_steps:
                errors.append(f'group {gname}: smtc steps {smtc_states} != yw steps {yw_steps}')

            script_text = script_path.read_text()
            sim_lines = [ln.strip() for ln in script_text.splitlines() if ln.strip().startswith('sim ')]
            if not any(' -assert ' in f' {ln} ' and ' -r ' in f' {ln} ' and ' -summary ' in f' {ln} '
                       for ln in sim_lines):
                errors.append(f'group {gname}: Yosys script missing sim -assert -r -summary')
            for forbidden in ('-zinit', '-noinitstate', 'chformal -assert -remove'):
                if forbidden in script_text:
                    errors.append(f'group {gname}: disallowed directive {forbidden} in sim script')

            log_text = log_path.read_text()
            if 'End of script.' not in log_text:
                errors.append(f'group {gname}: Yosys sim log missing End of script.')
            if ('ERROR:' in log_text or 'Failed assertion' in log_text or
                    ASSUMPTION_FAILED_RE.search(log_text)):
                errors.append(f'group {gname}: assertion or assumption failure in sim log')

            summary_doc = json.loads(summary_path.read_text())
            if not isinstance(summary_doc, dict) or summary_doc.get('top') != CORE_MODULE:
                errors.append(f'group {gname}: unexpected summary top module')
            if summary_doc.get('steps') != yw_steps - 1:
                errors.append(f'group {gname}: summary steps {summary_doc.get("steps")!r} != {yw_steps - 1}')
            entries = summary_doc.get('assertions')
            if not isinstance(entries, list):
                errors.append(f'group {gname}: summary missing assertions list')
                entries = []
            non_cover = [entry for entry in entries
                         if not isinstance(entry, dict) or entry.get('type') != '$cover']
            if non_cover:
                errors.append(f'group {gname}: summary recorded {len(non_cover)} non-cover failures')

            group_reached = set()
            for entry in entries:
                if not isinstance(entry, dict) or entry.get('type') != '$cover':
                    continue
                path = entry.get('path')
                step = entry.get('step')
                if (isinstance(path, list) and len(path) == 1 and isinstance(path[0], str) and
                        isinstance(step, int) and step >= 0):
                    group_reached.add(path[0].lstrip('\\'))

            missing_targets = [target for target in targets if target not in group_reached]
            if missing_targets:
                errors.append(f'group {gname}: unreached targets {", ".join(missing_targets)}')
            witness_reached |= group_reached
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
            errors.append(f'group {gname}: {error}')

    union_reached = blind_reached | witness_reached
    if all_covers:
        missing = sorted(set(all_covers) - union_reached)
        if missing:
            errors.append(f'missing core covers ({len(missing)}): {", ".join(missing)}')

    result = {
        'task': CORE_WITNESS_TASK,
        'result': 'FAIL' if errors else 'PASS',
        'errors': errors,
        'files': files,
        'core_covers_reached': len(set(all_covers) & union_reached) if all_covers else len(union_reached),
        'core_covers_total': len(all_covers),
    }
    return result


def audit(design, work, core_work=None, require_pdr=False):
    results = []
    configs = sorted((design / 'formal').glob('*.sby'))
    if not configs:
        raise ValueError('no formal configurations found')
    for source_config in configs:
        if source_config.stem == 'intel_80286_pdr' and not require_pdr:
            continue
        config = sections(source_config)
        expected_tasks = (['prove'] if source_config.stem == 'intel_80286_pdr'
                          else ['bmc', 'prove', 'cover'])
        if config.get('tasks') != expected_tasks:
            task_names = '/'.join(expected_tasks)
            raise ValueError(f'{source_config}: require {task_names} task inventory')
        has_core_property_source = (
            source_config.stem == CORE_MODULE and
            any(Path(entry).name == CORE_PROPERTY_SOURCE
                for entry in config.get('files', [])))
        task_root = core_work if core_work is not None and source_config.stem == 'intel_80286' else work
        for task in config['tasks']:
            run = task_root / f'{source_config.stem}_{task}'
            errors = []
            core_properties = None
            expected = task_config(config, task)
            try:
                status = (run / 'status').read_text().split()[0]
                if status != 'PASS' or not (run / 'PASS').is_file():
                    errors.append(f'not completed successfully: {status}')
            except (OSError, IndexError):
                errors.append('missing completion status')
            try:
                if sections(run / 'config.sby') != expected:
                    errors.append('saved task configuration differs from current configuration')
            except (OSError, ValueError) as error:
                errors.append(f'saved configuration: {error}')
            files, snapshot_errors = _check_source_snapshots(source_config, expected, run)
            errors.extend(snapshot_errors)
            if has_core_property_source:
                try:
                    core_properties = elaborated_core_properties(run / 'model/design.json')
                    for flavor in ('assert', 'cover'):
                        if core_properties[flavor] == 0:
                            errors.append(
                                f'no elaborated CPU {flavor} cells in {CORE_MODULE} '
                                f'from {CORE_PROPERTY_SOURCE}')
                except ValueError as error:
                    errors.append(f'elaborated core property inventory: {error}')
            result = {'task': run.name, 'result': 'FAIL' if errors else 'PASS',
                      'errors': errors, 'files': files}
            if has_core_property_source:
                result['core_properties'] = core_properties
            results.append(result)
        if has_core_property_source:
            results.append(audit_core_cover_witnesses(source_config, config, task_root))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--design-dir', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--work-dir', type=Path)
    parser.add_argument('--core-work-dir', type=Path,
                        help='Use a separate immutable core epoch; components still use --work-dir')
    parser.add_argument('--require-pdr', action='store_true',
                        help='Require optional intel_80286_pdr.sby evidence to be present and passing')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    results = audit(
        args.design_dir,
        args.work_dir or get_work_root(args.design_dir) / 'formal',
        args.core_work_dir,
        require_pdr=args.require_pdr,
    )
    for result in results:
        inventory = result.get('core_properties')
        properties = (f" (core cells: {inventory['assert']} assertions, "
                      f"{inventory['cover']} covers)" if inventory is not None else '')
        if 'core_covers_total' in result:
            properties = (f" (core covers reached: {result['core_covers_reached']}/"
                          f"{result['core_covers_total']})")
        print(f"{result['result']}: {result['task']}{properties}" +
              (': ' + '; '.join(result['errors']) if result['errors'] else ''))
    if args.output:
        args.output.write_text(json.dumps(results, indent=2) + '\n')
    passed = sum(result['result'] == 'PASS' for result in results)
    print(f'Formal evidence audit: {passed}/{len(results)} current tasks passed')
    return 0 if passed == len(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
