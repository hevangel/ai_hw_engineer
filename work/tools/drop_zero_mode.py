"""Drop the unusable zero-delay mode (zero-delay assigns loop in the netlist)."""
from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()

old = """    # 'legacy' keeps the original uniform 5 ns placeholder; 'zero' removes the
    # output delay entirely. Both exist to separate timing changes from logic
    # changes while the directed testbenches are retimed.
    uniform = {'legacy': 5, 'zero': 0}.get(mode)"""
new = """    # 'legacy' keeps the original uniform 5 ns placeholder so a timing change
    # can be separated from a logic change while testbenches are retimed.
    uniform = {'legacy': 5}.get(mode)"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """    parser.add_argument('--timing',choices=['legacy','zero','typ','max'],default='legacy',"""
new = """    parser.add_argument('--timing',choices=['legacy','typ','max'],default='legacy',"""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
