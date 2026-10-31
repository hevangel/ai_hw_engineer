"""Document the refresh instrument and its measured margin."""
from pathlib import Path

BASE = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime')

report = BASE / 'system/apple_ii/report/final_report.md'
text = report.read_text()
text += '''
## DRAM refresh (30 October 2026, review item P2)

The 4116 model retains data indefinitely, so the board's reliance on the video
scan for refresh was an assumption rather than a checked property.
`tb/apple_ii_refresh_check.sv` now watches the RAS/row-address bus — shared by
all eight banks — and records the gap between successive accesses to each row.
The boot gate asserts row coverage (a run that misses any of the 128 rows fails)
and reports the margin.

Measured with Icarus 12.0-3 in the Apple II tools image:

| Configuration | Rows refreshed | RAS accesses | Worst same-row gap | Gaps over 2 ms |
|---|---|---|---|---|
| authored Monitor boot, CPU running (183 ms) | 128/128 | 373,928 | 1.9668 ms | 0 |
| video scan only, CPU socket idle (40 ms) | 128/128 | 81,635 | 2.2215 ms | 48 |

The 4116 requires every row to be refreshed within 2 ms. With the CPU executing
the worst gap is 1.9668 ms, inside the limit. With the CPU idle the video scan
alone takes 2.2215 ms, 11% longer than the device allows, and the checker flags
48 violations in 40 ms; every row sits in the 1.85-2.22 ms band, so the overrun
is the sweep itself rather than a few slow rows.

The second row is a finding, not a pass: part of the board's refresh budget is
carried by CPU accesses, and the video-only path is marginally short. The real
machine works, so either the device tolerance is wider than the datasheet figure
at room temperature or the model's row addressing differs from silicon; that
question is left open rather than explained away. What changed is that the
margin is now measured, and a change that lengthens the sweep shows up
immediately.

`scripts/run_refresh_check.sh` runs the video-only configuration as a negative
control: it requires all 128 rows and at least one violation, so a checker stuck
at zero cannot pass the boot gate for the wrong reason.
'''
report.write_text(text, newline='\r\n')

spec = BASE / 'system/apple_ii/spec/spec.md'
t = spec.read_text()
old = """- ASSUMPTION: testbenches give the delayed netlist a static settle window
  before the oscillator starts. Delayed continuous assignments otherwise
  propagate X from the all-unknown time-zero state, which silicon does not have."""
new = """- ASSUMPTION: testbenches give the delayed netlist a static settle window
  before the oscillator starts. Delayed continuous assignments otherwise
  propagate X from the all-unknown time-zero state, which silicon does not have.
- ASSUMPTION: DRAM retention is ideal; the model has no decay. Refresh coverage
  is measured, not assumed: `tb/apple_ii_refresh_check.sv` records the gap
  between successive RAS accesses per row and the Monitor gate asserts all 128
  rows are refreshed. The measured margin and the video-only shortfall are in
  the [verification report](../report/final_report.md)."""
assert t.count(old) == 1
spec.write_text(t.replace(old, new), newline='\r\n')

model = BASE / 'design/apple_ii_chips/src/a2_4116.sv'
t = model.read_text()
old = "    // ASSUMPTION: ideal retention; no decay, power sequencing, or analog timing."
new = """    // ASSUMPTION: ideal retention; no decay, power sequencing, or analog timing.
    // Refresh coverage is measured by system/apple_ii/tb/apple_ii_refresh_check.sv,
    // which records the gap between successive RAS accesses to each row."""
assert t.count(old) == 1
model.write_text(t.replace(old, new), newline='\r\n')
print('refresh documented')
