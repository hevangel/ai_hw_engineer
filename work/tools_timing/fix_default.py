from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-timing\system\apple_ii\scripts\generate_rev0.py')
t = p.read_text()
old = "def generate(timing_mode='typ'):"
new = "def generate(timing_mode='legacy'):"
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new), newline='\r\n')
print('default mode aligned with the CLI')
