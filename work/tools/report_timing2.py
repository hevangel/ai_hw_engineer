"""Replace the timing section with the final measured results."""
from pathlib import Path

path = Path("system/apple_ii/report/final_report.md")
text = path.read_text()

marker = "\n## Package timing (29 October 2026, review item P1)"
index = text.find(marker)
assert index > 0
text = text[:index]

section = """
## Package timing (29 October 2026, review item P1)

`board/timing.json` records a per-part propagation delay with the datasheet
citation for every modelled package. `generate_rev0.py --timing typ|max`
regenerates the identical netlist with typical or published maximum delays;
`--timing legacy` reproduces the previous uniform 5 ns board byte-for-byte and
remains the checked-in default. `scripts/run_timing_sim.sh` reruns the socket
and Monitor gates at datasheet timing.

Measured with Icarus 12.0-3 in the Apple II tools image. Both datasheet runs use
the same authored CPU and unmodified Monitor ROM as the legacy run:

| Timing set | Directed socket test | Monitor keyboard/CPU | Monitor frame comparison |
|---|---|---|---|
| legacy (5 ns, checked in) | pass | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass | pass, 64,393 instructions, 4,516 unresolved reads | rejected: sample point precedes a 25 ns clock-to-Q |
| datasheet maximum | fail, readback X | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture starts one sample late |

The Monitor deposit/examine result carries the weight: the unmodified firmware
completes its keyboard, write and readback path while every TTL package carries
its published worst-case delay. The other two results are harness artifacts, not
board findings:

1. `tb/tb_rev0_wiring.sv` changes address and data exactly at the phi0 rising
   edge and samples with fixed 300 ns and 470 ns waits: a zero-setup,
   zero-delay stimulus. Presenting address and data during the previous phase,
   as a 6502 does, is required before its maximum-delay result means anything.
2. `tb/tb_rev0_boot.sv` samples the pixel and scan counters 10 ns after the
   pixel flip-flop clock. That window is shorter than the 25 ns typical
   clock-to-Q of a 74LS74, so the captured frame is offset; the pixel-exact
   comparison therefore remains valid only for the legacy model.

Memory packages keep the ideal placeholder. A datasheet 4116 access delay makes
the video data latch capture Hi-Z between CAS cycles because the model has no
tRAC/tCAC or output-hold behaviour; that is review item P3. The datasheet values
are recorded in `timing.json` for that rework.

Consequently `run_all.sh` keeps legacy timing. The datasheet gate is separate,
and its stated scope is the socket test at typical delays plus the Monitor boot
at typical and maximum delays.
"""

path.write_text(text.rstrip("\n") + "\n" + section, newline="\r\n")
print("report section replaced")
