# Intel 8279 programmable keyboard/display interface

**First introduced:** 1977*. A [May 26, 1977 contemporary report](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the part, establishing it by then; its exact first-shipment date is not established.

The 8279 combined keyboard scanning, contact debounce, an eight-character FIFO, a sensor-matrix mode, and refresh of 8- or 16-character displays. It mattered because an 8080/8085-class CPU could receive key interrupts and update display RAM instead of spending software cycles continuously scanning keys and refreshing digits. Intel's [8279/8279-5 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) is the technical source for this reconstruction.

This folder contains a synchronous SystemVerilog digital model with command/status bus interface, programmable scan timing, keyboard lockout and rollover, sensor and strobed input, display entry modes, directed verification, formal properties, and generic synthesis scripts. The physical chip's asynchronous bus edges and analog electrical behavior are outside this model.

## Documents

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Final report](report/final_report.md)

From the repository root, run `docker run --rm -v "$PWD:/workspace" -w /workspace ai-hw-engineer:latest sh design/intel_8279/scripts/run_all.sh` in a POSIX shell, or run `sh design/intel_8279/scripts/run_all.sh` inside the project image.
