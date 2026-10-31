"""Replace load_timing with an alias-resolving, citation-guarded version."""
from pathlib import Path

p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-timing\system\apple_ii\scripts\generate_rev0.py')
t = p.read_text()

old = '''def load_timing(mode):
    """Return the per-part propagation delay for every modelled package.

    Delays come from board/timing.json, whose entries cite manufacturer
    datasheets. Missing data is an error rather than a silent default: an
    unknown part must not quietly inherit another part's timing.
    """
    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
    # 'legacy' keeps the original uniform 5 ns placeholder; 'zero' removes the
    # output delay entirely. Both exist to separate timing changes from logic
    # changes while the directed testbenches are retimed.
    uniform = {'legacy': 5, 'zero': 0}.get(mode)
    # The 4116 carried a 20 ns placeholder in the original generated board.
    legacy_overrides = {'4116': 20} if mode == 'legacy' else {}
    delays = {}
    for part, entry in table['parts'].items():
        # A BOM alias such as 8T97-AppleII follows the base part's entry so one
        # datasheet value cannot drift between two spellings of the same device.
        seen = {part}
        while 'same_as' in entry:
            target = entry['same_as']
            if target in seen or target not in table['parts']:
                raise SystemExit(f"timing.json: bad alias {part} -> {target}")
            seen.add(target)
            entry = table['parts'][target]
        if key is None:
            delays[part] = legacy_overrides.get(part, uniform)
            continue
        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays
'''

new = '''LEGACY_UNIFORM_NS = 5
# The 4116 carried a 20 ns placeholder in the original generated board.
LEGACY_OVERRIDES_NS = {'4116': 20}


def resolve_entry(parts, part):
    """Follow same_as aliases so both spellings of a device share one row."""
    seen = {part}
    entry = parts[part]
    while 'same_as' in entry:
        target = entry['same_as']
        if target in seen or target not in parts:
            raise SystemExit(f"timing.json: bad alias {part} -> {target}")
        seen.add(target)
        entry = parts[target]
    return entry


def load_timing(mode):
    """Return the per-part propagation delay for every modelled package.

    'legacy' and 'zero' reproduce the earlier placeholder boards. 'typ' and
    'max' take each package's delay from board/timing.json, and an entry that
    is not idealized must name the datasheet that publishes it: a
    characterized number without a source is a guess.

    Idealized packages (the DRAM and ROM models) keep their legacy value in
    every mode. Those models have no access-time behaviour, so a datasheet
    access delay would describe hardware the model does not contain.
    """
    table = json.loads(TIMING_FILE.read_text())
    parts = table['parts']
    if mode in ('legacy', 'zero'):
        uniform = 0 if mode == 'zero' else LEGACY_UNIFORM_NS
        overrides = LEGACY_OVERRIDES_NS if mode == 'legacy' else {}
        return {p: overrides.get(p, uniform) for p in parts}
    key = {'typ': 'typ_ns', 'max': 'max_ns'}[mode]
    delays = {}
    for part in parts:
        entry = resolve_entry(parts, part)
        if entry.get('idealized'):
            delays[part] = LEGACY_OVERRIDES_NS.get(part, LEGACY_UNIFORM_NS)
            continue
        if not entry.get('source'):
            raise SystemExit(f"timing.json: {part} has {key} but no datasheet source")
        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays
'''

assert t.count(old) == 1, f"anchor count {t.count(old)}"
p.write_text(t.replace(old, new), newline='\r\n')
print("patched load_timing")
