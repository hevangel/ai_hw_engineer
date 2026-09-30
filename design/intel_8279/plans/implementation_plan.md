# Intel 8279 implementation plan

1. Extract command encodings, scan timing, keyboard modes, display addressing, and status behavior from Intel's [8279 data sheet](https://datasheets.pl/elementy_czynne/IC/8/8279.pdf) before RTL.
2. Implement a single-clock core with split bus pins, mode/command registers, prescaler and scan counter, 8-byte FIFO/sensor RAM, and 16-byte display RAM.
3. Use one display address/AI register for both read and write commands. Keep keyboard and display operations concurrent. Represent right entry with a logical ring origin.
4. Verify command reads and writes, clear, output scan, rollover, lockout, sensor interrupt, strobed capture, and error status in a pin-level directed bench.
5. Run strict Verilator and Verible lint, SymbiYosys BMC/prove/cover, and Yosys generic synthesis. Record observed results and limitations in the final report.

The clock parameter `SCAN_DIV` defaults to 64 for the data sheet's display scan cadence; the bench and formal cover use 1 to reduce simulation/solver time. No analog behavior or asynchronous electrical timing is represented.
