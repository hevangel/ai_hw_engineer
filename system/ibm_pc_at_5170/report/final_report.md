# IBM PC AT 5170 verification report

Status: M3. The unchanged REV1 BIOS runs 16,688,169 instructions of its
power-on self-test (16,586,155 with bus wait states) and stops at
`F000:1453`, a read of port 1F7h (fixed-disk status) at POST checkpoint 3Ch.
No fixed-disk adapter is fitted. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, two clock scenarios | `scripts/run_post.sh` | Both stop at `F000:1453`, port 1F7h read, POST 3Ch; 3 CPU resets and 8 interrupt-acknowledge cycles (4 interrupts, vector 08h) in each |
| Unicorn replay | `scripts/run_post.sh` | Every instruction state and data transfer matches: 16,688,169 and 16,586,155 instructions, through protected mode, 4 hardware interrupts, 4 exceptions, 69 software interrupts and 3 resets; 13 of 13 BIOS checkpoints |
| 8042 against its reference model | `scripts/run_post.sh` | 7,777,553 and 10,543,228 8042 instructions; 1,648,422 and 1,637,225 CPU reads identical |
| MC146818 against its reference model | `scripts/run_post.sh` | 22,855 and 14,538 address strobes, 23 writes each; 22,830 and 14,513 CPU reads identical |
| Synthesis | `scripts/run_synth.sh` | Pass, 87,161 generic cells, `check -assert` clean; the only latch is the refresh arbiter's schematic latch |

Details, findings and limits:
[M3 report](2026-11-15-m3-interrupts-and-protected-mode.md). Earlier:
[M2 report](2026-11-14-m2-8042-and-rtc.md) and
[M1 report](2026-11-13-m1-board-skeleton.md).

Not yet modeled: video, diskette, fixed disk, the 80287 and a keyboard on
the connector. NMI is not connected. The 8259s are checked only by the
BIOS's own tests and by the vectors and in-service values seen. There is no
whole-machine comparison with an independent emulator yet.
