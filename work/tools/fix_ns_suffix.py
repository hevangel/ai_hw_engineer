from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()
old = "parameters=f' #(.T_PD({tpd}))'"
new = "parameters=f' #(.T_PD({tpd}ns))'"
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
