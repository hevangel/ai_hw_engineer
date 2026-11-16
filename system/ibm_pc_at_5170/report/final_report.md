# IBM PC AT 5170 verification report

Status: M4a. The unchanged REV1 BIOS runs 16,688,169 instructions of its
power-on self-test (16,586,155 with bus wait states) on the bare board and
stops at `F000:1453`, a read of port 1F7h (fixed-disk status) at POST
checkpoint 3Ch. With an I/O channel and an IBM EGA in a slot, it and the
card's BIOS run 18,201,512 instructions to the same point and the display
shows the BIOS's memory count and its two error lines. No fixed-disk
adapter is fitted. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, two clock scenarios | `scripts/run_post.sh` | Both stop at `F000:1453`, port 1F7h read, POST 3Ch; 3 CPU resets and 8 interrupt-acknowledge cycles (4 interrupts, vector 08h) in each |
| Unicorn replay | `scripts/run_post.sh` | Every instruction state and data transfer matches: 16,688,169 and 16,586,155 instructions, through protected mode, 4 hardware interrupts, 4 exceptions, 69 software interrupts and 3 resets; 13 of 13 BIOS checkpoints |
| 8042 against its reference model | `scripts/run_post.sh` | 7,777,553 and 10,543,228 8042 instructions; 1,648,422 and 1,637,225 CPU reads identical |
| MC146818 against its reference model | `scripts/run_post.sh` | 22,855 and 14,538 address strobes, 23 writes each; 22,830 and 14,513 CPU reads identical |
| Synthesis, board | `scripts/run_synth.sh` | Pass, 86,864 generic cells, `check -assert` clean; the only latch is the refresh arbiter's schematic latch |
| EGA machine: lint | `scripts/run_post_ega.sh` (first step) | Clean, `verilator --lint-only -Wall` on `ibm_pc_at_5170_ega` |
| EGA machine: stop point | `scripts/run_post_ega.sh` | `kind=stop-at after=F1453 at=F000:1454 post=3C`; 18,201,512 instructions, 279,013,645 processor clocks, 3 CPU resets, 14 interrupt-acknowledge cycles (7 timer interrupts), 1,321 channel I/O writes, 4 unanswered channel I/O reads, 1,270,314 channel memory writes, 648 video frames |
| EGA machine: screen | `scripts/run_post_ega.sh` (`scripts/check_frame.py`) | The last frame, 640 x 350, decodes with the ROM's own 8 x 14 font to `00640 KB OK`, ` 301-Keyboard Error`, ` 601-Diskette Error` |
| EGA machine: 8042 | `scripts/run_post_ega.sh` | 9,987,012 instructions, 19 host writes, 6 data reads, 1,648,622 CPU read values identical |
| EGA machine: MC146818 | `scripts/run_post_ega.sh` | 64,931 address strobes, 23 writes, 64,906 CPU read values identical; 46.5 s of clock time |
| EGA machine: Unicorn replay | `scripts/run_post_ega.sh` | 18,201,512 instruction states and data transfers match, in the system BIOS and in the EGA BIOS; 7 hardware interrupts, 146 software interrupts, 3 resets, 4 exceptions; 13 of 13 BIOS checkpoints |
| Synthesis, EGA machine | `scripts/run_synth.sh` | Pass, `ibm_pc_at_5170_ega` 94,169 generic cells with the card's plane RAMs and ROM as black boxes (new in M4a); `check -assert` clean; the only latch is the refresh arbiter's schematic latch |

The EGA machine is checked in one scenario (no added wait states).
`run_post_ega.sh` takes about 35 minutes (15 of simulation and screen and
device checks, 20 for the Unicorn replay); `run_all.sh` does not run it.

Details, findings and limits:
[M4a report](2026-11-16-m4a-io-channel-and-ega.md). Earlier:
[M3 report](2026-11-15-m3-interrupts-and-protected-mode.md),
[M2 report](2026-11-14-m2-8042-and-rtc.md) and
[M1 report](2026-11-13-m1-board-skeleton.md).

Exploratory, not part of the regression: a longer run of the EGA machine
(3,000,000,000 processor clocks, 212,970,955 instructions) reaches POST
checkpoint 3Fh and waits at `(RESUME = "F1" KEY)`; the bare board with
readable empty slots (`--empty-slots`) also reaches checkpoint 3Fh.

Not yet modeled: a keyboard on the connector, diskette, fixed disk, the
80287 and VGA. NMI is not connected. Channel timing is not the real
board's (AT18) and the video and processor clocks keep a virtual ratio
(AT19). The 8259s are checked only by the BIOS's own tests and by the
vectors and in-service values seen. The display is checked as text of one
frame. 200-line modes are not converted. There is no whole-machine
comparison with an independent emulator yet.
