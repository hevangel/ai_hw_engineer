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
   waveform comparison has been performed. Full cassette command/audio validation
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
6. Xezim package tests pass; the complete resolved-bus board test loses driven
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

## Cassette implementation and validation

The cassette regression replaces only the D0 socket with a 209-byte project
exerciser. The original Monitor boots and enters it via physical keyboard
`D000G`; F8 is the unchanged hash-pinned historical ROM. The exerciser stores
`00 FF 55 AA A5 5A` through the physical DRAM path and calls the original
WRITE body at FED2. The routine writes those bytes and XOR checksum `00`
through C020 and J13. An independent 1.2 V peak-to-peak waveform exercises
the original FCEC RDBYTE through Cap10, K13, H14 and the shared data path.
Received bytes are stored in DRAM, then read back and copied to another range.

The R18/R19 output divider now exposes a real jack voltage and a separate
validity flag. Explicit assumed TTL levels of 0.2/4.0 V give 31.405 mV
open-circuit swing; a configurable 1 kΩ load gives 28.571 mV. Unknown or
floating driver levels and invalid negative loads cannot become valid voltage
samples. The analog boundary regression checks both voltages and invalid
states; motherboard/divider Verilator lint passes.

Both polarities pass in the feature worktree: seven received bytes and seven
physical DRAM readbacks each, 112 output transitions each, and 111 exact
firmware cycle intervals each. Observed half-cycles span 244.028-492.945 µs.
The positive/negative runs observe 128,607/128,611 post-vector instruction
fetches and 7,720/7,721 unresolved read samples, ending at approximately
345.124/345.136 ms. No unknown opcode is accepted after the completed reset
vector, and received data/readback must be fully known. The unresolved-read
count remains an explicit reference-boundary limit, not electrical sign-off.
The existing Monitor screen-clear/deposit/examine and complete 107,520-pixel
visible raster regression also passes with the added voltage observer.

The timing oracle uses exact counts from the original Monitor listing:
ordinary first/second halves take 253/250 CPU clocks for zero, with 250
more clocks for one. Later data-byte first halves take 249 clocks, and the
checksum first half takes 258 (plus 250 for one). This is stricter and more
appropriate than treating the rounded 250/500 µs tape-format figures as
exact intervals. The initial edge has no recorded preceding transition and
is excluded from interval checks. The two polarities also select both
possible initial states of J13's unresettable cassette flip-flop.

Sources and the bounded acceptance contract are in [cassette.md](../spec/cassette.md).
The standard ten-second WRITE leader and complete READ command's acquisition,
sync search, checksum/error handling, noise/speed tolerance and measured
analog waveform agreement remain outstanding. The byte-routine regression
does not claim those acceptance requirements are complete.

## Authored 6502 completion

The 151 documented-opcode authored NMOS core now replaces H7 in
`apple_ii_rev0_authored`, retaining the other 82 package instances and actual
motherboard nets. This option loads no CPU VPI module. Its own lint, formal,
independent instructions/arithmetic/pin tests, synthesis and real-software
gates are listed in the [CPU report](../../../design/mos_6502/report/final_report.md).

The authored option passes Monitor keyboard clear/deposit/examine and the
complete 107,520-pixel visible frame. Both cassette polarities also pass:
seven received bytes/readbacks, 112 transitions and 111 exact cycle intervals
each. The authored positive/negative runs observe 128,607/128,611 fetches
and 7,719/7,720 unresolved reads, ending at 345.121639/345.134350 ms.
Different canonical reset/dummy reads account for the reference count offset;
unknown opcodes and unknown received/readback bytes remain forbidden.

This completes the authored CPU's documented-instruction firmware gate.
It does not close the independent motherboard analog, font-dump or imported
connectivity audit requirements listed above.
