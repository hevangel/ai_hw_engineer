"""State the datasheet reading convention in the board README."""
from pathlib import Path

p = Path("system/apple_ii/board/README.md")
t = p.read_text()

old = """`timing.json` records a per-part propagation delay for every package model,
with the datasheet, document number and page that publish it. A module's
`T_PD` parameter delays each package output; internal state still follows the
documented clock edge.
"""
new = """`timing.json` records a per-part propagation delay for every package model,
with the datasheet, document number and page that publish it. Each entry takes
the worst published TYP/MAX pair from a single switching-table row at
VCC = 5 V, CL = 15 pF, TA = 25 °C, choosing the row with the largest maximum;
parts that publish only min/max use the maximum for the typical run. A module's
`T_PD` parameter delays each package output; internal state still follows the
documented clock edge.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
