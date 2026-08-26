# Intel 8253/8254 Programmable Interval Timer

The Intel 8253 and 8254 are three-channel programmable interval timers for early microprocessor systems. Software programs each independent 16-bit counter for interrupt timing, event counting, rate generation, square-wave generation, or one-shot/strobe operation. The 8254 retains the programming model while adding a read-back command, independent read/write byte phases, and higher-speed implementations.

## Historical context

This repository records **1975*** for the 8253 because Intel's September 1975 *8080 Microcomputer Systems User's Manual* is the earliest dated Intel documentation located during this implementation. It records **1982*** for the 8254 because Intel's 1982 systems data catalog contains a preliminary 8254 datasheet. These are evidence-backed documentation years, not claims of exact commercial launch dates; either device may have been introduced earlier within its respective year.

The timers mattered because they moved timing loops and waveform generation out of software and into a reusable peripheral. Their six operating modes supported terminal-count interrupts, retriggerable one-shots, periodic rates, square waves, and software- or hardware-triggered strobes. The compatible 8254 timer model persisted in PC platforms and remains documented in modern Intel-compatible platform material.

## Repository implementation

Both chips share one synthesizable SystemVerilog module, [`intel_8253_8254`](src/intel_8253_8254.sv). Its architectural parameter selects the elaborated variant:

- `IS_8254 = 1'b0` selects 8253 behavior: read-back commands are ignored and each counter shares one LSB/MSB phase between reads and writes.
- `IS_8254 = 1'b1` selects 8254 behavior: count/status read-back is enabled and read/write byte phases are independent.

The common timer engine provides three fixed 16-bit counters, Modes 0–5 (including Mode 2/3 aliases), binary and packed four-decade BCD counting, count/status latches, GATE control, null-count status, and the four-address CPU programming interface.

The historical devices use three independent asynchronous counter clocks and do not have a device-wide clock or reset. This implementation adds an integration `clk` and synchronous active-low `rst_n`; falling counter-clock and rising GATE events are detected from sampled input levels. External asynchronous inputs therefore require integration-layer synchronization. The design is a cycle-defined digital reconstruction and does not claim pin timing, metastability, electrical, package, or process compatibility.

## Documentation

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal verification plan](plans/formal_plan.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

## Sources

- [Intel 8080 Microcomputer Systems User's Manual, September 1975, text archive](https://archive.org/stream/bitsavers_intelMCS80ocomputerSystemsUsersManual197509_43049640/98-153B_Intel_8080_Microcomputer_Systems_Users_Manual_197509_djvu.txt)
- [Intel 8080 Microcomputer Systems User's Manual catalog record](https://archive.org/details/intel8080microco00inte)
- [Intel 1982 Systems Data Catalog, including the preliminary 8254 material](https://archive.org/stream/bitsavers_inteldataBCatalog_75793335/1982_Systems_Data_Catalog_djvu.txt)
- [Intel 8254 datasheet reproduction](https://www.scs.stanford.edu/10wi-cs140/pintos/specs/8254.pdf)
- [Intel-compatible platform 8254 timer documentation](https://edc.intel.com/content/www/us/en/design/products/platforms/details/meteor-lake-u-p/core-ultra-processor-datasheet-volume-1-of-2/001/8254-timers/)
- [Historical overview and additional references](https://en.wikipedia.org/wiki/Intel_8253)

Source content is summarized and rephrased for licensing compliance; no source prose is reproduced beyond device names and standard signal terminology.
