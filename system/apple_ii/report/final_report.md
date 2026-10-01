# Revision-0 reconstruction verification

## Observed results

- 79 digital package instances generated from 196-component connectivity facts.
- Three analog ICs and one physical-pin CPU reference bring the integrated
  IC count to 83. This count includes six ROM sockets; optional population
  and additional board connectors are not IC packages.
- 29 digital package regressions passed in Xezim; analog package regression
  passed in Icarus. Tests include exhaustive combinational inputs, sequential
  controls, both asynchronous flip-flop controls, all ROM addresses,
  open-collector/tri-state release, and DRAM row/column/write behavior.
- Physical CPU socket transactions wrote and read all three DRAM banks in
  Icarus without a behavioral RAM block or behavioral motherboard decoder.
- Four-channel paddle RC test passed, including B→paddle 3 and D→paddle 1.
- Authentic Monitor regression passed through the integrated reference system:
  exact reset vector reads and FF59 opcode fetch; typed deposit `300:A5 5A`;
  typed examine `300.301`; CPU readback A5/5A at 0300/0301.
  Observed 75,520 instruction fetches and 4,568 unresolved read samples
  at the reference boundary, ending at approximately 227.222 ms simulated time.
- Verilator 5.052 lint passed with documented physical-open-pin, pullup,
  unused-pin, and direction-enabled bus feedback exceptions.
- Yosys synthesis/check passed for 16 zero-delay combinational package models.
- The Icarus 12.0-3 tools overlay built successfully.

## Limits that prevent sign-off

1. This is a functional physical-package simulation, not an exact electrical
   replica. The crystal oscillator is an ideal clock input. Q3/Q4 output
   transistor stages, output loads, supply ramp/decoupling, device tolerances,
   leakage, and parasitic effects are not solved.
2. Analog package models use ideal comparator thresholds, reduced RC networks,
   typical amplifier parameters, and explicit initial conditions. No vintage
   waveform comparison has been performed. Cassette firmware/audio validation
   and visible composite-video validation remain outstanding.
3. The imported revision-0 transcription requires comparison against every
   original schematic sheet. Corrections are recorded separately; netlist
   generation cannot prove that upstream connectivity facts are correct.
4. The character font is a conversion from a pinned AppleWin EPROM
   representation. Its physical package pin/address mapping is tested, but
   the converted glyph contents have not been compared to an original 2513 dump.
5. CPU reference reads convert unknown input bits to high and count them.
   The Monitor regression forbids unknown opcodes, but dummy/uninitialized
   data reads remain. Success does not certify those electrical read values.
6. The authored synthesizable 6502 supports 29 opcodes and is not completed
   by using an external transistor reference. Its own historical-software
   acceptance gate remains failing.
7. Xezim package tests pass; the complete resolved-bus board test loses driven
   CPU data. Icarus passes the identical board test. The full reproducer is
   `SIMULATOR=xezim sh scripts/run_board_sim.sh`; scalar reductions passed,
   so the simulator defect is not yet reduced to an isolated minimal case.

No SBY proofs are claimed for these mixed-signal/event package models.
Analog, DRAM event models, and the external transistor CPU are simulation-only;
their synthesis is not claimed. The full system `run_all.sh` intentionally
returns nonzero after successful regressions while the requirements above remain.
