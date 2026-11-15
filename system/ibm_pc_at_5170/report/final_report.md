# IBM PC AT 5170 verification report

Status: M2. The unchanged REV1 BIOS runs 1,125,813 instructions of its
power-on self-test, passes its own 8042 test and stops at `F000:068B`, a
write to port F1h (POST checkpoint 12h), the first hardware not on the
board. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, two clock scenarios | `scripts/run_post.sh` | Both stop at `F000:068B`, port F1h write, POST 12h |
| Unicorn replay | `scripts/run_post.sh` | 1,125,813 and 1,084,662 instructions; every state and data transfer matches |
| BIOS checkpoints | `scripts/run_post.sh` | 9 of 9, including the BIOS's 8042 test |
| 8042 against its reference model | `scripts/run_post.sh` | 559,555 and 737,730 8042 instructions; 39,267 and 28,966 CPU reads identical |
| Synthesis | `scripts/run_synth.sh` | Pass, 84,669 generic cells, `check -assert` clean; the only latch is the refresh arbiter's schematic latch |

Details, findings and limits:
[M2 report](2026-11-14-m2-8042-and-rtc.md). Earlier:
[M1 report](2026-11-13-m1-board-skeleton.md).

Not yet modeled: the math-coprocessor ports, both 8259s (so no interrupts),
video, diskette, fixed disk, and a keyboard on the connector. There is no
whole-machine comparison with an independent emulator yet.
