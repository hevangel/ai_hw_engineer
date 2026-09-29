# Intel 8279 test plan

The directed xezim testbench drives CPU bus cycles through the public pins and checks read data, output enable, IRQ, blanking, scan outputs, and display nibbles. It checks reset, the shared display pointer, auto-increment, write inhibit, clear busy/write rejection, right-entry output, decoded scan, sensor change/acknowledge, strobed FIFO, empty-read underrun, simultaneous-key rollover, two-key lockout, and special-error IRQ.

`SCAN_DIV=1` shortens the scan period; the default RTL parameter remains 64. Each test reports an exact expected byte or bit, and `run_sim.sh` requires a zero-failure result. The design is a peripheral, so no processor ISS or historical-software regression is applicable.
