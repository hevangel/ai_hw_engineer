"""Correct the measured instruction counts in the timing section."""
from pathlib import Path

p = Path("system/apple_ii/report/final_report.md")
t = p.read_text()
old = """| datasheet typical | pass | pass, 64,393 instructions, 4,516 unresolved reads | rejected: sample point precedes a 25 ns clock-to-Q |
| datasheet maximum | fail, readback X | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture starts one sample late |"""
new = """| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: sample point precedes a 25 ns clock-to-Q |
| datasheet maximum | fail, readback X | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture starts one sample late |"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
