# Simulation test plan

Use external memory/peripheral BFMs. Check exact channel order, addresses, directions, payloads, final register values and status read-to-clear; no hierarchical stimulus or RTL-derived oracle.

Directed cases: reset/master clear; global byte phase; mask/disable; software request bypass/block eligibility; all channels/directions/service modes; fixed/rotating contention; single release/HLDA interlock; demand resume; READY/verify/cascade; EOP/reload; increment/decrement/wrap and high-address strobes; compressed/extended timing; memory copy/fill, unequal/equal counts, Temporary and phase EOP. Full 65536-transfer verify checks maximum count.

Random block transfers vary channel, address, length, direction, decrement, auto initialization and waits. A separate factory-registered UVM sequencer/driver/monitor/scoreboard regression and dedicated coverage collector exercise register accesses and expected DMA transactions.

`run_sim.sh` runs Verilator, Xezim and UVM; `run_coverage.sh` gathers RTL statement/branch/toggle coverage and UVM functional coverage. Passing suites do not establish silicon equivalence.
