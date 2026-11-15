# IBM PC AT 5170

Milestone M3: the board has the 80286, timer, DMA and page registers,
refresh logic, the 8042 keyboard controller running IBM's own firmware, the
MC146818 clock, two 8259A interrupt controllers, the math-coprocessor ports
and the shutdown-to-reset path. The unchanged IBM BIOS runs about 16.7
million instructions of its power-on self-test: it sets up both interrupt
controllers, tests memory in protected mode, resets the processor through
the 8042 three times and takes four timer interrupts. It stops at POST
checkpoint 3Ch on a read of port 1F7h, the fixed-disk status register; no
fixed-disk adapter is fitted. Nothing boots.

The IBM Personal Computer AT (model 5170) was IBM's first 80286 machine. It
added a 16-bit expansion bus, 24-bit addressing (16 MB), a second interrupt
controller and DMA controller, an 8042 keyboard controller and a
battery-backed MC146818 clock with CMOS setup memory. These became the
"AT-compatible" base that later PCs followed. IBM's
[personal computer history](https://www.ibm.com/history/personal-computer)
dates it to August 1984; the exact day is not yet confirmed from an IBM
source.

This system runs the unchanged IBM AT REV1 BIOS (1984-01-10) on the
repository's [`intel_80286`](../../design/intel_80286/) RTL. The goal is to
boot PC DOS and then Microsoft OS/2 1.0.

## Web interface and waveform

No screenshot is available because the web interface and waveform capture
have not been implemented.

## Run

From the repository root, inside the `ai-hw-engineer` tool image:

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
```

`get_bios.sh` downloads the BIOS from the pinned PCjs archive into the
ignored `work/` folder and checks its SHA-256. The 8042 firmware (IBM part
1503033) is rebuilt and hash-checked by the 8042 design's script, also into
`work/`. `run_all.sh` lints the board, runs the BIOS in two clock
scenarios, checks the stop point in `scripts/expected_stop.txt`, compares
every 80286 instruction with Unicorn, checks the 8042 and the MC146818
against their reference models, and synthesizes the board with Yosys. The
two scenarios take about 20 minutes of simulation and their Unicorn
replays about 20 minutes each; `run_post.sh` takes about 54 minutes and
synthesis about 12 more.

## Verification and boundaries

The board answers an I/O read only from modeled devices; the run stops at
the first unmodeled I/O read, and at an instruction fetch from memory that
is not fitted. Two cases have no effect on a real bus and are accepted: a
write to an empty expansion-slot address, and a write to memory that is not
fitted; a data read from unfitted memory returns FFh (assumption AT14).
Current stop: `F000:1453`, a read of port 1F7h (fixed-disk status) at POST
checkpoint 3Ch. Video, diskette and fixed-disk adapters and the 80287 are
not fitted, the keyboard connector is empty (the BIOS's keyboard reset gets
FEh), NMI is not connected, and only IRQ 0 has been taken (IRQ 1 and IRQ 8
are connected but have not fired). The 8259s are checked only by the BIOS's
own tests and by the vectors and in-service values seen. Every 80286
instruction of both runs matches Unicorn, and the board synthesizes to
87,161 generic cells. The next milestone is video, keyboard input and
diskette, which must also settle what a read from an empty slot returns;
see the [implementation plan](plans/implementation_plan.md).
Tracking issue: https://github.com/hevangel/ai_hw_engineer/issues/254.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [M1 report](report/2026-11-13-m1-board-skeleton.md)
- [M2 report](report/2026-11-14-m2-8042-and-rtc.md)
- [M3 report](report/2026-11-15-m3-interrupts-and-protected-mode.md)
- [Verification report](report/final_report.md)
