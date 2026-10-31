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
   replica. The crystal oscillator is an ideal clock input. Q3/Q4 output networks
   and configurable loads now have reduced numerical models; supply ramp,
   decoupling, device tolerances, leakage and parasitics remain unsolved.
2. Analog package models use ideal comparator thresholds, reduced RC networks,
   typical amplifier parameters, and explicit initial conditions. No vintage
   waveform comparison has been performed. Full cassette commands pass at both firmware and physical-board layers.
   Measured audio and composite-video voltage/color agreement remain outstanding. Digital
   visible Monitor output and diagnostic modes are now validated as above.
3. All 83 ICs and 1,368 pads now agree with an independently traced copper
   source. Non-IC components still require a complete schematic/copper audit.
   Corrections and source hashes are recorded in the board ledger.
4. The character font is a conversion from a pinned AppleWin EPROM
   representation. Its physical package pin/address mapping is tested, but
   the converted glyph contents have not been compared to an original 2513 dump.
5. Passive system-bus charge now preserves the preceding video byte.
   CPU reference reads still convert genuinely unknown input bits to high and count them.
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
The complete original WRITE/READ commands now pass as recorded below.
Speed variation is tested in the firmware harness. Physical noise/speed margins
and measured analog waveform agreement remain outstanding; the byte-routine
regression alone does not certify those requirements.

## Authored 6502 completion

The 151 documented-opcode authored NMOS core now replaces H7 in
`apple_ii_rev0_authored`, retaining the other 82 package instances and actual
motherboard nets. This option loads no CPU VPI module. Its own lint, formal,
independent instructions/arithmetic/pin tests, synthesis and real-software
gates are listed in the [CPU report](../../../design/mos_6502_family/mos_6502/cycle/report/final_report.md).

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

## Completion work: cassette commands and output networks

`run_cassette_command_firmware.sh` executes the unchanged original Monitor
through its real command parser on the authored RTL CPU. This is explicitly
a **firmware harness with behavioral memory/I/O**, not the resolved motherboard.
Nine cases pass: full WRITE, six good READs (both polarities at .92/1/1.08 tape
period scales), and bad-checksum READs in both polarities. The inclusive range
02FD..0302 crosses a page; all six bytes and XOR checksum agree.

WRITE emits 16,499 transitions with the complete approximately 10.79-second
command. The leader has 16,385 long half-cycles: ordinary 652-cycle intervals,
656 cycles at block boundaries, then 195/250-cycle sync halves. Data intervals
match the original instruction listing, including four additional cycles on
NXTA1 low-byte wrap. Both bad-checksum cases print ERR; all cases ring the bell.
Full historical-command execution on the resolved physical board also passes
as recorded below.

Q3/R5-R11/L1/Cap2/CT3 and Q4/Cap11/R24/CR1/R25/Cap12/speaker networks are now
wired to actual B12/B10/C13/J13 signals in both CPU wrappers. The bounded copper
check includes published Red Book corrections and every output network endpoint
and component value used by these models. It does not certify every imported
connection. Models use configurable reduced transistor/diode/load parameters
and explicit zero-energy initialization, with unknown-state validity preserved.

Strict Verilator lint passes for the motherboard and three output-network
modules. Icarus DC/load/pot, speaker pulse/energy decay, AC blocking, unknown
state and reinitialization tests pass. An independent complex-impedance/Fourier
oracle gives tank RMS error .028965 V (including 2 ns stimulus quantization).
The independent speaker winding-law residual is at most .001926 V; halving
the integration step changes observed speaker voltage by at most .000163 V.
These are numerical/circuit checks, not a comparison with vintage measurements.
No synthesis or SBY claims apply to these real-valued simulation networks.

## Local front panel

The new Icarus VPI bridge transports keyboard bytes and actual serialized
frames. It contains no CPU/RAM/video emulation. Transport tests pass for key
order, an independent Reset channel, EOF recovery after appended input, all 107,520 frame
pixels, orientation and X/Z preservation. The local HTTP server serves the
canvas and rejects malformed/non-ASCII input. The live physical board accepted
ESC/@, `300:A5 5A` and `300.301`; observed command/readback glyph pixels agreed
with the external font. A screenshot was visually checked in the in-app browser.
The frontend is monochrome and runs at simulator speed; analog color/audio
presentation and measured fidelity are not claimed.

The Integer BASIC physical program regression was added. During bring-up,
the original ROM rejected a combined immediate `COLOR=9:PLOT 3,4` command in
both the fast CPU harness and the physical board. Separate immediate commands
succeed. The initial one-second watchdog also expired during legitimate ROM
processing at FC8E, so the final test allows three seconds and first performs
the original screen clear. The rerun passes at 893.476743 ms: 292,559 instruction fetches and 11,847
counted unresolved non-opcode reads. The program prints SUM=55, stores 55 and
lores color 9 through physical DRAM, and returns to the Monitor, which prints
0300- 37 09. This does not characterize uninitialized/dummy/floating bus reads.

## Long physical cassette gate

`run_full_write_board.sh` types the payload and `2FD.302W` through physical
keyboard pins and the original Monitor parser. It leaves every firmware byte
unchanged, selects an explicit initial J13 state and observes real J13 edges,
R18/R19 voltage and generated CPU timing. The independent listing oracle
requires 16,499 transitions and all 16,498 intervals, including full leader,
sync, page carry and checksum. The original integration gate finished successfully before the charge/copper
changes: WRITE completed at 10.782144314017 seconds with 16,499 transitions,
all 16,498 intervals and real output-divider voltages matching the oracle.
It counted 21,243 unresolved non-opcode read samples.

`run_full_read_board.sh` likewise passed all four physical original READ
commands through Cap10/K13/H14 with an independent 12,000-half-cycle leader
and standard sync/data waveform. Each case received all six bytes, verified
six actual DRAM readbacks and printed ERR if and only if the checksum was bad.

| Polarity | Checksum | Completion (simulated seconds) | Unresolved reads |
|---|---|---:|---:|
| +1 | good | 8.120533580441 | 331,606 |
| +1 | bad | 8.121259657873 | 331,645 |
| -1 | good | 8.120536513805 | 331,659 |
| -1 | bad | 8.121262591237 | 331,698 |

Both simulator jobs and every independent checker exited zero. These numbers
are retained as the pre-charge baseline, not measured electrical fidelity.
No completed final charge/copper full-command rerun result was recorded
in the original branch. The pre-charge baseline remains historical evidence only.

## Independent IC wiring and retained bus

The independently traced Willegal copper fixture covers every physical pad
of all 83 ICs: 1,368 pads / 322 nets and open nodes. The audit compares net
partitions by pin membership, rejecting split or shorted connections. Eight
source-open pads omitted by imported symbols are accounted for explicitly.
Extraction is reproducible from the SHA-pinned Osmond file. It exposed a
short between the two separate A2 soft-5 outputs and an omitted H14.6 ground
connection. Both are corrected in the manifest and regenerated RTL.

The physical data bus now retains passive charge through weak resolved
feedback, preserving the preceding video byte on undriven I/O reads. The
regression checks 5,632 known reads (5,599 nontrivial video values), D7-only
cassette/button/paddle inputs, strong expansion writes, X from contention,
known-drive recovery, RES preservation, CPU writes and actual RAM readback.
The same regression with retention disabled fails at C020, as required by
its negative control. No video/RAM/decoder shortcut is inserted.

The first retention firmware rerun passed the original Monitor and its full
107,520-pixel visible raster, Integer BASIC, and both original cassette-byte
polarities. BASIC also now isolates its PEEK(-16336) access from the boot bell
and requires exactly one known physical J13 speaker transition. Its result
remains SUM=55, lores color 9 and Monitor 0300- 37 09, with 292,559 fetches and
11,751 unresolved reads. The final corrected-board short suite also exited zero: independent copper
and published-correction checks, strict lint, three DRAM banks, floating bus
plus negative control, all nine diagnostic frames (967,680 visible samples),
original Monitor (107,520 visible samples), and Integer BASIC with isolated
speaker toggle. Together its ten complete frames compare 1,075,200 visible
samples exactly. Final Monitor/BASIC counts are unchanged from the first
retention rerun. A completed post-copper/charge full physical-command rerun remains unrecorded.

Charge leakage/analog drive current remain assumptions; uninitialized DRAM
can still yield genuine unknown reads. Verilator two-state lint cannot model
Z-dependent retention: the initialization and latch warning exceptions are
local and explained. Icarus four-state regressions verify actual strengths.
No synthesis or formal proof is claimed for the passive charge model.

## October 18, 2026 branch integration

The seven previously local Apple II commits through `aabbf67` are integrated
with the current main branch. Both authored CPU implementations are retained:
`design/mos_6502_family/mos_6502` is unchanged except for its README cross-link, while the
physical-bus implementation is preserved as `design/mos_6502_family/mos_6502/cycle` with a
separate module name and the original bus/pin tests. The motherboard uses
that physical-bus implementation. The IIe MMU, IOU and timing PAL already
present on main are preserved.

Fresh integration checks have passed strict CPU lint, all three SBY tasks,
177,280 independent documented-opcode/bus cases, all 105 unsupported opcode
traps, 524,288 arithmetic cases, Klaus at PC 3469 after 96,241,381 cycles,
648 transistor pin scenarios / 116,501 cycles, and CPU synthesis. The existing
functional-bus CPU's RTL and tests are unchanged.

The system rerun passed the independent 83-package/1,368-pad copper audit,
RAM/keyboard and CPU echo, digital/analog package regressions, synthesis of
16 combinational packages, motherboard lint, physical DRAM routing, retained
bus and failing negative control, paddle/divider/output-network checks, and
nine diagnostic frames with 967,680 exact visible pixels. Original Monitor
boot/deposit/examine also passed with its 107,520-pixel frame.

The optional VPI reference initially exposed an uninitialized allocation in
the pinned external solver. An explicit generated allocation-only fix retains
the original hash-checked artifact. The new startup/reset-vector/first-fetch
regression passes with allocator poisoning and AddressSanitizer; all existing
pin comparisons also pass with the initialized solver. See the
[post-mortem](../../../failure_notes/2026-10-18-apple-ii-reference-initialization.md).

Fresh historical firmware reruns also passed: original Monitor and its full
107,520-pixel frame on both reference and authored CPUs; cassette byte input
in both polarities on both CPUs with seven DRAM readbacks, 112 transitions
and 111 exact cycle intervals per run; front-panel ordered input/reset/EOF
handling and frame encoding; and original Integer BASIC FOR/NEXT, SUM=55,
POKE/PRINT, lores PLOT/SCRN, one isolated speaker toggle and Monitor readback.
BASIC executed 292,559 instruction fetches and counted 11,751 unresolved
non-opcode reads. The compiled authored-CPU harness passed all nine complete
original WRITE/READ command cases, including full leaders, page crossing,
both input polarities, speed variation and checksum-error ERR behavior.

The imported Docker overlay built successfully, and its reference startup
smoke test passed. Internal links across 22 imported/moved Markdown documents
and Git whitespace checks passed. The isolated CPU and firmware rerun drivers
both exited zero. Downloaded artifacts, compiled binaries and raw traces are
ignored; the retained front-panel image is explicitly identified as an earlier
capture. A scratch-source comparison found only an unsupported Verilator
experiment and a stale nested copy of the earlier CPU, not additional
completed implementation work. The long
full-delay physical WRITE/READ gates are retained with their historical
pre-charge results; no completed post-copper/charge result is claimed here.
The exact analog/font acceptance limits and intentional final failure of
`run_all.sh` remain in force. This merge publishes functional work without
claiming complete electrical sign-off.

## Package timing (29 October 2026, review item P1)

`board/timing.json` carries a per-package propagation delay with the
manufacturer document and printed page that publish it. The TI literature
number is recorded only where the scan prints one; the remaining entries cite
the document URL and page, because an unprinted number is not a citation.
`generate_rev0.py --timing typ|max` regenerates the same connectivity from those
per-part delays and refuses to run when a characterized part has no source. The
typical and maximum boards differ only in `T_PD` values (checked by normalizing
the two outputs). `--timing legacy` reproduces the previous uniform 5 ns board
byte for byte and stays the checked-in default, because the video, cassette and
peripheral harnesses still encode zero-delay phase relationships.

Two entries are bounds rather than board-load numbers. The 8T97 datasheet is
specified at CL = 50 pF, so its 13 ns maximum is conservative at the board's
15 pF, and no Signetics 8T28 delay was readable, so the AMD second-source 17 ns
maximum is used for both directions. The table carries both caveats.

The memory packages are marked `idealized` and keep the legacy output delay in
every mode: 20 ns for the 4116, 5 ns for the system ROM and 2513. A datasheet
4116 access delay makes the video data latch capture Hi-Z between CAS cycles,
because the model has no tRAC/tCAC or output-hold behaviour. That is review item
P3, not a TTL delay question.

Measured with Icarus 12.0-3 in the Apple II tools image, with the same authored
CPU and unmodified Monitor ROM in every row:

| Timing set | Directed socket test | Monitor keyboard/CPU | Monitor frame comparison |
|---|---|---|---|
| legacy (5 ns, checked in) | pass, data at +429 ns | pass, 64,393 instructions, 4,516 unresolved reads | pass, pixel-exact |
| datasheet typical | pass, data at +469 ns | pass, 64,394 instructions, 4,516 unresolved reads | rejected: capture one sample out of phase |
| datasheet maximum | pass, data at +472 ns | pass, 64,394 instructions, 4,516 unresolved reads | not compared (see below) |

The socket harness now samples read data at the phi2 falling edge, where a 6502
latches it, and prints how long each bank took to drive the bus. Phi2 high lasts
488.9 ns, so the margin is 60 ns at legacy delays, 20 ns at typical and 17 ns at
maximum. The previous harness sampled at a fixed +470 ns: that point sat 1-3 ns
inside the window, so the maximum-delay readback failure it reported was a
timing coincidence in the harness, not a board finding. Address and data were
already presented during the previous phase, as a 6502 does.

One limit remains, and it is measured rather than assumed. At datasheet delays
`composite_sync` is produced after a deeper gate chain than the counter outputs
the oracle derives it from, so comparing the two at the same instant fails, and
no constant dot shift reconciles them: across shifts of -4 to +4 samples the
best agreement is 70% of the frame. A delay-faithful video check needs an
edge-time comparison rather than a per-dot sample, so the pixel-exact frame gate
stays on the legacy board.

Consequently `run_all.sh` keeps legacy timing, and `scripts/run_timing_sim.sh`
covers the socket test and the Monitor boot at typical and maximum delays. Its
summary line names the frame comparison as legacy-only rather than hiding it.

## DRAM refresh (30 October 2026, review item P2)

The 4116 model retains data indefinitely, so the board's reliance on the video
scan for refresh was an assumption rather than a checked property.
`tb/apple_ii_refresh_check.sv` now watches the RAS/row-address bus — shared by
all eight banks — and records the gap between successive accesses to each row.
The boot gate asserts row coverage (a run that misses any of the 128 rows fails)
and reports the margin.

Measured with Icarus 12.0-3 in the Apple II tools image:

| Configuration | Rows refreshed | RAS accesses | Worst same-row gap | Gaps over 2 ms |
|---|---|---|---|---|
| authored Monitor boot, CPU running (183 ms) | 128/128 | 373,928 | 1.9668 ms | 0 |
| video scan only, CPU socket idle (40 ms) | 128/128 | 81,635 | 2.2215 ms | 48 |

The 4116 requires every row to be refreshed within 2 ms. With the CPU executing
the worst gap is 1.9668 ms, inside the limit. With the CPU idle the video scan
alone takes 2.2215 ms, 11% longer than the device allows, and the checker flags
48 violations in 40 ms; every row sits in the 1.85-2.22 ms band, so the overrun
is the sweep itself rather than a few slow rows.

The second row is a finding, not a pass: part of the board's refresh budget is
carried by CPU accesses, and the video-only path is marginally short. The real
machine works, so either the device tolerance is wider than the datasheet figure
at room temperature or the model's row addressing differs from silicon; that
question is left open rather than explained away. What changed is that the
margin is now measured, and a change that lengthens the sweep shows up
immediately.

`scripts/run_refresh_check.sh` runs the video-only configuration as a negative
control: it requires all 128 rows and at least one violation, so a checker stuck
at zero cannot pass the boot gate for the wrong reason.
