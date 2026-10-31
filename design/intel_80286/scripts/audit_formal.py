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


def elaborated_core_properties(path):
    """Count CPU assertions/covers retained in the top module's Yosys JSON.

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

    counts = {'assert': 0, 'cover': 0}
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
                    flavor not in counts):
                continue
            source_file = source.split(':', 1)[0].replace('\\', '/').rsplit('/', 1)[-1]
            if source_file == CORE_PROPERTY_SOURCE:
                counts[flavor] += 1
    return counts


def audit(design, work, core_work=None):
    results = []
    configs = sorted((design / 'formal').glob('*.sby'))
    if not configs:
        raise ValueError('no formal configurations found')
    for source_config in configs:
        config = sections(source_config)
        expected_tasks = (['prove'] if source_config.stem == 'intel_80286_pdr'
                          else ['bmc', 'prove', 'cover'])
        if config.get('tasks') != expected_tasks:
            task_names = '/'.join(expected_tasks)
            raise ValueError(f'{source_config}: require {task_names} task inventory')
        for task in config['tasks']:
            task_root = core_work if core_work is not None and source_config.stem == 'intel_80286' else work
            run = task_root / f'{source_config.stem}_{task}'
            errors = []
            files = []
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
            for entry in expected.get('files', []):
                # Current configurations copy one relative source to its basename.
                # Reject aliases/globs/commands rather than silently skipping them.
                if any(char.isspace() for char in entry) or any(c in entry for c in '*?[]$'):
                    raise ValueError(f'{source_config}: unsupported file entry {entry}')
                original = source_config.parent / entry
                snapshot = run / 'src' / original.name
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
            has_core_property_source = (
                source_config.stem == CORE_MODULE and
                any(Path(entry).name == CORE_PROPERTY_SOURCE
                    for entry in expected.get('files', [])))
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
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--design-dir', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--work-dir', type=Path)
    parser.add_argument('--core-work-dir', type=Path,
                        help='Use a separate immutable core epoch; components still use --work-dir')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    results = audit(args.design_dir, args.work_dir or get_work_root(args.design_dir) / 'formal', args.core_work_dir)
    for result in results:
        inventory = result.get('core_properties')
        properties = (f" (core cells: {inventory['assert']} assertions, "
                      f"{inventory['cover']} covers)" if inventory is not None else '')
        print(f"{result['result']}: {result['task']}{properties}" +
              (': ' + '; '.join(result['errors']) if result['errors'] else ''))
    if args.output:
        args.output.write_text(json.dumps(results, indent=2) + '\n')
    passed = sum(result['result'] == 'PASS' for result in results)
    print(f'Formal evidence audit: {passed}/{len(results)} current tasks passed')
    return 0 if passed == len(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
