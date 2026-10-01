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
- Four-channel paddle RC test passed, including Bâ†’paddle 3 and Dâ†’paddle 1.
- Authentic Monitor regression passed through the integrated reference system:
  exact reset vector reads and FF59 opcode fetch; typed deposit `300:A5 5A`;
  typed examine `300.301`; CPU readback A5/5A at 0300/0301.
  The extended display regression first invokes HOME with ESC then @
  (physical Shift-P), asserts blank untouched rows and exact printed output,
  and compares the complete observed serial raster to tracked CPU text writes.
  Observed 64,393 instruction fetches and 4,524 unresolved read samples
  at the reference boundary, ending at approximately 183.212 ms simulated time.
- Nine digital video diagnostic frames passed: inverse/flashing/normal text,
  both text pages, lores, both hires pages, mixed lores/hires at line 160, and
  text precedence over graphics switches. All screen patterns were initialized
  through physical CPU socket writes; no DRAM contents were injected.
- Ten captured frames (nine diagnostics plus Monitor) each had 238,944 master
  samples, 65 character clocks per line and 262 lines per frame. All scan states,
  blanking and original revision-0 sync values matched the independent oracle.
  **1,075,200 visible serial pixel samples** matched exactly. Actual observed
  monochrome PNGs and raw CSVs are retained in ignored `work/`.
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
   and composite-video voltage/color validation remain outstanding. Digital
   visible Monitor output and diagnostic modes are now validated as above.
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

## Video oracle and stimulus corrections

The initial graphics oracle applied the later-board DL7 half-dot shift. The
revision-0 schematic lacks that delayed path, and Gayler's *Apple II Circuit
Description*, Appendix B p.153, explicitly says DL7 is ignored. The corrected
oracle validates both values of DL7 without adding later-board hardware.

The manual's Shift-P screen-clear instruction names a physical key combination.
At the seven-bit keyboard boundary it must be `$40` (@), not `$50` (P), as
pinned by the original Monitor's FC2C `EOR #$C0`/`BEQ HOME`. The new display
assertions reject surviving startup question marks and verify exact output
rows and untouched spaces. These corrections were made during regression
bring-up before commit; no CPU or support-package RTL was changed.
