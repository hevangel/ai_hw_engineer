# Apple IIe IOU (341-0267)

The Apple IIe's Input/Output Unit is the custom chip that *is* the video
machine: the scanner counters that walk all 262 scan lines, the fold logic
that maps scan position to the interleaved display memory, the video-mode
soft switches (TEXT, MIXED, PAGE2, HIRES, annunciators, ALTCHAR, 80COL), the
keyboard strobe/any-key-down switches with the auto-repeat timer, and the
speaker, cassette-out and annunciator outputs. It shares the multiplexed
RA0-RA7 DRAM address bus with the MMU — the MMU drives it for the CPU during
PHI_0, the IOU drives it for the display during PHI_1 — and, in the IIe's
most elegant trick, it latches the CPU address *off that same bus* during the
CPU phase, which is how a 40-pin package decodes `$C000-$C07F` with a single
dedicated address pin (A6).

First introduced: **January 1983**, with the Apple IIe itself
([Wikipedia](https://en.wikipedia.org/wiki/Apple_IIe),
[Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe));
the exact introduction day is not asserted. The IOU (Apple part 341-0267) and
its sibling MMU (341-0266) are Synertek-manufactured full-custom DIP-40 parts.

**Verified functional reconstruction.** Lint, formal (bmc depth 32, unbounded
prove, non-vacuous cover), Verilator and xezim simulation against an
independent reference model — including a full-frame scan validating every
display address against the ground-truth sequences of the reference
testbenches — plus code coverage and Yosys synthesis all pass; see the
[validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report](report/final_report.md)
- [Coverage report](report/coverage_report.md)
- [Source manifest](references/README.md)

Primary source: the [Apple IIe Technical Reference Manual, 2nd ed., © 1985](https://archive.org/details/Apple_IIe_Technical_Reference_Manual)
(Chapter 2 soft switches and keyboard, Chapter 7 custom ICs: pinouts
Table 7-7, RAM address multiplexing Table 7-9, the Σ-fold display address
mapping Tables 7-11/7-12/7-13), cross-checked against the schematic-derived,
hardware-validated CC0 [frozen-signal reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU)
whose unit testbenches pin the exact text/hi-res address sequences (citing
Sather, *Understanding the Apple IIe*, pp. 5-9, 5-15..5-18). Run
`sh design/apple_iie_iou/scripts/run_all.sh` inside `ai-hw-engineer:latest`.

The PAL (RAS'/CAS' timing) is the remaining IIe custom-adjacent part and a
candidate for its own design; this IOU is specified so a future
`system/apple_iie` build can wire it to the [MMU](../apple_iie_mmu/README.md),
the existing `mos_6502` core and the Apple II board inventory.
