# IBM PC AT 5170

Milestone M4a: the board has the 80286, timer, DMA and page registers,
refresh logic, the 8042 keyboard controller running IBM's own firmware, the
MC146818 clock, two 8259A interrupt controllers, the math-coprocessor ports
and the shutdown-to-reset path. A second machine top adds an I/O channel and
an IBM Enhanced Graphics Adapter (EGA) in an expansion slot. The unchanged
IBM BIOS and the card's own BIOS run about 18.2 million instructions of the
power-on self-test: both interrupt controllers are set up, memory is tested
in protected mode, the processor is reset through the 8042 three times, and
seven timer interrupts are taken. The EGA BIOS's own self-test passes and
its display shows `00640 KB OK`, ` 301-Keyboard Error` and
` 601-Diskette Error`; both errors are correct, because no keyboard is
plugged in and no diskette adapter is modeled. The run stops at POST
checkpoint 3Ch on the BIOS's first read of port 1F7h, the fixed-disk status
register; no fixed-disk adapter is fitted. The board alone, without a
card, stops at the same read. Nothing boots.

The IBM Personal Computer AT (model 5170) was IBM's first 80286 machine. It
added a 16-bit expansion bus, 24-bit addressing (16 MB), a second interrupt
controller and DMA controller, an 8042 keyboard controller and a
battery-backed MC146818 clock with CMOS setup memory. These became the
"AT-compatible" base that later PCs followed. IBM's
[personal computer history](https://www.ibm.com/history/personal-computer)
dates it to August 1984; the exact day is not yet confirmed from an IBM
source. IBM's announcement letter for the EGA is dated 10 September 1984; see the
[EGA design](../../design/ibm_ega/) for sources.

This system runs the unchanged IBM AT REV1 BIOS (1984-01-10) on the
repository's [`intel_80286`](../../design/intel_80286/) RTL. The goal is to
boot PC DOS and then Microsoft OS/2 1.0.

Important chips: Intel 80286, 8254 timer, two 8259A interrupt controllers,
two 8237A DMA controllers (register interface), 74LS612 page registers,
8042 keyboard controller with IBM firmware 1503033, Motorola MC146818 clock
and the IBM EGA (five custom LSI devices, 256 KB display memory, IBM ROM
6277356) in the machine with a display.

## Web interface and waveform

There is no web interface and no waveform capture yet, so no panel or
waveform screenshot is available. The only host is the POST runner.

The image below is not a panel. It is the last video frame of the EGA
machine at the stop point (POST checkpoint 3Ch), captured in simulation
from the card's monitor connector (active area only, 640 x 350) and
written by `scripts/run_post_ega.sh` as `work/post_ega/frame.png`:

![Last video frame of the IBM PC AT 5170 with an EGA at POST checkpoint 3Ch](assets/post-ega-frame.png)

Reproduce it with `sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"`
(see Run). The three rows of text are checked by the script against the
ROM's own font; the frame is one picture, not a recording.

## Run

From the repository root, inside the `ai-hw-engineer` tool image:

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"
```

`get_bios.sh` downloads the BIOS from the pinned PCjs archive into the
ignored `work/` folder and checks its SHA-256. The 8042 firmware (IBM part
1503033) is rebuilt and hash-checked by the 8042 design's script, also into
`work/`. `run_all.sh` lints the board, runs the BIOS in two clock
scenarios, checks the stop point in `scripts/expected_stop.txt`, compares
every 80286 instruction with Unicorn, checks the 8042 and the MC146818
against their reference models, and synthesizes the board and the EGA
machine with Yosys. The two scenarios take about 20 minutes of simulation
and their Unicorn replays about 20 minutes each; `run_post.sh` takes about
54 minutes and synthesis about 12 more.

`run_post_ega.sh` needs only the path of the AT BIOS. It fetches the EGA
ROM (IBM 6277356) with `design/ibm_ega/scripts/get_rom.py`, which checks its
hashes and writes it to the ignored `work/` folder. It runs the EGA machine
in one scenario, checks the stop point in `scripts/expected_stop_ega.txt`,
checks the screen text in `tb/expected_screen_ega.txt`, replays the 8042
and the MC146818 into their models and compares every 80286 instruction
with Unicorn. It takes about 15 minutes of simulation and checks plus about
20 minutes for the Unicorn replay, and writes `work/post_ega/frame.png`.
`run_all.sh` does not run it.

## Verification and boundaries

The board answers an I/O read only from modeled devices. On the bare board
the run stops at the first unmodeled I/O read, and at an instruction fetch
from memory that is not fitted. Two cases have no effect on a real bus and
are accepted: a write to an empty expansion-slot address, and a write to
memory that is not fitted; a data read from unfitted memory returns FFh
(assumption AT14). Current stop on the bare board: `F000:1453`, a read of
port 1F7h (fixed-disk status) at POST checkpoint 3Ch. In the EGA machine
the channel and the card answer video memory and the card's ports, and the
run ends after the same read, at `F000:1454`.

Every 80286 instruction of all three runs (two bare-board scenarios and the
EGA machine) matches Unicorn, in the system BIOS and, for the EGA machine,
in the EGA BIOS. The 8042 and the MC146818 match their reference models in
all three. The display is checked as the text of one frame against the
ROM's own font. The board synthesizes to 86,864 generic cells and the EGA
machine to 94,169 (the card's plane RAMs and ROM are black boxes).

Limits:

- No keyboard device, diskette adapter, fixed-disk adapter or 80287; NMI is
  not connected; only the timer interrupt (IRQ 0) has been taken, and the
  8259s are checked only by the BIOS's own tests and by the vectors and
  in-service values seen.
- Channel timing is not the real board's (AT18). The video and processor
  clocks have a virtual ratio: the 8042 and the MC146818 run four times
  fast relative to video (AT19).
- The EGA machine is checked in one scenario, with no added wait states.
- 200-line modes on the card's direct-drive connector are not converted;
  frame colors assume the 350-line 64-colour interpretation.
- Unicorn does not check segment limits on accesses that do not fault.
- No whole-machine comparison with an independent emulator.
- Exploratory, not part of the regression: a longer EGA run
  (3,000,000,000 processor clocks) reaches POST checkpoint 3Fh, where the
  screen also shows `(RESUME = "F1" KEY)` and the BIOS waits for the F1
  key; the bare board with readable empty slots also reaches 3Fh.

The next milestone, M4b, is the VGA card, keyboard input and diskette, and
a complete POST; see the [implementation plan](plans/implementation_plan.md).
Tracking issue: https://github.com/hevangel/ai_hw_engineer/issues/254.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [M1 report](report/2026-11-13-m1-board-skeleton.md)
- [M2 report](report/2026-11-14-m2-8042-and-rtc.md)
- [M3 report](report/2026-11-15-m3-interrupts-and-protected-mode.md)
- [M4a report](report/2026-11-16-m4a-io-channel-and-ega.md)
- [Verification report](report/final_report.md)
