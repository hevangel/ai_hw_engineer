"""Tighten the measured wording in the timing section."""
from pathlib import Path

p = Path("system/apple_ii/report/final_report.md")
t = p.read_text()

old = """| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: sample point precedes a 25 ns clock-to-Q |
| datasheet maximum | fail, readback X | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture starts one sample late |"""
new = """| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: sync mismatch at line 0 sample 0 |
| datasheet maximum | fail, readback X | pass, 64,394 instructions, 4,516 unresolved reads | rejected: scan state 25/256 at line 0 sample 0 |"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """1. `tb/tb_rev0_wiring.sv` changes address and data exactly at the phi0 rising
   edge and samples with fixed 300 ns and 470 ns waits: a zero-setup,
   zero-delay stimulus. Presenting address and data during the previous phase,
   as a 6502 does, is required before its maximum-delay result means anything."""
new = """1. `tb/tb_rev0_wiring.sv` changes address and data exactly at the phi0 rising
   edge and samples with fixed 300 ns and 470 ns waits: a zero-setup,
   zero-delay stimulus. That is one candidate cause of the maximum-delay
   readback failure, which has not been reduced to a specific model error.
   Presenting address and data during the previous phase, as a 6502 does, is
   required before the result means anything about the board."""
assert t.count(old) == 1
t = t.replace(old, new)

old = """2. `tb/tb_rev0_boot.sv` samples the pixel and scan counters 10 ns after the
   pixel flip-flop clock. That window is shorter than the 25 ns typical
   clock-to-Q of a 74LS74, so the captured frame is offset; the pixel-exact
   comparison therefore remains valid only for the legacy model."""
new = """2. `tb/tb_rev0_boot.sv` samples the pixel and scan counters 10 ns after the
   pixel flip-flop clock, which is shorter than the 25 ns typical clock-to-Q of
   a 74LS74. The captured frame is therefore offset by one sample at typical
   and maximum delays, and the pixel-exact comparison remains valid only for the
   legacy model until the capture is retimed."""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
