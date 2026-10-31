"""Append the dated package-timing evidence section to the system report."""
from pathlib import Path

path = Path("system/apple_ii/report/final_report.md")
text = path.read_text()

section = """
## Package timing (29 October 2026, review item P1)

`board/timing.json` now carries a per-part propagation delay with the datasheet
citation for every modelled package. `generate_rev0.py --timing typ|max`
regenerates the same connectivity with typical or published maximum delays;
`--timing legacy` reproduces the previous uniform 5 ns board byte-for-byte and
remains the default until the directed testbenches are retimed.
`sh scripts/run_timing_sim.sh` reruns the socket and historical Monitor gates at
datasheet timing.

Measured with Icarus 12.0-3 in the Apple II tools image:

| Timing set | Socket wiring | Monitor keyboard/CPU | Monitor frame |
|---|---|---|---|
| legacy (5 ns) | pass | pass, 64,393 instructions, 4,524 unresolved reads | pixel-exact |
| datasheet typical | pass | pass, 64,393 instructions, 4,516 unresolved reads | pixel-exact |
| datasheet maximum | fail: readback X | pass, 64,393 instructions, 4,516 unresolved reads | fail: sync mismatch at line 0 |

TTL delays alone reproduce the assembly conclusion; the memory placeholder was
held constant for these runs, because the 4116 output model has no row-access
or refresh timing.

Open work exposed by the maximum-delay run:

1. The directed socket test changes address and data exactly at the phi0 rising
   edge and samples with fixed 300 ns and 470 ns waits. That zero-setup
   stimulus and the fixed waits encode the old zero-delay phase relationship.
   The readback failure has not been reduced to a specific model error yet, so
   the maximum-delay socket result is not evidence about the real board.
2. Composite sync does not match the sampled h/v counters sample-for-sample
   when package delays reach 30 ns. The sync path is deeper than one packet of
   delay, so a delay-faithful video check needs a skew-aware comparison rather
   than the same-instant equality used by `check_video.py`.
3. A datasheet 4116 access delay makes the video data latch capture Hi-Z
   between CAS cycles. That is review item P3's subject: the DRAM model needs
   tRAC/tCAC and output-hold behaviour before its delay can be characterized.

For those reasons `run_all.sh` keeps `legacy` timing and the datasheet modes are
an explicit, separately reported gate rather than a silent default change.
"""

text = text.rstrip("\n") + "\n" + section
path.write_text(text, newline="\r\n")
print("report updated")
