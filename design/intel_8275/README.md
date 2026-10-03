# Intel 8275 programmable CRT controller

The **8275**, publicly introduced in **1977**, brought DMA-fed raster display control to Intel's microcomputer family. It buffers one text row while displaying another, relieving the CPU of continuously feeding a CRT. Programmable raster geometry, graphics attributes, cursor and light pen made it useful for terminals and early text-oriented computers.

A contemporary [May 26, 1977 Electronics report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new 8275 with sample quantities forthcoming. The exact commercial first-shipment date is not established; 1977 is the public introduction year. The primary technical reference is the [Intel 8275 AFN-00224B scan](references/intel_8275.pdf), archived by [CPU Galaxy](https://www.cpu-galaxy.at/CPU/Ram%20Rom%20Eprom/Other_Intel_chips/other_intel-Dateien/8275_Datasheet.pdf).

This implementation provides the complete eight-command programming model, two row buffers, invisible-attribute FIFOs, configurable DMA bursts, raster timing, field and graphics attributes, four cursor forms, spaced rows, light pen, interrupts and error status. It uses a synchronous FPGA-style clock with a character-clock enable. Character ROM, dot serialization and electrical package timing are external. A standalone DMA bus functional model makes it independent of the currently unmerged 8237A design.

## Documents

* [Specification and assumption ledger](spec/spec.md)
* [Implementation plan](plans/implementation_plan.md)
* [Simulation/UVM plan](plans/testplan.md)
* [Formal plan](plans/formal_plan.md)
* [Source provenance and independent graphics vectors](references/README.md)
* [Verification report](report/final_report.md)
* [Coverage analysis](report/coverage_report.md)

## Run

From the repository root with the project tools installed:

```sh
sh design/intel_8275/scripts/run_all.sh
```

Or use the project Docker image:

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace ai-hw-engineer:latest \
  sh design/intel_8275/scripts/run_all.sh
```

The flow runs strict RTL lint, formal BMC/prove/cover, seeded pin-level tests in Verilator and Xezim, Xezim UVM, code coverage, then generic Yosys synthesis. Logs, waveforms, coverage databases and netlists are under ignored `work/`. Formal uses a four-column instance; simulation and synthesis use the full 80-column default. Integration must synchronize external inputs and supply `cclk_en`; see the specification for edge acceptance and undefined-operation boundaries.
