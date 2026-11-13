# IBM PC AT 5170 verification report

Status: M1 board skeleton. The unchanged REV1 BIOS runs 30 instructions and
stops at `F000:00DE`, its first 8042 status read. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, two clock scenarios | `scripts/run_post.sh` | Both stop at `F000:00DE`, port 64h read |
| Unicorn replay | `scripts/run_post.sh` | 30 of 30 instructions match in each scenario |
| Synthesis | `scripts/run_synth.sh` | Pass, 76,442 generic cells, `check -assert` clean |

Details, the 8042 finding and limits:
[M1 report](2026-11-13-m1-board-skeleton.md).

The 286 design's own AT fixture reaches `F000:03A2` (about 247,000
instructions) because unknown ports read as zero there; that is fixture
evidence for the CPU, not for this board.
