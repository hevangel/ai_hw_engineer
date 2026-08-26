# 74181 4-Bit Arithmetic Logic Unit

## At a glance

- **Part family:** 74181, including SN74LS181 and related 74x181 variants
- **Function:** 4-bit arithmetic logic unit (ALU) and function generator
- **First introduced:** 1970 by Texas Instruments
- **Technology:** 7400-series TTL medium-scale integration
- **Width:** 4 bits per device, with cascading support for wider datapaths
- **Notable features:** 16 logic functions, 16 arithmetic functions, internal carry lookahead, and propagate/generate outputs for use with a 74182 carry-lookahead generator

The introduction year is recorded as 1970 because historical sources differ on the exact month. The local technical specification identifies the Texas Instruments and Fairchild device documentation used for this design.

## Historical context

Before highly integrated microprocessors became common, computers often assembled a processor from boards of small- and medium-scale logic devices. The arithmetic logic unit was one of the most important pieces of that processor: it performed arithmetic, Boolean operations, comparisons, and the carry handling needed to join multiple word slices.

The 74181 put a complete 4-bit ALU/function generator into one TTL integrated circuit. Its 4-bit slice could be replicated to build wider datapaths, while the 74182 carry-lookahead generator could coordinate carries between slices. This made the ALU a reusable building block instead of requiring a separate gate-level implementation for every processor word size. The part's combination of broad operation selection and carry-lookahead support helped make it useful in the minicomputer and early bit-slice-processor era.

The 74181 is often described as an important transition from collections of discrete logic gates toward standardized, modular processor building blocks. It is also a useful historical case study because its unusual arithmetic function table is a consequence of the gate-level implementation and the desire to share logic across many operations, rather than a list of arbitrary modern ALU instructions.

## Why the chip is important

1. **It made an ALU a commodity building block.** A designer could assemble a processor datapath from repeated 4-bit slices instead of designing every arithmetic and logic function from individual gates.
2. **It supported practical word-width scaling.** Multiple 74181 devices could be combined, with 74182 carry-lookahead logic, to construct wider arithmetic units while avoiding a simple ripple-carry path through every slice.
3. **It captures the design trade-offs of TTL MSI.** The part exposes carry propagation, carry generation, active-low conventions, and a dense shared Boolean network that are normally hidden inside a modern processor macro.
4. **It connects hardware history with verifiable RTL.** Recreating the device requires preserving datasheet semantics, active-low signals, independent function tables, exhaustive simulation, formal properties, and synthesis evidence—not merely writing a modern `A + B` operator.

## This repository's implementation

The RTL model is a combinational SystemVerilog implementation of the active-HIGH function equations with the original active-LOW carry and lookahead outputs. The verification environment also checks the active-LOW data duality and the independently specified arithmetic and logic tables.

## Documentation and artifacts

### Markdown documentation

- [Specification](spec/spec.md) — device behavior, pinout, function tables, equations, timing, electrical characteristics, and application notes
- [Implementation plan](plans/implementation_plan.md) — RTL structure and implementation decisions
- [Formal verification plan](plans/formal_plan.md) — formal properties and proof strategy
- [Test plan](plans/testplan.md) — simulation, UVM, coverage, and sign-off strategy
- [Coverage report](report/coverage_report.md) — verification coverage and results
- [Final report](report/final_report.md) — design summary, validation evidence, and limitations

### Reference datasheets

- [Texas Instruments SN74LS181 datasheet](spec/SN74LS181_datasheet.pdf)
- [Fairchild 74F181 datasheet](spec/74F181_Fairchild_datasheet.pdf)

### Historical and technical references

- [Texas Instruments SN54S181 product page](https://www.ti.com/product/SN54S181) — manufacturer product information and device capabilities
- [74181 overview](https://en.wikipedia.org/wiki/74181) — introduction date and historical summary
- [Ken Shirriff: Inside the vintage 74181 ALU chip](https://www.righto.com/2017/03/inside-vintage-74181-alu-chip.html) — reverse engineering and historical context

The external historical references are secondary sources; the local datasheets and specification remain the source of truth for the behavior implemented in this repository.
