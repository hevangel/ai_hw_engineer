# IBM PC AT 5170

Specification only. No system RTL exists yet.

The IBM Personal Computer AT (model 5170) was IBM's first 80286 machine. It
added a 16-bit expansion bus, 24-bit addressing (16 MB), a second interrupt
controller and DMA controller, an 8042 keyboard controller and a
battery-backed MC146818 clock with CMOS setup memory. These became the
"AT-compatible" base that later PCs followed. IBM's
[personal computer history](https://www.ibm.com/history/personal-computer)
dates it to August 1984; the exact day is not yet confirmed from an IBM
source.

This system will run the unchanged IBM AT REV1 BIOS (1984-01-10) on the
repository's [`intel_80286`](../../design/intel_80286/) RTL, with the goal of
booting PC DOS and then Microsoft OS/2 1.0.

## Web interface and waveform

No screenshot is available because the web interface and waveform capture
have not been implemented.

## Run

No runnable system is available yet. The nearest runnable work is the 286
design's AT BIOS fixture, which reaches `F000:03A2` in the BIOS
([report](../../design/intel_80286/report/2026-10-29-at-bios-native-refresh.md)).

## Verification and boundaries

No system verification has been run. Missing parts include the 8042
keyboard controller, MC146818 CMOS, video, diskette and fixed-disk
controllers, and the board logic that joins them. Tracking issue:
https://github.com/hevangel/ai_hw_engineer/issues/254.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Verification report](report/final_report.md)
