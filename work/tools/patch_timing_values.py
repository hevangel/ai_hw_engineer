"""Handle fractional and missing typical delays from the datasheets."""
from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()

old = """import argparse
import json
from pathlib import Path
"""
new = """import argparse
import json
import math
from pathlib import Path
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """def load_timing(mode):
    \"\"\"Return the per-part propagation delay for every modelled package.

    Delays come from board/timing.json, whose entries cite manufacturer
    datasheets. Missing data is an error rather than a silent default: an
    unknown part must not quietly inherit another part's timing.
    \"\"\"
"""
new = """def load_timing(mode):
    \"\"\"Return (delays, notes) for every modelled package.

    Delays come from board/timing.json, whose entries cite manufacturer
    datasheets. Missing data is an error rather than a silent default: an
    unknown part must not quietly inherit another part's timing. A published
    fractional value is rounded up to the integer the models accept, and a part
    with no published typical value falls back to its maximum; both cases are
    recorded in the generated metadata.
    \"\"\"
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """    delays = {}
    for part, entry in table['parts'].items():"""
new = """    delays = {}
    notes = {'typ_from_max': [], 'rounded_up_ns': {}}
    for part, entry in table['parts'].items():"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays
"""
new = """        value = entry.get(key)
        if value is None and key == 'typ_ns':
            value = entry.get('max_ns')
            notes['typ_from_max'].append(part)
        if isinstance(value, float) and not value.is_integer():
            notes['rounded_up_ns'][part] = [value, math.ceil(value)]
            value = math.ceil(value)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays, notes
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """    delays = load_timing(timing_mode)"""
new = """    delays, timing_notes = load_timing(timing_mode)"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """        timing=dict(mode=timing_mode,units='ns',table='board/timing.json',
            part_delays={p:delays[p] for p in sorted({c['part'] for c in components.values() if c['part'] in models})}),"""
new = """        timing=dict(mode=timing_mode,units='ns',table='board/timing.json',
            **timing_notes,
            part_delays={p:delays[p] for p in sorted({c['part'] for c in components.values() if c['part'] in models})}),"""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
