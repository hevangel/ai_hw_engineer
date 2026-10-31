"""Document per-part package timing (board README, spec ledger, system README)."""
from pathlib import Path

board = Path("system/apple_ii/board/README.md")
text = board.read_text()
anchor = """`apple_ii_rev0_peripherals.sv` models the three analog IC functions with real
voltage inputs and reduced RC networks. See [analog assumptions](../spec/analog.md).
The ideal oscillator remains a fidelity boundary. Q3/Q4 output networks now
have reduced numerical models with observable voltages and validity flags.
"""
addition = anchor + """
## Package timing

`timing.json` records a per-part propagation delay for every package model,
with the datasheet, document number and page that publish it. A module's
`T_PD` parameter delays each package output; internal state still follows the
documented clock edge.

`generate_rev0.py --timing typ|max` regenerates the identical netlist with
typical or maximum datasheet delays. `--timing legacy` keeps the original
uniform 5 ns placeholder and remains the checked-in default, because the
directed testbenches encode zero-delay phase relationships that have not all
been retimed. `scripts/run_timing_sim.sh` runs the socket wiring test and the
unmodified Monitor boot at datasheet timing; measured results and open harness
work are in the [verification report](../report/final_report.md).

The memory packages keep the legacy placeholder. The 4116 model has no row
access (tRAC) or refresh behaviour, so a datasheet access delay makes the video
data latch capture Hi-Z between CAS cycles. That belongs to review item P3, not
to the TTL delay table.
"""
assert text.count(anchor) == 1
board.write_text(text.replace(anchor, addition), newline="\r\n")

spec = Path("system/apple_ii/spec/spec.md")
text = spec.read_text()
old = """- ASSUMPTION: digital package delays are 5 ns and DRAM output delay is 20 ns
  for event ordering. These uniform values are not characterized timing data.
"""
new = """- ASSUMPTION: the checked-in board keeps the original uniform 5 ns package
  delay and 20 ns DRAM output delay for event ordering. `board/timing.json`
  records per-part typical and maximum datasheet propagation delays, selected
  with `generate_rev0.py --timing typ|max`; they stay opt-in until every
  directed testbench is retimed.
- ASSUMPTION: memory packages (4116, system ROM, 2513) keep that placeholder
  because the 4116 model has no row-access or refresh timing.
- ASSUMPTION: testbenches give the delayed netlist a static settle window
  before the oscillator starts. Delayed continuous assignments otherwise
  propagate X from the all-unknown time-zero state, which silicon does not have.
"""
assert text.count(old) == 1
spec.write_text(text.replace(old, new), newline="\r\n")

readme = Path("system/apple_ii/README.md")
text = readme.read_text()
old = """Individual regressions have separate passing scripts. The motherboard uses
Icarus; package tests use Xezim.
"""
new = """Individual regressions have separate passing scripts. The motherboard uses
Icarus; package tests use Xezim. `sh scripts/run_timing_sim.sh` repeats the
socket and Monitor gates with datasheet package delays; see
[package timing](board/README.md#package-timing) for what is and is not covered.
"""
assert text.count(old) == 1
readme.write_text(text.replace(old, new), newline="\r\n")
print("documented timing")
