# Apple IIe PAL (PAL16R8 timing generator)

The least visible of the IIe's three custom-programmed parts: a PAL16R8
programmed by Apple that turns the 14.31818 MHz master oscillator into every
other heartbeat on the board — the 65C02 clocks (φ0/φ1 at 1.0227 MHz), the
asymmetric Q3 strobe (2.045 MHz, the "alternate column-address strobe" the
DRAM cycle alternates between), the RAM row/column strobes (PRAS'/PCAS'),
and the video shift-register controls (LDPS', the 7 MHz dot-clock VID7M).
The IOU's soft-switch decoder is gated by Q3, the MMU's CASEN' path feeds
the PAL's RAMEN' ("CAS enable") input, and the MMU/IOU "row while PRAS' is
high, column after Q3 falls" address convention is this chip's timing made
visible.

First introduced: **January 1983**, with the Apple IIe itself
([Wikipedia](https://en.wikipedia.org/wiki/Apple_IIe),
[Centre for Computing History](https://www.computinghistory.org.uk/det/209/Apple-IIe));
the exact introduction day is not asserted.

**Verified functional reconstruction.** Lint, formal (bmc depth 32,
unbounded prove, non-vacuous cover), Verilator and xezim simulation against
an independent truth-table reference model, code coverage and Yosys
synthesis all pass — see the [validation report](report/final_report.md).

**Reconstruction level.** This design is rebuilt at the **14M-tick level**
(one clock edge = one 14M period), one domain finer than the cycle-level
MMU and IOU designs, because the PAL's outputs *are* the tick structure
(14-tick CPU cycle, 7-tick Q3 period — the TRM's 280 ns + 210 ns = 490 ns
phase decomposition). The φ0/φ1/Q3/PRAS'/PCAS'/ENTMG/RAMEN' behavior is
TRM-pinned; **the LDPS' pulse positions and the PAL's mode-dependent
VID7M gating are not**: Sather's *Understanding the Apple IIe* documents
the fuse-level equations, but the book is under copyright and no citable
public transcription exists, so those outputs are reconstructed at
cadence level only (1 vs 2 pulses per cycle, 7 MHz dot-clock rate) with
the exact gating declared out of scope — assumption ledger A4/A5 in the
[specification](spec/spec.md). The pins whose only role is inside that
unreconstructed gating (3.58M, H0, VID7, SEGB, GR) are documented but not
ports, following the same convention as the MMU design's removed Q3 pin.

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Validation report](report/final_report.md)
- [Coverage report](report/coverage_report.md)
- [Source manifest](references/README.md)

Primary source: the [Apple IIe Technical Reference Manual, 2nd ed., © 1985](https://archive.org/details/Apple_IIe_Technical_Reference_Manual)
(Table 7-5 65C02 timing signals, Table 7-8 PAL pinouts and signal
descriptions, Table 7-10 RAM timing signals, Figure 7-1 phase
decomposition, and the Chapter 2/7 LDPS' cadence text), with Sather's
*Understanding the Apple IIe* cited for the LDPS'/VID7M input-dependence
statement. Run `sh design/apple_iie_pal/scripts/run_all.sh` inside
`ai-hw-engineer:latest`.

With the [MMU](../apple_iie_mmu/README.md) and [IOU](../apple_iie_iou/README.md),
this completes the IIe's custom-silicon trio; all three are specified so a
future `system/apple_iie` build can wire them to the existing `mos_6502`
core and the Apple II board inventory.
