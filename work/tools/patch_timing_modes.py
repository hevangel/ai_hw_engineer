"""Add explicit legacy/zero timing modes to generate_rev0.py (CRLF file)."""
from pathlib import Path

path = Path("system/apple_ii/scripts/generate_rev0.py")
text = path.read_text()

old = """    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
    delays = {}
    for part, entry in table['parts'].items():"""
new = """    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
    # 'legacy' keeps the original uniform 5 ns placeholder; 'zero' removes the
    # output delay entirely. Both exist to separate timing changes from logic
    # changes while the directed testbenches are retimed.
    uniform = {'legacy': 5, 'zero': 0}.get(mode)
    delays = {}
    for part, entry in table['parts'].items():"""
assert text.count(old) == 1
text = text.replace(old, new)

old = """        if key is None:
            delays[part] = 0
            continue"""
new = """        if key is None:
            delays[part] = uniform
            continue"""
assert text.count(old) == 1
text = text.replace(old, new)

old = """    parser.add_argument('--timing',choices=['typ','max','zero'],default='typ',"""
new = """    parser.add_argument('--timing',choices=['legacy','zero','typ','max'],default='legacy',"""
assert text.count(old) == 1
text = text.replace(old, new)

path.write_text(text, newline="\r\n")
print("patched timing modes")
