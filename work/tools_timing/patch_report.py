"""Rewrite the Package timing report section from the measured 29 Oct 2026 runs."""
from pathlib import Path

P = Path(r'B:\ai_hw_engineer\worktree\apple-ii-timing\system\apple_ii\report\final_report.md')
text = P.read_text()
marker = '## Package timing'
start = text.index(marker)

new = '''## Package timing (29 October 2026, review item P1)

`board/timing.json` carries a per-package propagation delay with the
manufacturer document and printed page that publish it. The TI literature
number is recorded only where the scan prints one; the remaining entries cite
the document URL and page, because an unprinted number is not a citation.
`generate_rev0.py --timing typ|max` regenerates the same connectivity from those
per-part delays and refuses to run when a characterized part has no source. The
typical and maximum boards differ only in `T_PD` values (checked by normalizing
the two outputs). `--timing legacy` reproduces the previous uniform 5 ns board
byte for byte and stays the checked-in default, because the directed
testbenches still encode zero-delay phase relationships.

Two entries are bounds rather than board-load numbers. The 8T97 datasheet is
specified at CL = 50 pF, so its 13 ns maximum is conservative at the board's
15 pF, and no Signetics 8T28 delay was readable, so the AMD second-source 17 ns
maximum is used for both directions. The table carries both caveats.

The memory packages are marked `idealized` and keep the legacy output delay in
every mode: 20 ns for the 4116, 5 ns for the system ROM and 2513. A datasheet
4116 access delay makes the video data latch capture Hi-Z between CAS cycles,
because the model has no tRAC/tCAC or output-hold behaviour. That is review item
P3, not a TTL delay question.

Measured with Icarus 12.0-3 in the Apple II tools image, with the same authored
CPU and unmodified Monitor ROM in every row:

| Timing set | Directed socket test | Monitor keyboard/CPU | Monitor frame comparison |
|---|---|---|---|
| legacy (5 ns, checked in) | pass | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass | pass, 64,394 instructions, 4,516 unresolved reads | rejected: line 0 sample 0, scan state 25/256 where the oracle has 24/256 |
| datasheet maximum | fail: RAM row 0 read xx at 25.213729 ms | pass, 64,394 instructions, 4,516 unresolved reads | not compared by `run_timing_sim.sh`; the capture offset below applies to any non-zero delay |

The Monitor deposit/examine result carries the weight: the unmodified firmware
completes its keyboard, write and readback path while every characterized
package carries its published worst-case delay, and the instruction count moves
by one against the legacy run. The two remaining failures are harness limits,
not board findings:

1. `tb/tb_rev0_wiring.sv` changes address and data exactly at the phi0 rising
   edge and samples after fixed 300 ns and 470 ns waits: a zero-setup,
   zero-delay stimulus. It passes at typical delays and fails at maximum with
   `RAM row 0 read xx`. Presenting address and data during the previous phase,
   as a 6502 does, is required before that maximum-delay result says anything
   about the board; it has not been reduced to a specific model error.
2. `tb/tb_rev0_boot.sv` samples the pixel and scan counters 10 ns after the
   pixel flip-flop clock. That window is shorter than the 25 ns typical
   clock-to-Q of a 74LS74, so at any non-zero package delay the captured frame
   is one sample out of phase (the typical run reports scan state 25/256 where
   the oracle has 24/256). The pixel-exact comparison therefore holds only for
   the legacy model until the capture is retimed.

Consequently `run_all.sh` keeps legacy timing, and the datasheet gate is a
separate, explicitly scoped run: `sh scripts/run_timing_sim.sh` covers the
socket test at typical delays and the Monitor boot at typical and maximum
delays. Its own summary line states the two open comparisons rather than
hiding them behind a weaker check.
'''

P.write_text(text[:start] + new, newline='\r\n')
print('report section replaced')
