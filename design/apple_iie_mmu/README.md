# Apple IIe MMU (341-0266)

The Apple IIe's Memory Management Unit is the custom chip that decodes every
6502 bus cycle and decides what answers: motherboard RAM, auxiliary-slot RAM
or on-board ROM. It implements the machine's soft switches for auxiliary
memory (RAMRD, RAMWRT, 80STORE, ALTZP), the bank-switched language-card
window with its famous double-read write-enable dance, the $C100-$CFFF
internal/slot ROM selection, and the multiplexed RA0-RA7 DRAM address bus
shared with the video circuitry.

First introduced: **January 1983**, with the Apple IIe itself
([Wikipedia](https://en.wikipedia.org/wiki/Apple_IIe),
[Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe));
the exact introduction day is not asserted. The MMU (Apple part 341-0266) and
its sibling IOU (341-0267) are Synertek-manufactured full-custom DIP-40 parts
— Apple's move to custom silicon both integrated ~20 TTL packages and raised
the cloning barrier. The IIe became Apple's longest-lived computer, produced
until November 1993.

**Verified functional reconstruction.** Lint, formal (bmc/prove/cover,
non-vacuous), Verilator and xezim simulation against an independent
reference model, 100% statement/branch/toggle code coverage and Yosys
synthesis all pass — see the [validation report](report/final_report.md).

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report](report/final_report.md)
- [Coverage report](report/coverage_report.md)
- [Source manifest](references/README.md)

Primary source: the [Apple IIe Technical Reference Manual, 2nd ed., © 1985](https://archive.org/details/Apple_IIe_Technical_Reference_Manual)
(Chapter 4 memory organization, Chapter 6 I/O memory, Chapter 7 custom ICs,
Appendix I Monitor listing), cross-checked against AppleWin and the
schematic-derived CC0 [frozen-signal reimplementation](https://github.com/frozen-signal/Apple_IIe_MMU_IOU)
for details the manual does not state. Run
`sh design/apple_iie_mmu/scripts/run_all.sh` inside `ai-hw-engineer:latest`.

The IOU (video timing, annunciators, keyboard/paddle inputs) and the PAL
(RAS'/CAS' timing) are separate chips and candidates for their own designs;
the MMU here is specified so a future `system/apple_iie` build can wire it to
the existing `mos_6502` core and the Apple II board inventory.
