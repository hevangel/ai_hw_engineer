"""Patch load_timing to support BOM aliases (8T97-AppleII -> 8T97)."""
from pathlib import Path

path = Path("system/apple_ii/scripts/generate_rev0.py")
text = path.read_text()

old = """    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
    delays = {}
    for part, entry in table['parts'].items():
        if key is None:
            delays[part] = 0
            continue
        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays
"""
new = """    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
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
            delays[part] = 0
            continue
        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f"timing.json: {part} has no integer {key} (mode {mode})")
        delays[part] = value
    return delays
"""
assert text.count(old) == 1
path.write_text(text.replace(old, new), newline="\r\n")
print("patched alias resolution")
