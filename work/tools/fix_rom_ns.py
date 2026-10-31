from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()
pairs = [
    (".T_PD({tpd}), .ROM_FILE(ROM_{ref.split(\"-\")[-1]})", ".T_PD({tpd}ns), .ROM_FILE(ROM_{ref.split(\"-\")[-1]})"),
    (".T_PD({tpd}), .ROM_FILE(CHAR_ROM)", ".T_PD({tpd}ns), .ROM_FILE(CHAR_ROM)"),
]
for old, new in pairs:
    assert t.count(old) == 1, (old, t.count(old))
    t = t.replace(old, new)
p.write_text(t, newline="\r\n")
print("ok")
