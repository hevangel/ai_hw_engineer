#!/usr/bin/env python3
"""Fail fast when a mutation suite's source pattern drifts from the RTL.

Each listed suite patches its target file only when the pattern occurs
exactly once; otherwise the suite aborts before testing anything. This
cheap textual check catches that drift without building any mutant. It
does not show that a mutant is still semantically meaningful or detected.
"""
import importlib
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
SOURCE_DIR = SCRIPT_DIR.parent / 'src'
CORE = 'intel_80286.sv'

# suite module -> function returning (name, target file, pattern) per entry
SUITES = {
    'run_mutations': lambda entry: (entry[0], entry[1], entry[2]),
    'run_irq_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_debug_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_reference_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_cache_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_system_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_undefined_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_protection_mutations': lambda entry: (entry[0], CORE, entry[1]),
    'run_protected_event_mutations': lambda entry: (entry[0], CORE, entry[1]),
}


def inspect(source_dir=SOURCE_DIR):
    if str(SCRIPT_DIR) not in sys.path:
        sys.path.insert(0, str(SCRIPT_DIR))
    errors = []
    checked = 0
    cache = {}
    for module_name, unpack in SUITES.items():
        module = importlib.import_module(module_name)
        for entry in module.MUTATIONS:
            name, target, pattern = unpack(entry)
            if target not in cache:
                cache[target] = (source_dir / target).read_text()
            matches = cache[target].count(pattern)
            checked += 1
            if matches != 1:
                errors.append(f'{module_name}.{name}: {matches} matches in {target}')
    return checked, errors


def main():
    checked, errors = inspect()
    for error in errors:
        print(f'FAIL: mutation pattern drift: {error}')
    if not errors:
        print(f'PASS: {checked} mutation patterns each match their target exactly once')
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
