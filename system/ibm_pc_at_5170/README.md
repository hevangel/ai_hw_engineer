# IBM PC AT 5170

Board skeleton (milestone M1). The unchanged IBM BIOS runs its first 30
instructions on this board and stops at its first read of the 8042 keyboard
controller, which is not built yet. Nothing boots.

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
ignored `work/` folder and checks its SHA-256. `run_all.sh` lints the board,
runs the BIOS in two clock scenarios, compares every instruction with
Unicorn, checks the stop point in `scripts/expected_stop.txt`, and
synthesizes the board with Yosys.

## Verification and boundaries

The board answers only from modeled devices; the run stops at the first
unmodeled I/O port or memory address. Current stop: `F000:00DE`, the BIOS's
cold-boot test of the 8042 system flag. The 286 design's own AT fixture runs
further (to `F000:03A2`) because unknown ports there read as zero. The next
milestone is the 8042; see the [implementation plan](plans/implementation_plan.md).
Tracking issue: https://github.com/hevangel/ai_hw_engineer/issues/254.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [M1 report](report/2026-11-13-m1-board-skeleton.md)
- [Verification report](report/final_report.md)
