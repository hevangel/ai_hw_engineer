"""Record the retimed socket harness and its measured margins."""
from pathlib import Path

BASE = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime')

report = BASE / 'system/apple_ii/report/final_report.md'
text = report.read_text()
start = text.index('## Package timing')
new = '''## Package timing (29 October 2026, review item P1)

`board/timing.json` carries a per-package propagation delay with the
manufacturer document and printed page that publish it. The TI literature
number is recorded only where the scan prints one; the remaining entries cite
the document URL and page, because an unprinted number is not a citation.
`generate_rev0.py --timing typ|max` regenerates the same connectivity from those
per-part delays and refuses to run when a characterized part has no source. The
typical and maximum boards differ only in `T_PD` values (checked by normalizing
the two outputs). `--timing legacy` reproduces the previous uniform 5 ns board
byte for byte and stays the checked-in default, because the video, cassette and
peripheral harnesses still encode zero-delay phase relationships.

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
| legacy (5 ns, checked in) | pass, data at +429 ns | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass, data at +469 ns | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture one sample out of phase |
| datasheet maximum | pass, data at +472 ns | pass, 64,394 instructions, 4,516 unresolved reads | not compared (see below) |

The socket harness now samples read data at the phi2 falling edge, where a 6502
latches it, and prints how long each bank took to drive the bus. Phi2 high lasts
488.9 ns, so the margin is 60 ns at legacy delays, 20 ns at typical and 17 ns at
maximum. The previous harness sampled at a fixed +470 ns: that point sat 1-3 ns
inside the window, so the maximum-delay readback failure it reported was a
timing coincidence in the harness, not a board finding. Address and data were
already presented during the previous phase, as a 6502 does.

One limit remains, and it is measured rather than assumed. At datasheet delays
`composite_sync` is produced after a deeper gate chain than the counter outputs
the oracle derives it from, so comparing the two at the same instant fails, and
no constant dot shift reconciles them: across shifts of -4 to +4 samples the
best agreement is 70% of the frame. A delay-faithful video check needs an
edge-time comparison rather than a per-dot sample, so the pixel-exact frame gate
stays on the legacy board.

Consequently `run_all.sh` keeps legacy timing, and `scripts/run_timing_sim.sh`
covers the socket test and the Monitor boot at typical and maximum delays. Its
summary line names the frame comparison as legacy-only rather than hiding it.
'''
report.write_text(text[:start] + new, newline='\r\n')

board = BASE / 'system/apple_ii/board/README.md'
t = board.read_text()
old = """default, because the directed testbenches encode zero-delay phase relationships
that have not all been retimed. `scripts/run_timing_sim.sh` runs the socket
wiring test and the unmodified Monitor boot at datasheet timing; measured
results and open harness work are in the
[verification report](../report/final_report.md)."""
new = """default, because the video, cassette and peripheral harnesses still encode
zero-delay phase relationships. `scripts/run_timing_sim.sh` runs the socket
wiring test and the unmodified Monitor boot at typical and maximum delays, and
prints how long each DRAM bank took to drive the bus; the pixel-exact frame
comparison stays on the legacy board, because the sync path is deeper than the
counter path it is compared against. Measured results and the remaining limit
are in the [verification report](../report/final_report.md)."""
assert t.count(old) == 1, t.count(old)
board.write_text(t.replace(old, new), newline='\r\n')
print('report and board README updated')
