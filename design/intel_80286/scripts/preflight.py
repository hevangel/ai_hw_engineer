#!/usr/bin/env python3
"""Fail early on interrupted writes and missing local regression dependencies.

The reviewed source inventory is a deletion guard, not a proof of elaborated
properties or their semantics. Formal completion and cover remain mandatory.
"""
import argparse
import json
from pathlib import Path
import re


def property_counts(source):
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
    return {kind: len(re.findall(r'\b' + kind + r'\s*\(', source))
            for kind in ('assert', 'assume', 'cover')}


def inspect(design):
    errors = []
    inventory_path = design / 'formal/property_inventory.json'
    try:
        inventory = json.loads(inventory_path.read_text())
        if not inventory:
            errors.append('empty property inventory')
        for relative, expected in inventory.items():
            path = design / relative
            if not path.is_file() or not path.read_text().strip():
                errors.append(f'missing/empty property source: {relative}')
            elif property_counts(path.read_text()) != expected:
                errors.append(f'property inventory changed; review required: {relative}')
    except (OSError, ValueError) as error:
        errors.append(f'property inventory: {error}')
    for script in sorted((design / 'scripts').glob('*.sh')):
        source = script.read_text()
        if not source.strip():
            errors.append(f'empty script: {script.name}')
        for name in re.findall(r'\$SCRIPT_DIR/([\w.-]+\.(?:py|sh))', source):
            target = script.parent / name
            if not target.is_file() or not target.read_text().strip():
                errors.append(f'{script.name}: missing/empty dependency {name}')
    configs = list((design / 'formal').glob('*.sby'))
    if not configs:
        errors.append('missing formal configurations')
    for config in configs:
        entries = config.read_text().split('[files]', 1)
        if len(entries) != 2:
            errors.append(f'missing source inventory: {config.name}')
            continue
        for entry in entries[1].splitlines():
            entry = entry.strip()
            if not entry or entry.startswith('#'):
                continue
            path = config.parent / entry
            if not path.is_file() or not path.read_text().strip():
                errors.append(f'{config.name}: missing/empty source {entry}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--design-dir', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = inspect(args.design_dir)
    for error in errors:
        print(f'FAIL: {error}')
    if not errors:
        print('PASS: regression dependencies and reviewed property source inventory')
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
