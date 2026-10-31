# 82288 CENL source reconciliation — 2026-10-28

## Finding

Intel's *80286 Hardware Reference Manual*, order 210760-002, contains a
contradictory passage about the 82288 `CENL` input. Its controller-selection
diagram shows the always-selected local controller with `CENL` tied high, but
the adjacent text says a sampled-high input makes the controller ignore the
cycle. That sentence conflicts with the diagram and with the CENL description
in Intel's original HMOS device datasheet.

I inspected Intel's scanned *M82288 Bus Controller for M80286 Processors*
(Military) datasheet in the Datasheet Archive viewer using Playwright CLI. Its
pin description (PDF page 2) defines CENL as active HIGH, latched at the start
of each bus cycle, and says it may be tied to VCC to select the controller for
all transfers. Its control-input discussion (PDF page 9) says CENL is sampled
HIGH at the end of `Ts` to enable that controller's command and control
outputs; sampled LOW prevents commands and DEN and leaves `DT/R` HIGH until a
new cycle. This directly resolves the polarity conflict: the manual's
sampled-high/ignore sentence is an apparent textual error.

The later Intel 82C288/M82C288 datasheets independently state that these CHMOS
parts are fully compatible with the HMOS M82288 and also define CENL as active
HIGH. The original HMOS source is now checked for functional polarity and
cycle selection. It does not establish every speed-grade setup/hold limit or
electrical behavior of a particular physical part.

## Controller-model consequences

The implemented functional profile models one local bus in non-MULTIBUS mode
(`MB=0`):

- `CENL=1` selects the controller; its level is latched at cycle start and
  applied at the end of `Ts`. `CENL=0` suppresses command and DEN activation
  for that cycle, with `DT/R` held HIGH.
- In this mode, `CEN` is an asynchronous command/DEN gate. A HIGH-to-LOW
  transition immediately forces those outputs inactive; a LOW-to-HIGH
  transition enables their current state. A selected cycle still terminates
  through READY.
- `CMDLY` is active HIGH and is sampled on each falling edge of system CLK,
  beginning at the edge ending `Ts`. While sampled HIGH, it delays the
  selected command. A LOW sample enables the command in non-MULTIBUS mode.
- READY is active LOW and is sampled at each `Tc` end. HIGH repeats `Tc`
  without changing active outputs; LOW ends the cycle. A cycle can end before
  CMDLY enables a command.
- `ALE` is active HIGH in the second phase of `Ts`, absent on halt, and not
  gated by the controller-enable inputs. `DT/R` is HIGH for writes and idle,
  LOW for reads; DEN must be inactive while direction changes.
- Decode `M/IO`, `S1`, and `S0` for memory read/write, I/O read/write and
  interrupt acknowledge. Halt/shutdown and idle do not issue commands. MCE
  is active with ALE during INTA and stays active for one external CLK period
  after ALE falls. Write DEN can be prepared in phase two of `Ts`, before the
  end-of-`Ts` CENL decision suppresses DEN for an unselected cycle.

The model is implemented as the separate `intel_80286_82288` system-interface
component and is connected to `intel_80286_native_cpu`. The wrapper accepts
both processor-rate `clk_i` and external 2x `clk_2x_i`; it does not derive or
phase-lock them. Directed controller and connected-CPU tests cover the local
strobes. This cycle-level model does not claim electrical timing or physical
qualification, and it does not implement the `MB=1` MULTIBUS delay profile.

## Sources

- Intel, *M82288 Bus Controller for M80286 Processors* (Military), scanned
  manufacturer datasheet, [datasheet record and preview](https://www.datasheetarchive.com/datasheet/M82288/Intel?term=m82288&version=1), especially PDF pages 2, 4–6, 8–10.
- Intel, [*80286 Hardware Reference Manual*, order 210760-002 (1987)](https://www.bitsavers.org/components/intel/80286/210760-002_80286_Hardware_Reference_Manual_1987.pdf), Chapter 3, “Selecting a Controller,” Figures 3-41 through 3-47.
- Intel, *M82C288 Bus Controller for M80286 Processors*, order 271077-006,
  [datasheet PDF](https://intel-vintage-developer.eu5.org/DESIGN/SPECENVN/INTARCH/DATASHTS/27107706.PDF), pin description, Table 2, processor/bus-state definitions and control-input discussion.

The polarity blocker was resolved during the source inspection. At that
inspection checkpoint, no RTL or test files had changed; the subsequent
controller implementation and evidence are recorded in
[the local 82288 report](2026-10-28-82288-local-controller.md).
