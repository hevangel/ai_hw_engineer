# Intel 8259A Programmable Interrupt Controller

The Intel 8259, and its refined successor the 8259A, is a programmable interrupt
controller (PIC) that manages up to eight prioritized interrupt requests for a
CPU, resolves the highest-priority request, signals the processor, and supplies
a programmed interrupt vector during the acknowledge sequence. Multiple devices
cascade to expand the interrupt count.

## Historical context

Intel introduced the 8259 as part of its MCS-85 family in **1976**. The later
8259A added 8086/8088 (MCS-86/88) support alongside the original MCS-80/85
mode. A pair of cascaded 8259A controllers became a defining fixture of the IBM
PC/AT-class interrupt architecture after the single-controller PC and PC/XT, and
the programming model persisted for decades in PC-compatible chipsets before the
APIC era. The introduction year is supported by the historical summary that
places the 8259 in Intel's MCS-85 family in 1976; the exact commercial launch
date within that year was not established, so the index records the year rather
than a month-level date.

The device mattered because it consolidated interrupt request latching, masking,
priority resolution (including rotation and special modes), vectoring, and
multi-controller cascading into a single programmable peripheral, replacing
substantial discrete interrupt logic and giving software fine-grained control
over interrupt priority and servicing.

## Repository implementation

This design implements the complete digital programming model:

- ICW1-ICW4 initialization sequencing (single and cascade configurations);
- edge-triggered and level-triggered request sensing;
- Interrupt Request, In-Service, and Interrupt Mask registers;
- a rotating priority resolver with fully nested, automatic-rotation,
  specific-rotation, and set-priority operation;
- the CPU acknowledge sequence in MCS-86/88 mode (two pulses, one vector byte)
  and MCS-80/85 mode (three pulses, `CALL` opcode plus two address bytes);
- non-specific, specific, and rotate-on-EOI commands, automatic EOI, and
  rotate-in-automatic-EOI;
- special fully nested mode, special mask mode, and polled mode;
- IRR/ISR readback through OCW3 and IMR readback;
- cascade signaling (master cascade-address drive, slave address decode) and
  buffered-mode buffer enable.

The original NMOS part is asynchronous and has neither a clock pin nor a reset
pin; it is brought to a defined state only by the ICW1 initialization sequence.
This repository uses a single-clock synthesizable core: the CPU bus, request
lines, and the acknowledge handshake are sampled on `clk`, while read data, the
vector/opcode/address output, the interrupt output, and the cascade/buffer
outputs are combinational. A synchronous active-low `rst_n` establishes a
defined un-initialized state. Separate input, output, and output-enable vectors
represent the shared cascade and buffer-enable pins. This preserves functional
ordering without claiming pin-level timing, metastability behavior, NMOS/TTL
electrical behavior, or package compatibility.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [Intel 8259A datasheet reproduction, pcjs.org archive](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf)
- [Intel "Programming the 8259A" application note archive](http://www.idc-online.com/technical_references/pdfs/electronic_engineering/Programming_THE_8259A.pdf)
- [8259A device summary, alldatasheet](http://www.alldatasheet.com/datasheet-pdf/pdf/66107/INTEL/8259A.html)
- [8259 historical summary and MCS-85 introduction date](https://en.wikipedia.org/wiki/Intel_8259)

Source content is summarized and rephrased for licensing compliance; no source
text is reproduced verbatim beyond device names and signal terminology.
