"""Require a datasheet citation for every characterized timing entry."""
from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()

old = '''        if key is None:
            delays[part] = legacy_overrides.get(part, uniform)
            continue
'''
new = '''        if key is None:
            delays[part] = legacy_overrides.get(part, uniform)
            continue
        # A characterized delay without a citation is a guess. Idealized
        # placeholders are exempt, but they must say so explicitly.
        if not entry.get('idealized') and not entry.get('source'):
            raise SystemExit(f"timing.json: {part} has {key} but no datasheet source")
'''
assert t.count(old) == 1
t = t.replace(old, new)
p.write_text(t, newline="\r\n")
print("ok")
