# Numbered 74-series digital logic library

The shared folder contains the classic numbered 74-series library, including
numbers above 74299 with no numeric upper limit. See the
[extension coverage report](report/extended_report.md) for implemented, pending
and excluded counts. The full requested library is **not yet complete**: missing
source-backed digital parts remain explicitly pending in the manifest.
Unassigned numbers are not invented. Analog/timing-only parts are excluded.
The user extended this scope on 2026-10-20.

The [74181](README_74181.md) was moved here with its independent exhaustive/UVM,
formal and synthesis environment. Its public `alu_74181` name and ports are
preserved; `ttl_74x181` is a thin wrapper using the same active-low carry convention.
There is one module per file in `src/`, with all chips in this single design folder.

## Using the library

`ttl_74x00` implements the generic 7400 NAND function; the `x` denotes an equivalent
logic family. Historically different functions keep explicit letters, such as
`ttl_7451` versus `ttl_74l51` (also 74LS51), and `ttl_74l68` versus `ttl_74ls68`.
Aliases and manufacturer links are in the [manifest](manifest.json).
Use [files.f](files.f) from the repository root, or select individual sources.

These are **normalized digital functional interfaces**, not a promise of complete
native package-pin compatibility. Read each [part specification](#chip-index)
before connecting a board. In particular:

- Some RAM, FIFO and multi-clock parts expose a system clock or normalized
  transaction controls. Their native asynchronous handshake waveforms are not
  reproduced. Their capacities, data functions, ordering and stated enable
  behavior are tested through the documented interface.
- Three-state parts expose output drive enables or split input/output buses.
  A disabled data value is ignored; the enable determines whether the bus drives.
  Open-collector logical 1 means release to a pull-up; combine shared OC levels
  with an AND at the board boundary.
- ROM/PROM devices are read-only and image-backed. Supply the historical mask
  through `INIT_FILE`; blank defaults and synthetic test images are not historical
  contents. The 74262 exports whole 45-bit character bitmaps.
- Extended error-correction models use a documented normalized extended-Hamming
  matrix. They cannot be connected to native check-bit wiring without a matrix
  adapter. Some controller models also use simplified transaction interfaces;
  source-table conformance beyond their stated contracts is unreviewed.
- Rate multipliers retain the stated long-run division ratio through a normalized
  accumulator interface. The 74297 has a sampled-clock digital K-counter,
  increment/decrement and phase-detector contract; internal TI pipeline placement
  is outside that interface. Analog timing is outside every model.

The [specification](spec/spec.md) and per-part notes record these contracts and
assumptions. The [MIT baseline provenance](references/README.md) and local changes
are retained. The imported simplified 74181 was replaced by the existing verified
design. Local corrections include strobe polarity, expander terms, cascade
comparison, falling-edge ripple counters, native shift/load behavior, SR/D-FF
controls, output drive masks, read-only ROMs, inverted RAM outputs and divider ratios.

## Verification

Run in the repository's `ai-hw-engineer:latest` Docker image:

```sh
sh design/ttl_74xx/scripts/run_all.sh
```

Individual aggregate commands are `run_lint.sh`, `run_formal.sh`, `run_sim.sh` and
`run_synth.sh`. The manifest runner also accepts a single module:

```sh
python3 design/ttl_74xx/scripts/run_library.py all --chip ttl_74x161
```

All implemented modules receive strict Verilator RTL lint, xezim simulation and Yosys
synthesis/structural checks. Independent formal truth tables cover 46 gate modules;
additional formal contracts cover counter, shift and symbolic-address RAM behavior,
plus bounded FIFO ordering and reachable full/empty states. These targeted formal
checks are not a claim of exhaustive formal coverage for every catalogued
device. The original 74181 retains its full exhaustive/UVM/prove/cover flow.
Source fingerprints prevent successful stale phase results from being reused.

- [Library specification](spec/spec.md)
- [Original implementation plan](plans/library_plan.md)
- [Extension plan](plans/extended_plan.md)
- [Extension test plan](plans/extended_testplan.md)
- [Current coverage and missing parts](report/extended_report.md)
- [Formal verification plan](plans/library_formal_plan.md)
- [Test plan](plans/library_testplan.md)
- [Current verification report](report/library_report.md)
- [74181 specification](spec/74181.md), [overview](README_74181.md),
  [implementation plan](plans/implementation_plan.md), [formal plan](plans/formal_plan.md),
  [test plan](plans/testplan.md), [coverage](report/coverage_report.md),
  [original report](report/final_report.md), [migration report](report/migration_report.md)

## Historical context and dates

These devices made gates, arithmetic, storage and control reusable building blocks
for board-level computers. The range spans several technology generations; sharing
a number does not establish equal logic or a shared introduction date.
The 74181 introduction year is **1970**, with month-level uncertainty documented
in its [sourced overview](README_74181.md). Exact introduction years for the other
individual parts have not been established here and are explicitly recorded as
unknown. Manufacturer datasheets establish their functions; they are linked for
each entry. No common year is assigned by guesswork. The
[1985 TI TTL Data Book volume 2](https://archive.org/details/bitsavers_tidataBookVol2_45945352)
is an independent historical/technical source for much of the classic range.

## Completion gate

`run_all.sh` verifies the implemented subset and writes its coverage report, then
fails if requested digital parts remain pending. To check the implemented subset
alone use `run_library.py all`. The frozen inventory prevents omitted entries
from being mistaken for full coverage. The [extended catalog](report/extended_report.md)
lists every pending part and its reason.

## Chip index

| Part | Function | First introduced | Status / specification |
|---|---|---|---|
| 74x00 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x00.md) |
| 74x01 | quad 2-input NAND gate; different pinout for 74H01 | Unknown | [implemented](spec/chips/ttl_74x01.md) |
| 74x02 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x02.md) |
| 74x03 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x03.md) |
| 74x04 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x04.md) |
| 74x05 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x05.md) |
| 74x06 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x06.md) |
| 74x07 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x07.md) |
| 74x08 | quad 2-input AND gate | Unknown | [implemented](spec/chips/ttl_74x08.md) |
| 74x09 | quad 2-input AND gate | Unknown | [implemented](spec/chips/ttl_74x09.md) |
| 74x10 | triple 3-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x10.md) |
| 74x11 | triple 3-input AND gate | Unknown | [implemented](spec/chips/ttl_74x11.md) |
| 74x12 | triple 3-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x12.md) |
| 74x13 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x13.md) |
| 74x14 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x14.md) |
| 74x15 | triple 3-input AND gate | Unknown | [implemented](spec/chips/ttl_74x15.md) |
| 74x16 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x16.md) |
| 74x17 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x17.md) |
| 74x18 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x18.md) |
| 74x19 | hex inverter gate | Unknown | [implemented](spec/chips/ttl_74x19.md) |
| 74x20 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x20.md) |
| 74x21 | dual 4-input AND gate | Unknown | [implemented](spec/chips/ttl_74x21.md) |
| 74x22 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x22.md) |
| 74x23 | dual 4-input NOR gate with strobe, one gate expandable with 74x60 | Unknown | [implemented](spec/chips/ttl_74x23.md) |
| 74x24 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x24.md) |
| 74x25 | dual 4-input NOR gate with strobe | Unknown | [implemented](spec/chips/ttl_74x25.md) |
| 74x26 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x26.md) |
| 74x27 | triple 3-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x27.md) |
| 74x28 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x28.md) |
| 74x29 | dual 4-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x29.md) |
| 74x30 | single 8-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x30.md) |
| 74x31 | hex delay elements (two 6ns, two 23-32ns, two 45-48ns) | Unknown | [excluded](spec/chips/ttl_74x31.md) |
| 74x32 | quad 2-input OR gate | Unknown | [implemented](spec/chips/ttl_74x32.md) |
| 74x33 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x33.md) |
| 74x34 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x34.md) |
| 74x35 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x35.md) |
| 74x36 | quad 2-input NOR gate (different pinout than 7402) | Unknown | [implemented](spec/chips/ttl_74x36.md) |
| 74x37 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x37.md) |
| 74x38 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x38.md) |
| 74x39 | quad 2-input NAND gate (different pinout than 7438) | Unknown | [implemented](spec/chips/ttl_74x39.md) |
| 74x40 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x40.md) |
| 74x41 | BCD to decimal decoder / Nixie tube driver | Unknown | [implemented](spec/chips/ttl_74x41.md) |
| 74x42 | BCD to decimal decoder | Unknown | [implemented](spec/chips/ttl_74x42.md) |
| 74x43 | excess-3 to decimal decoder | Unknown | [implemented](spec/chips/ttl_74x43.md) |
| 74x44 | Gray code to decimal decoder | Unknown | [implemented](spec/chips/ttl_74x44.md) |
| 74x45 | BCD to decimal decoder/driver | Unknown | [implemented](spec/chips/ttl_74x45.md) |
| 74x46 | BCD to 7-segment display decoder/driver | Unknown | [implemented](spec/chips/ttl_74x46.md) |
| 74x47 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x47.md) |
| 74x48 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x48.md) |
| 74x49 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x49.md) |
| 74x50 | dual 2-2-input AND-OR-Invert gate, one gate expandable | Unknown | [implemented](spec/chips/ttl_74x50.md) |
| 7451 | dual 2-2-input AND-OR-Invert (AOI) gate | Unknown | [implemented](spec/chips/ttl_7451.md) |
| 74L51 | 3-3-input AND-OR-Invert gate and 2-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74l51.md) |
| 74x52 | 3-2-2-2-input AND-OR gate, expandable with 74x61 | Unknown | [implemented](spec/chips/ttl_74x52.md) |
| 7453 | 2-2-2-2-input AND-OR-Invert gate, expandable | Unknown | [implemented](spec/chips/ttl_7453.md) |
| 74H53 | 3-2-2-2-input AND-OR-Invert gate, expandable | Unknown | [implemented](spec/chips/ttl_74h53.md) |
| 7454 | 2-2-2-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_7454.md) |
| 74H54 | 3-2-2-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74h54.md) |
| 74L54 | 3-3-2-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74l54.md) |
| 74x55 | 4-4-input AND-OR-Invert gate, 74H55 is expandable | Unknown | [implemented](spec/chips/ttl_74x55.md) |
| 74x56 | 50:1 frequency divider | Unknown | [implemented](spec/chips/ttl_74x56.md) |
| 74x57 | 60:1 frequency divider | Unknown | [implemented](spec/chips/ttl_74x57.md) |
| 74x58 | 3-3-input AND-OR gate and 2-2-input AND-OR gate | Unknown | [implemented](spec/chips/ttl_74x58.md) |
| 74x59 | dual 3-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74x59.md) |
| 74x60 | dual 4-input expander for 74x23, 74x50, 74x53, 74x55 | Unknown | [implemented](spec/chips/ttl_74x60.md) |
| 74x61 | triple 3-input expander for 74x52 | Unknown | [implemented](spec/chips/ttl_74x61.md) |
| 74x62 | 3-3-2-2-input AND-OR expander for 74x50, 74x53, 74x55 | Unknown | [implemented](spec/chips/ttl_74x62.md) |
| 74x63 | hex current sensing interface gates | Unknown | [implemented](spec/chips/ttl_74x63.md) |
| 74x64 | 4-3-2-2-input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74x64.md) |
| 74x65 | 4-3-2-2 input AND-OR-Invert gate | Unknown | [implemented](spec/chips/ttl_74x65.md) |
| 74x67 | AND gated J-K master-slave flip-flop, asynchronous preset and clear (improved 74L72) | Unknown | [implemented](spec/chips/ttl_74x67.md) |
| 74L68 | dual J-K flip-flop, asynchronous clear (improved 74L73) | Unknown | [implemented](spec/chips/ttl_74l68.md) |
| 74LS68 | dual 4-bit decade counters | Unknown | [implemented](spec/chips/ttl_74ls68.md) |
| 74L69 | dual J-K flip-flop, asynchronous preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74l69.md) |
| 74LS69 | dual 4-bit binary counters | Unknown | [implemented](spec/chips/ttl_74ls69.md) |
| 74x70 | AND-gated positive-edge-triggered J-K flip-flop, asynchronous preset and clear | Unknown | [implemented](spec/chips/ttl_74x70.md) |
| 74H71 | AND-OR-gated J-K master-slave flip-flop, preset | Unknown | [implemented](spec/chips/ttl_74h71.md) |
| 74L71 | AND-gated R-S master-slave flip-flop, preset and clear | Unknown | [implemented](spec/chips/ttl_74l71.md) |
| 74x72 | AND gated J-K master-slave flip-flop, asynchronous preset and clear | Unknown | [implemented](spec/chips/ttl_74x72.md) |
| 74x73 | dual J-K flip-flop, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x73.md) |
| 74x74 | dual D positive-edge-triggered flip-flop, asynchronous clear & preset, Q & /Q outputs | Unknown | [implemented](spec/chips/ttl_74x74.md) |
| 74x75 | 4-bit bistable latch, complementary outputs | Unknown | [implemented](spec/chips/ttl_74x75.md) |
| 74x76 | dual J-K flip-flop, asynchronous preset and clear | Unknown | [implemented](spec/chips/ttl_74x76.md) |
| 74x77 | 4-bit bistable latch | Unknown | [implemented](spec/chips/ttl_74x77.md) |
| 74H78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74h78.md) |
| 74L78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74l78.md) |
| 74LS78 | dual negative-edge-triggered J-K flip-flop, preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74ls78.md) |
| 74x79 | dual D positive-edge-triggered flip-flop, asynchronous preset and clear | Unknown | [implemented](spec/chips/ttl_74x79.md) |
| 74x80 | gated full adder | Unknown | [implemented](spec/chips/ttl_74x80.md) |
| 74x81 | 16-bit RAM | Unknown | [implemented](spec/chips/ttl_74x81.md) |
| 74x82 | 2-bit binary full adder | Unknown | [implemented](spec/chips/ttl_74x82.md) |
| 74x83 | 4-bit binary full adder | Unknown | [implemented](spec/chips/ttl_74x83.md) |
| 74x84 | 16-bit RAM | Unknown | [implemented](spec/chips/ttl_74x84.md) |
| 74x85 | 4-bit magnitude comparator | Unknown | [implemented](spec/chips/ttl_74x85.md) |
| 74x86 | quad 2-input XOR gate | Unknown | [implemented](spec/chips/ttl_74x86.md) |
| 74x87 | 4-bit true/complement/zero/one element | Unknown | [implemented](spec/chips/ttl_74x87.md) |
| 74x88 | 256-bit ROM (32x8) | Unknown | [implemented](spec/chips/ttl_74x88.md) |
| 74x89 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown | [implemented](spec/chips/ttl_74x89.md) |
| 74x90 | decade counter (separate divide-by-2 and divide-by-5 sections) | Unknown | [implemented](spec/chips/ttl_74x90.md) |
| 74x91 | 8-bit shift register, serial in, serial out, gated input | Unknown | [implemented](spec/chips/ttl_74x91.md) |
| 74x92 | divide-by-12 counter (separate divide-by-2 and divide-by-6 sections) | Unknown | [implemented](spec/chips/ttl_74x92.md) |
| 74x93 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections); different pinout for 74L93 | Unknown | [implemented](spec/chips/ttl_74x93.md) |
| 74x94 | 4-bit shift register, dual asynchronous presets | Unknown | [implemented](spec/chips/ttl_74x94.md) |
| 74x95 | 4-bit shift register, parallel in, parallel out, serial input; different pinout for 74L95 | Unknown | [implemented](spec/chips/ttl_74x95.md) |
| 74x96 | 5-bit parallel-in/parallel-out shift register, asynchronous preset | Unknown | [implemented](spec/chips/ttl_74x96.md) |
| 74x97 | synchronous 6-bit binary rate multiplier | Unknown | [implemented](spec/chips/ttl_74x97.md) |
| 74x98 | 4-bit data selector/storage register | Unknown | [implemented](spec/chips/ttl_74x98.md) |
| 74x99 | 4-bit bidirectional universal shift register | Unknown | [implemented](spec/chips/ttl_74x99.md) |
| 74x100 | dual 4-bit bistable latch | Unknown | [implemented](spec/chips/ttl_74x100.md) |
| 74x101 | AND-OR-gated J-K negative-edge-triggered flip-flop, preset | Unknown | [implemented](spec/chips/ttl_74x101.md) |
| 74x102 | AND-gated J-K negative-edge-triggered flip-flop, preset and clear | Unknown | [implemented](spec/chips/ttl_74x102.md) |
| 74x103 | dual J-K negative-edge-triggered flip-flop, clear | Unknown | [implemented](spec/chips/ttl_74x103.md) |
| 74x104 | J-K master-slave flip-flop | Unknown | [implemented](spec/chips/ttl_74x104.md) |
| 74x105 | J-K master-slave flip-flop, J2 and K2 inverted | Unknown | [implemented](spec/chips/ttl_74x105.md) |
| 74x106 | dual J-K negative-edge-triggered flip-flop, preset and clear | Unknown | [implemented](spec/chips/ttl_74x106.md) |
| 74x107 | dual J-K flip-flop, clear | Unknown | [implemented](spec/chips/ttl_74x107.md) |
| 74x108 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74x108.md) |
| 74x109 | dual J-NotK positive-edge-triggered flip-flop, clear and preset | Unknown | [implemented](spec/chips/ttl_74x109.md) |
| 74x110 | AND-gated J-K master-slave flip-flop, data lockout | Unknown | [implemented](spec/chips/ttl_74x110.md) |
| 74x111 | dual J-K master-slave flip-flop, data lockout, reset, set | Unknown | [implemented](spec/chips/ttl_74x111.md) |
| 74x112 | dual J-K negative-edge-triggered flip-flop, clear & preset, Q & /Q outputs | Unknown | [implemented](spec/chips/ttl_74x112.md) |
| 74x113 | dual J-K negative-edge-triggered flip-flop, preset | Unknown | [implemented](spec/chips/ttl_74x113.md) |
| 74x114 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74x114.md) |
| 74x115 | dual J-K master-slave flip-flop, data lockout, reset | Unknown | [implemented](spec/chips/ttl_74x115.md) |
| 74116 | dual 4-bit latch, clear | Unknown | [implemented](spec/chips/ttl_74116.md) |
| 74H116 | AND-gated J-K flip flop | Unknown | [implemented](spec/chips/ttl_74h116.md) |
| 74x117 | AND-gated J-K flip flop, one J and K input inverted | Unknown | [implemented](spec/chips/ttl_74x117.md) |
| 74x118 | hex set/reset latch, shared reset | Unknown | [implemented](spec/chips/ttl_74x118.md) |
| 74119 | hex set/reset latch | Unknown | [implemented](spec/chips/ttl_74119.md) |
| 74H119 | dual J-K flip-flop, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74h119.md) |
| 74120 | dual pulse synchronizer/drivers | Unknown | [implemented](spec/chips/ttl_74120.md) |
| 74H120 | dual J-K flip-flop, separate clock inputs | Unknown | [implemented](spec/chips/ttl_74h120.md) |
| 74x121 | monostable multivibrator | Unknown | [excluded](spec/chips/ttl_74x121.md) |
| 74x122 | retriggerable monostable multivibrator, clear | Unknown | [excluded](spec/chips/ttl_74x122.md) |
| 74x123 | dual retriggerable monostable multivibrator, clear | Unknown | [excluded](spec/chips/ttl_74x123.md) |
| 74x124 | dual voltage-controlled oscillator | Unknown | [excluded](spec/chips/ttl_74x124.md) |
| 74x125 | quad bus buffer, negative enable | Unknown | [implemented](spec/chips/ttl_74x125.md) |
| 74x126 | quad bus buffer, positive enable | Unknown | [implemented](spec/chips/ttl_74x126.md) |
| 74x128 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x128.md) |
| 74x130 | retriggerable monostable multivibrator | Unknown | [excluded](spec/chips/ttl_74x130.md) |
| 74131 | quad 2-input AND gate | Unknown | [implemented](spec/chips/ttl_74131.md) |
| 74x132 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x132.md) |
| 74x133 | single 13-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x133.md) |
| 74x134 | single 12-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x134.md) |
| 74x135 | quad XOR/XNOR gate, two inputs to select logic type | Unknown | [implemented](spec/chips/ttl_74x135.md) |
| 74x136 | quad 2-input XOR gate | Unknown | [implemented](spec/chips/ttl_74x136.md) |
| 74x137 | 3-to-8 line decoder/demultiplexer, address latch, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x137.md) |
| 74x138 | 3-to-8 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x138.md) |
| 74x139 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x139.md) |
| 74x140 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x140.md) |
| 74x141 | BCD to decimal decoder/driver for cold-cathode indicator / Nixie tube | Unknown | [implemented](spec/chips/ttl_74x141.md) |
| 74x142 | decade counter/latch/decoder/driver for Nixie tubes | Unknown | [implemented](spec/chips/ttl_74x142.md) |
| 74x143 | decade counter/latch/decoder/7-segment driver | Unknown | [implemented](spec/chips/ttl_74x143.md) |
| 74x144 | decade counter/latch/decoder/7-segment driver | Unknown | [implemented](spec/chips/ttl_74x144.md) |
| 74x145 | BCD to decimal decoder/driver | Unknown | [implemented](spec/chips/ttl_74x145.md) |
| 74x146 | 3-to-8 line decoder | Unknown | [implemented](spec/chips/ttl_74x146.md) |
| 74x147 | 10-line to 4-line priority encoder | Unknown | [implemented](spec/chips/ttl_74x147.md) |
| 74x148 | 8-line to 3-line priority encoder | Unknown | [implemented](spec/chips/ttl_74x148.md) |
| 74x149 | 8-line to 8-line priority encoder | Unknown | [implemented](spec/chips/ttl_74x149.md) |
| 74x150 | 16-line to 1-line data selector/multiplexer | Unknown | [implemented](spec/chips/ttl_74x150.md) |
| 74x151 | 8-line to 1-line data selector/multiplexer | Unknown | [implemented](spec/chips/ttl_74x151.md) |
| 74x152 | 8-line to 1-line data selector/multiplexer, inverting output | Unknown | [implemented](spec/chips/ttl_74x152.md) |
| 74x153 | dual 4-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x153.md) |
| 74x154 | 4-to-16 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x154.md) |
| 74x155 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x155.md) |
| 74x156 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x156.md) |
| 74x157 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x157.md) |
| 74x158 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x158.md) |
| 74x159 | 4-to-16 line decoder/demultiplexer | Unknown | [implemented](spec/chips/ttl_74x159.md) |
| 74x160 | synchronous presettable 4-bit decade counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x160.md) |
| 74x161 | synchronous presettable 4-bit binary counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x161.md) |
| 74x162 | synchronous presettable 4-bit decade counter, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x162.md) |
| 74x163 | synchronous presettable 4-bit binary counter, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x163.md) |
| 74x164 | 8-bit serial-in parallel-out (SIPO) shift register, asynchronous clear, not output latch | Unknown | [implemented](spec/chips/ttl_74x164.md) |
| 74x165 | 8-bit parallel-in serial-out (PISO) shift register, parallel load, complementary outputs | Unknown | [implemented](spec/chips/ttl_74x165.md) |
| 74x166 | parallel-load 8-bit shift register | Unknown | [implemented](spec/chips/ttl_74x166.md) |
| 74x167 | synchronous decade rate multiplier | Unknown | [implemented](spec/chips/ttl_74x167.md) |
| 74x168 | synchronous presettable 4-bit up/down decade counter | Unknown | [implemented](spec/chips/ttl_74x168.md) |
| 74x169 | synchronous presettable 4-bit up/down binary counter | Unknown | [implemented](spec/chips/ttl_74x169.md) |
| 74x170 | 16-bit register file (4x4) | Unknown | [implemented](spec/chips/ttl_74x170.md) |
| 74x171 | quad D flip-flops, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74x171.md) |
| 74x172 | 16-bit multiple port register file (8x2) | Unknown | [implemented](spec/chips/ttl_74x172.md) |
| 74x173 | quad D flip-flop, shared clock and asynchronous clear and enable, Q & /Q outputs | Unknown | [implemented](spec/chips/ttl_74x173.md) |
| 74x174 | hex D flip-flop, shared clock and asynchronous clear, Q outputs | Unknown | [implemented](spec/chips/ttl_74x174.md) |
| 74x175 | quad D edge-triggered flip-flop, shared clock and asynchronous clear, Q & /Q outputs | Unknown | [implemented](spec/chips/ttl_74x175.md) |
| 74x176 | presettable decade (bi-quinary) counter/latch | Unknown | [implemented](spec/chips/ttl_74x176.md) |
| 74x177 | presettable binary counter/latch | Unknown | [implemented](spec/chips/ttl_74x177.md) |
| 74x178 | 4-bit parallel-access shift register | Unknown | [implemented](spec/chips/ttl_74x178.md) |
| 74x179 | 4-bit parallel-access shift register, asynchronous clear input, complementary Q output | Unknown | [implemented](spec/chips/ttl_74x179.md) |
| 74x180 | 9-bit odd/even parity bit generator and checker | Unknown | [implemented](spec/chips/ttl_74x180.md) |
| 74x181 | 4-bit arithmetic logic unit and function generator | 1970 | [implemented](spec/chips/ttl_74x181.md) |
| 74x182 | lookahead carry generator | Unknown | [implemented](spec/chips/ttl_74x182.md) |
| 74x183 | dual carry-save full adder | Unknown | [implemented](spec/chips/ttl_74x183.md) |
| 74x184 | BCD to binary converter | Unknown | [implemented](spec/chips/ttl_74x184.md) |
| 74x185 | 6-bit binary to BCD converter | Unknown | [implemented](spec/chips/ttl_74x185.md) |
| 74x186 | 512-bit ROM (64x8) | Unknown | [implemented](spec/chips/ttl_74x186.md) |
| 74x187 | 1024-bit ROM (256x4) | Unknown | [implemented](spec/chips/ttl_74x187.md) |
| 74x188 | 256-bit PROM (32x8) | Unknown | [implemented](spec/chips/ttl_74x188.md) |
| 74x189 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown | [implemented](spec/chips/ttl_74x189.md) |
| 74x190 | synchronous presettable up/down 4-bit decade counter | Unknown | [implemented](spec/chips/ttl_74x190.md) |
| 74x191 | synchronous presettable up/down 4-bit binary counter | Unknown | [implemented](spec/chips/ttl_74x191.md) |
| 74x192 | synchronous presettable up/down 4-bit decade counter, clear | Unknown | [implemented](spec/chips/ttl_74x192.md) |
| 74x193 | synchronous presettable up/down 4-bit binary counter, clear | Unknown | [implemented](spec/chips/ttl_74x193.md) |
| 74x194 | 4-bit bidirectional universal shift register | Unknown | [implemented](spec/chips/ttl_74x194.md) |
| 74x195 | 4-bit parallel-access shift register | Unknown | [implemented](spec/chips/ttl_74x195.md) |
| 74x196 | presettable 4-bit decade counter/latch | Unknown | [implemented](spec/chips/ttl_74x196.md) |
| 74x197 | presettable 4-bit binary counter/latch | Unknown | [implemented](spec/chips/ttl_74x197.md) |
| 74x198 | 8-bit bidirectional universal shift register | Unknown | [implemented](spec/chips/ttl_74x198.md) |
| 74x199 | 8-bit universal shift register, J-NotK serial inputs | Unknown | [implemented](spec/chips/ttl_74x199.md) |
| 74x200 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x200.md) |
| 74x201 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x201.md) |
| 74x202 | 256-bit RAM (256x1) with power down | Unknown | [implemented](spec/chips/ttl_74x202.md) |
| 74x206 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x206.md) |
| 74x207 | 1024-bit RAM (256x4) | Unknown | [implemented](spec/chips/ttl_74x207.md) |
| 74x208 | 1024-bit RAM (256x4), separate data in- and outputs | Unknown | [implemented](spec/chips/ttl_74x208.md) |
| 74x209 | 1024-bit RAM (1024x1) | Unknown | [implemented](spec/chips/ttl_74x209.md) |
| 74x210 | octal buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x210.md) |
| 74x211 | 144-bit RAM (16x9) with output latch | Unknown | [implemented](spec/chips/ttl_74x211.md) |
| 74x212 | 144-bit RAM (16x9) | Unknown | [implemented](spec/chips/ttl_74x212.md) |
| 74x213 | 192-bit RAM (16x12) | Unknown | [implemented](spec/chips/ttl_74x213.md) |
| 74x214 | 1024-bit RAM (1024x1) | Unknown | [implemented](spec/chips/ttl_74x214.md) |
| 74x215 | 1024-bit RAM (1024x1) with power-down mode | Unknown | [implemented](spec/chips/ttl_74x215.md) |
| 74x216 | 256-bit RAM (64x4), common I/O | Unknown | [implemented](spec/chips/ttl_74x216.md) |
| 74x217 | 256-bit RAM (64x4) | Unknown | [implemented](spec/chips/ttl_74x217.md) |
| 74x218 | 256-bit RAM (32x8) | Unknown | [implemented](spec/chips/ttl_74x218.md) |
| 74x219 | 64-bit RAM (16x4), non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x219.md) |
| 74x221 | dual monostable multivibrator | Unknown | [excluded](spec/chips/ttl_74x221.md) |
| 74x222 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | Unknown | [implemented](spec/chips/ttl_74x222.md) |
| 74x224 | 64-bit FIFO memory (16x4), synchronous | Unknown | [implemented](spec/chips/ttl_74x224.md) |
| 74x225 | 80-bit FIFO memory (16x5), asynchronous | Unknown | [implemented](spec/chips/ttl_74x225.md) |
| 74x226 | 4-bit parallel latched bus transceiver | Unknown | [implemented](spec/chips/ttl_74x226.md) |
| 74x227 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | Unknown | [implemented](spec/chips/ttl_74x227.md) |
| 74x228 | 64-bit FIFO memory (16x4), synchronous | Unknown | [implemented](spec/chips/ttl_74x228.md) |
| 74x229 | 80-bit FIFO memory (16x5), asynchronous | Unknown | [implemented](spec/chips/ttl_74x229.md) |
| 74x230 | dual 4-bit buffer/driver, one inverted, one non-inverted; negative enable | Unknown | [implemented](spec/chips/ttl_74x230.md) |
| 74x231 | dual 4-bit buffer/driver, both inverted; one positive and one negative enable | Unknown | [implemented](spec/chips/ttl_74x231.md) |
| 74x232 | 64-bit FIFO memory (16x4), asynchronous | Unknown | [implemented](spec/chips/ttl_74x232.md) |
| 74x233 | 80-bit FIFO memory (16x5), asynchronous | Unknown | [implemented](spec/chips/ttl_74x233.md) |
| 74x234 | 256-bit FIFO memory (64x4), asynchronous | Unknown | [implemented](spec/chips/ttl_74x234.md) |
| 74x235 | 320-bit FIFO memory (64x5), asynchronous | Unknown | [implemented](spec/chips/ttl_74x235.md) |
| 74x236 | 256-bit FIFO memory (64x4), asynchronous | Unknown | [implemented](spec/chips/ttl_74x236.md) |
| 74x237 | 3-to-8 line decoder/demultiplexer, address latch, active high outputs | Unknown | [implemented](spec/chips/ttl_74x237.md) |
| 74x238 | 3-to-8 line decoder/demultiplexer, active high outputs | Unknown | [implemented](spec/chips/ttl_74x238.md) |
| 74x239 | dual 2-to-4 line decoder/demultiplexer, active high outputs | Unknown | [implemented](spec/chips/ttl_74x239.md) |
| 74x240 | octal buffer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x240.md) |
| 74x241 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x241.md) |
| 74x242 | quad bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x242.md) |
| 74x243 | quad bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x243.md) |
| 74x244 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x244.md) |
| 74x245 | octal bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x245.md) |
| 74x246 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x246.md) |
| 74x247 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x247.md) |
| 74x248 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x248.md) |
| 74x249 | BCD to 7-segment decoder/driver | Unknown | [implemented](spec/chips/ttl_74x249.md) |
| 74x250 | 1 of 16 data selector/multiplexer | Unknown | [implemented](spec/chips/ttl_74x250.md) |
| 74x251 | 8-line to 1-line data selector/multiplexer, complementary outputs | Unknown | [implemented](spec/chips/ttl_74x251.md) |
| 74x253 | dual 4-line to 1-line data selector/multiplexer | Unknown | [implemented](spec/chips/ttl_74x253.md) |
| 74x255 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x255.md) |
| 74x256 | dual 4-bit addressable latch | Unknown | [implemented](spec/chips/ttl_74x256.md) |
| 74x257 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x257.md) |
| 74x258 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x258.md) |
| 74x259 | 8-bit bit addressable input latch with clr | Unknown | [implemented](spec/chips/ttl_74x259.md) |
| 74x260 | dual 5-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x260.md) |
| 74x261 | 2-bit by 4-bit parallel binary multiplier | Unknown | [implemented](spec/chips/ttl_74x261.md) |
| 74x262 | 5760-bit read-only character memory (128 by 45-bit bitmaps) | Unknown | [implemented](spec/chips/ttl_74x262.md) |
| 74x264 | look ahead carry generator | Unknown | [implemented](spec/chips/ttl_74x264.md) |
| 74x265 | quad complementary output elements | Unknown | [implemented](spec/chips/ttl_74x265.md) |
| 74x266 | quad 2-input XNOR gate | Unknown | [implemented](spec/chips/ttl_74x266.md) |
| 74x268 | hex D-type latches, shared enable and output control | Unknown | [implemented](spec/chips/ttl_74x268.md) |
| 74x269 | 8-bit bidirectional binary counter | Unknown | [implemented](spec/chips/ttl_74x269.md) |
| 74x270 | 2048-bit ROM (512x4) | Unknown | [implemented](spec/chips/ttl_74x270.md) |
| 74x271 | 2048-bit ROM (256x8) | Unknown | [implemented](spec/chips/ttl_74x271.md) |
| 74x273 | 8-bit register, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x273.md) |
| 74x274 | 4-bit by 4-bit binary multiplier | Unknown | [implemented](spec/chips/ttl_74x274.md) |
| 74x275 | 7-bit slice Wallace tree | Unknown | [implemented](spec/chips/ttl_74x275.md) |
| 74x276 | quad J-NotK edge-triggered flip-flops, separate clocks, shared preset and clear | Unknown | [implemented](spec/chips/ttl_74x276.md) |
| 74x278 | 4-bit cascadeable priority registers, latched data inputs | Unknown | [implemented](spec/chips/ttl_74x278.md) |
| 74x279 | quad set-reset latch | Unknown | [implemented](spec/chips/ttl_74x279.md) |
| 74x280 | 9-bit odd/even parity bit generator/checker | Unknown | [implemented](spec/chips/ttl_74x280.md) |
| 74x281 | 4-bit parallel binary accumulator | Unknown | [implemented](spec/chips/ttl_74x281.md) |
| 74x282 | look-ahead carry generator, selectable carry inputs | Unknown | [implemented](spec/chips/ttl_74x282.md) |
| 74x283 | 4-bit binary full adder (has carry in function) | Unknown | [implemented](spec/chips/ttl_74x283.md) |
| 74x284 | 4-bit by 4-bit parallel binary multiplier (high order 4 bits of product) | Unknown | [implemented](spec/chips/ttl_74x284.md) |
| 74x285 | 4-bit by 4-bit parallel binary multiplier (low order 4 bits of product) | Unknown | [implemented](spec/chips/ttl_74x285.md) |
| 74x286 | 9-bit parity generator/checker, bus driver parity I/O port | Unknown | [implemented](spec/chips/ttl_74x286.md) |
| 74x287 | 1024-bit PROM (256x4) | Unknown | [implemented](spec/chips/ttl_74x287.md) |
| 74x288 | 256-bit PROM (32x8) | Unknown | [implemented](spec/chips/ttl_74x288.md) |
| 74x289 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown | [implemented](spec/chips/ttl_74x289.md) |
| 74x290 | decade counter (separate divide-by-2 and divide-by-5 sections) | Unknown | [implemented](spec/chips/ttl_74x290.md) |
| 74x292 | programmable frequency divider/digital timer | Unknown | [implemented](spec/chips/ttl_74x292.md) |
| 74x293 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections) | Unknown | [implemented](spec/chips/ttl_74x293.md) |
| 74x294 | programmable frequency divider/digital timer | Unknown | [implemented](spec/chips/ttl_74x294.md) |
| 74x295 | 4-bit bidirectional shift register | Unknown | [implemented](spec/chips/ttl_74x295.md) |
| 74x297 | digital phase-locked loop filter | Unknown | [implemented](spec/chips/ttl_74x297.md) |
| 74x298 | quad 2-input multiplexer, storage | Unknown | [implemented](spec/chips/ttl_74x298.md) |
| 74x299 | 8-bit bidirectional universal shift/storage register | Unknown | [implemented](spec/chips/ttl_74x299.md) |
| 74x300 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x300.md) |
| 74x301 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x301.md) |
| 74x302 | 256-bit RAM (256x1) | Unknown | [implemented](spec/chips/ttl_74x302.md) |
| 74x303 | octal divide-by-2 clock driver, 2 outputs inverted | Unknown | [implemented](spec/chips/ttl_74x303.md) |
| 74x304 | octal divide-by-2 clock driver | Unknown | [implemented](spec/chips/ttl_74x304.md) |
| 74x305 | octal divide-by-2 clock driver, 4 outputs inverted | Unknown | [implemented](spec/chips/ttl_74x305.md) |
| 74x306 | 8-bit LV-TTL to GTL+ bus transceiver | Unknown | [implemented](spec/chips/ttl_74x306.md) |
| 74x309 | 1024-bit RAM (1024x1) | Unknown | [implemented](spec/chips/ttl_74x309.md) |
| 74x310 | octal buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x310.md) |
| 74x311 | 144-bit RAM (16x9) with output latch | Unknown | [implemented](spec/chips/ttl_74x311.md) |
| 74x312 | 144-bit RAM (16x9) | Unknown | [implemented](spec/chips/ttl_74x312.md) |
| 74x313 | 192-bit RAM (16x12) | Unknown | [implemented](spec/chips/ttl_74x313.md) |
| 74x314 | 1024-bit RAM (1024x1) | Unknown | [implemented](spec/chips/ttl_74x314.md) |
| 74x315 | 1024-bit RAM (1024x1) with power-down mode | Unknown | [implemented](spec/chips/ttl_74x315.md) |
| 74x316 | 256-bit RAM (64x4), common I/O | Unknown | [implemented](spec/chips/ttl_74x316.md) |
| 74x317 | 256-bit RAM (64x4) | Unknown | [implemented](spec/chips/ttl_74x317.md) |
| 74x318 | 256-bit RAM (32x8) | Unknown | [implemented](spec/chips/ttl_74x318.md) |
| 74x319 | 64-bit RAM (16x4) | Unknown | [implemented](spec/chips/ttl_74x319.md) |
| 74x320 | crystal-controlled oscillator | Unknown | [excluded](spec/chips/ttl_74x320.md) |
| 74x321 | crystal-controlled oscillators, F/2 and F/4 count-down outputs | Unknown | [excluded](spec/chips/ttl_74x321.md) |
| 74x322 | 8-bit shift register, sign extend | Unknown | [implemented](spec/chips/ttl_74x322.md) |
| 74x323 | 8-bit bidirectional universal shift/storage register, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x323.md) |
| 74x324 | voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs | Unknown | [excluded](spec/chips/ttl_74x324.md) |
| 74x325 | dual voltage-controlled oscillator (or crystal controlled), complementary outputs | Unknown | [excluded](spec/chips/ttl_74x325.md) |
| 74x326 | dual voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs | Unknown | [excluded](spec/chips/ttl_74x326.md) |
| 74x327 | dual voltage-controlled oscillator (or crystal controlled) | Unknown | [excluded](spec/chips/ttl_74x327.md) |
| 74x330 | PLA (12 inputs, 50 terms, 6 outputs) | Unknown | [implemented](spec/chips/ttl_74x330.md) |
| 74x331 | PLA (12 inputs, 50 terms, 6 outputs) | Unknown | [implemented](spec/chips/ttl_74x331.md) |
| 74x333 | PLA (12 inputs, 32 terms, 6 outputs, 4 state registers) | Unknown | [implemented](spec/chips/ttl_74x333.md) |
| 74x334 | PLA (12 inputs, 32 terms, 6 outputs) | Unknown | [implemented](spec/chips/ttl_74x334.md) |
| 74x335 | PLA (12 inputs, 32 terms, 6 outputs, 4 state registers) | Unknown | [implemented](spec/chips/ttl_74x335.md) |
| 74x336 | PLA (12 inputs, 32 terms, 6 outputs) | Unknown | [implemented](spec/chips/ttl_74x336.md) |
| 74x337 | clock driver | Unknown | [implemented](spec/chips/ttl_74x337.md) |
| 74x340 | octal buffer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x340.md) |
| 74x341 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x341.md) |
| 74x344 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x344.md) |
| 74x347 | BCD to 7-segment decoders/drivers, low voltage version of 7447 | Unknown | [implemented](spec/chips/ttl_74x347.md) |
| 74x348 | 8 to 3-line priority encoder | Unknown | [implemented](spec/chips/ttl_74x348.md) |
| 74x350 | 4-bit shifter | Unknown | [implemented](spec/chips/ttl_74x350.md) |
| 74x351 | dual 8-line to 1-line data selectors/multiplexers, 4 common data inputs | Unknown | [implemented](spec/chips/ttl_74x351.md) |
| 74x352 | dual 4-line to 1-line data selectors/multiplexers, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x352.md) |
| 74x353 | dual 4-line to 1-line data selectors/multiplexers, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x353.md) |
| 74x354 | 8-line to 1-line data selector/multiplexer, transparent registers | Unknown | [implemented](spec/chips/ttl_74x354.md) |
| 74x355 | 8-line to 1-line data selector/multiplexer, transparent registers | Unknown | [implemented](spec/chips/ttl_74x355.md) |
| 74x356 | 8-line to 1-line data selector/multiplexer, edge-triggered registers | Unknown | [implemented](spec/chips/ttl_74x356.md) |
| 74x357 | 8-line to 1-line data selector/multiplexer, edge-triggered registers | Unknown | [implemented](spec/chips/ttl_74x357.md) |
| 74x361 | bubble memory function timing generator | Unknown | [pending](spec/chips/ttl_74x361.md) |
| 74x362 | four-phase clock generator/driver for Texas Instruments TMS9900 | Unknown | [implemented](spec/chips/ttl_74x362.md) |
| 74x363 | octal transparent latch | Unknown | [implemented](spec/chips/ttl_74x363.md) |
| 74x364 | octal edge-triggered D-type register | Unknown | [implemented](spec/chips/ttl_74x364.md) |
| 74x365 | hex buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x365.md) |
| 74x366 | hex buffer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x366.md) |
| 74x367 | hex buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x367.md) |
| 74x368 | hex buffer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x368.md) |
| 74x370 | 2048-bit ROM (512x4) | Unknown | [implemented](spec/chips/ttl_74x370.md) |
| 74x371 | 2048-bit ROM (256x8) | Unknown | [implemented](spec/chips/ttl_74x371.md) |
| 74x373 | octal transparent latch | Unknown | [implemented](spec/chips/ttl_74x373.md) |
| 74x374 | octal register | Unknown | [implemented](spec/chips/ttl_74x374.md) |
| 74x375 | quad bistable latch | Unknown | [implemented](spec/chips/ttl_74x375.md) |
| 74x376 | quad J-NotK flip-flop, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74x376.md) |
| 74x377 | 8-bit register, clock enable | Unknown | [implemented](spec/chips/ttl_74x377.md) |
| 74x378 | 6-bit register, clock enable | Unknown | [implemented](spec/chips/ttl_74x378.md) |
| 74x379 | 4-bit register, clock enable and complementary outputs | Unknown | [implemented](spec/chips/ttl_74x379.md) |
| 74x380 | 8-bit multifunction register (combines features of x374, x377, x273, x534 ICs) | Unknown | [implemented](spec/chips/ttl_74x380.md) |
| 74x381 | 4-bit arithmetic logic unit/function generator, generate and propagate outputs | Unknown | [implemented](spec/chips/ttl_74x381.md) |
| 74x382 | 4-bit arithmetic logic unit/function generator, ripple carry and overflow outputs | Unknown | [implemented](spec/chips/ttl_74x382.md) |
| 74x383 | 8-bit register | Unknown | [implemented](spec/chips/ttl_74x383.md) |
| 74x384 | 8-bit by 1-bit two's complement multipliers | Unknown | [implemented](spec/chips/ttl_74x384.md) |
| 74x385 | quad serial adder/subtractor | Unknown | [implemented](spec/chips/ttl_74x385.md) |
| 74x386 | quad 2-input XOR gate | Unknown | [implemented](spec/chips/ttl_74x386.md) |
| 74x387 | 1024-bit PROM (256x4) | Unknown | [implemented](spec/chips/ttl_74x387.md) |
| 74x388 | 4-bit D-type register | Unknown | [implemented](spec/chips/ttl_74x388.md) |
| 74x390 | dual 4-bit decade counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x390.md) |
| 74x393 | dual 4-bit binary counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x393.md) |
| 74x395 | 4-bit cascadable shift register | Unknown | [implemented](spec/chips/ttl_74x395.md) |
| 74x396 | octal storage registers, parallel access | Unknown | [implemented](spec/chips/ttl_74x396.md) |
| 74x398 | quad 2-input multiplexers, storage and complementary outputs | Unknown | [implemented](spec/chips/ttl_74x398.md) |
| 74x399 | quad 2-input multiplexer, storage | Unknown | [implemented](spec/chips/ttl_74x399.md) |
| 74x401 | CRC generator/checker | Unknown | [implemented](spec/chips/ttl_74x401.md) |
| 74x402 | serial data polynomial generator/checker | Unknown | [implemented](spec/chips/ttl_74x402.md) |
| 74x403 | 64-bit FIFO memory (16x4) | Unknown | [implemented](spec/chips/ttl_74x403.md) |
| 74x405 | 3-to-8 line decoder (equivalent to Intel 8205) | Unknown | [implemented](spec/chips/ttl_74x405.md) |
| 74406 | 3-to-8 line decoder | Unknown | [implemented](spec/chips/ttl_74406.md) |
| 74x407 | data access register | Unknown | [implemented](spec/chips/ttl_74x407.md) |
| 74408 | 8-bit parity tree | Unknown | [implemented](spec/chips/ttl_74408.md) |
| 74S408 | controller/driver for 16k/64k/256k dRAM | Unknown | [pending](spec/chips/ttl_74s408.md) |
| 74x409 | controller/driver for 16k/64k/256k dRAM | Unknown | [implemented](spec/chips/ttl_74x409.md) |
| 74x410 | 64-bit RAM (16x4) with output register | Unknown | [implemented](spec/chips/ttl_74x410.md) |
| 74x411 | FIFO RAM controller | Unknown | [implemented](spec/chips/ttl_74x411.md) |
| 74x412 | multi-mode buffered 8-bit latches (equivalent to Intel 3212/8212) | Unknown | [implemented](spec/chips/ttl_74x412.md) |
| 74x413 | 256-bit FIFO memory (64x4) | Unknown | [implemented](spec/chips/ttl_74x413.md) |
| 74x414 | interrupt priority controller for Intel 8080 (equivalent to Intel 8214) | Unknown | [implemented](spec/chips/ttl_74x414.md) |
| 74416 | modulo 10 counter, preload and clear inputs | Unknown | [implemented](spec/chips/ttl_74416.md) |
| 74S416 | 4-bit bidirectional bus transceiver, non-inverting (equivalent to Intel 8216) | Unknown | [implemented](spec/chips/ttl_74s416.md) |
| 74x417 | modulo 2 and modulo 5 counters, shared preload and clear inputs | Unknown | [implemented](spec/chips/ttl_74x417.md) |
| 74418 | modulo 16 counter, preload and clear inputs | Unknown | [implemented](spec/chips/ttl_74418.md) |
| 74419 | dual modulo 4 counters, shared preload and clear inputs | Unknown | [implemented](spec/chips/ttl_74419.md) |
| 74S419 | FIFO RAM controller | Unknown | [implemented](spec/chips/ttl_74s419.md) |
| 74x420 | 32-bit check bit / syndrome bit generator | Unknown | [implemented](spec/chips/ttl_74x420.md) |
| 74x422 | retriggerable monostable multivibrators, two inputs | Unknown | [excluded](spec/chips/ttl_74x422.md) |
| 74x423 | dual retriggerable monostable multivibrator | Unknown | [excluded](spec/chips/ttl_74x423.md) |
| 74424 | dual voltage-controlled oscillator | Unknown | [excluded](spec/chips/ttl_74424.md) |
| 74LS424 | two-phase clock generator/driver for Intel 8080 (equivalent to Intel 8224) | Unknown | [implemented](spec/chips/ttl_74ls424.md) |
| 74x425 | quad bus buffers, active low enables | Unknown | [implemented](spec/chips/ttl_74x425.md) |
| 74x426 | quad bus buffers, active high enables | Unknown | [implemented](spec/chips/ttl_74x426.md) |
| 74x428 | system controller for Intel 8080A (equivalent to Intel 8228) | Unknown | [implemented](spec/chips/ttl_74x428.md) |
| 74x429 | FIFO RAM controller | Unknown | [implemented](spec/chips/ttl_74x429.md) |
| 74x430 | cyclic redundancy checker/corrector | Unknown | [pending](spec/chips/ttl_74x430.md) |
| 74x432 | 8-bit multi-mode buffered latch | Unknown | [implemented](spec/chips/ttl_74x432.md) |
| 74x433 | 256-bit FIFO memory (64x4) | Unknown | [implemented](spec/chips/ttl_74x433.md) |
| 74x436 | line driver/memory driver circuits - MOS memory interface, damping output resistor | Unknown | [implemented](spec/chips/ttl_74x436.md) |
| 74x437 | line driver/memory driver circuits - MOS memory interface | Unknown | [implemented](spec/chips/ttl_74x437.md) |
| 74x438 | system controller for Intel 8080A (equivalent to Intel 8238) | Unknown | [implemented](spec/chips/ttl_74x438.md) |
| 74x440 | quad tridirectional bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x440.md) |
| 74x441 | quad tridirectional bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x441.md) |
| 74x442 | quad tridirectional bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x442.md) |
| 74x443 | quad tridirectional bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x443.md) |
| 74x444 | quad tridirectional bus transceiver, inverting and non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x444.md) |
| 74x445 | BCD to decimal decoders/drivers | Unknown | [implemented](spec/chips/ttl_74x445.md) |
| 74x446 | quad bus transceivers, direction controls, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x446.md) |
| 74x447 | BCD to 7-segment decoders/drivers, low voltage version of 74247 | Unknown | [implemented](spec/chips/ttl_74x447.md) |
| 74x448 | quad tridirectional bus transceiver, inverting and non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x448.md) |
| 74x449 | quad bus transceivers, direction controls, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x449.md) |
| 74450 | counter, latch, 7-segment decoder | Unknown | [implemented](spec/chips/ttl_74450.md) |
| 74S450 | 8192-bit PROM (1024x8) with power-down | Unknown | [implemented](spec/chips/ttl_74s450.md) |
| 74LS450 | 16-to-1 multiplexer, complementary outputs | Unknown | [implemented](spec/chips/ttl_74ls450.md) |
| 74S451 | 8192-bit PROM (1024x8) with power-down | Unknown | [implemented](spec/chips/ttl_74s451.md) |
| 74LS451 | dual 8-to-1 multiplexer | Unknown | [implemented](spec/chips/ttl_74ls451.md) |
| 74x452 | dual decade counter, synchronous | Unknown | [implemented](spec/chips/ttl_74x452.md) |
| 74453 | dual binary counter, synchronous | Unknown | [implemented](spec/chips/ttl_74453.md) |
| 74LS453 | quad 4-to-1 multiplexer | Unknown | [implemented](spec/chips/ttl_74ls453.md) |
| 74x454 | dual decade up/down counter, synchronous, preset input | Unknown | [implemented](spec/chips/ttl_74x454.md) |
| 74455 | dual binary up/down counter, synchronous, preset input | Unknown | [implemented](spec/chips/ttl_74455.md) |
| 74456 | 4-bit NBCD full adder | Unknown | [implemented](spec/chips/ttl_74456.md) |
| 74x458 | nines complement / zero element | Unknown | [implemented](spec/chips/ttl_74x458.md) |
| 74460 | 4-bit bus transfer switch | Unknown | [implemented](spec/chips/ttl_74460.md) |
| 74LS460 | 10-bit comparator | Unknown | [implemented](spec/chips/ttl_74ls460.md) |
| 74x461 | 8-bit presettable binary counter | Unknown | [implemented](spec/chips/ttl_74x461.md) |
| 74x462 | fiber-optic data-link transmitter | Unknown | [excluded](spec/chips/ttl_74x462.md) |
| 74x463 | fiber-optic data-link receiver | Unknown | [excluded](spec/chips/ttl_74x463.md) |
| 74x465 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x465.md) |
| 74x466 | octal buffers, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x466.md) |
| 74x467 | octal buffers, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x467.md) |
| 74x468 | octal buffers, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x468.md) |
| 74x469 | 8-bit synchronous up/down counter, parallel load and hold capability | Unknown | [implemented](spec/chips/ttl_74x469.md) |
| 74x470 | 2048-bit PROM (256x8) | Unknown | [implemented](spec/chips/ttl_74x470.md) |
| 74x471 | 2048-bit PROM (256x8) | Unknown | [implemented](spec/chips/ttl_74x471.md) |
| 74x472 | 4096-bit PROM (512x8) | Unknown | [implemented](spec/chips/ttl_74x472.md) |
| 74x473 | 4096-bit PROM (512x8) | Unknown | [implemented](spec/chips/ttl_74x473.md) |
| 74x474 | 4096-bit PROM (512x8) | Unknown | [implemented](spec/chips/ttl_74x474.md) |
| 74x475 | 4096-bit PROM (512x8) | Unknown | [implemented](spec/chips/ttl_74x475.md) |
| 74x476 | 4096-bit PROM (1024x4) | Unknown | [implemented](spec/chips/ttl_74x476.md) |
| 74x477 | 4096-bit PROM (1024x4) | Unknown | [implemented](spec/chips/ttl_74x477.md) |
| 74x478 | 8192-bit PROM (1024x8) | Unknown | [implemented](spec/chips/ttl_74x478.md) |
| 74x479 | 8192-bit PROM (1024x8) | Unknown | [implemented](spec/chips/ttl_74x479.md) |
| 74x480 | single burst error recovery circuit | Unknown | [implemented](spec/chips/ttl_74x480.md) |
| 74x481 | 4-bit slice cascadable processor elements | Unknown | [implemented](spec/chips/ttl_74x481.md) |
| 74x482 | 4-bit slice expandable control elements | Unknown | [implemented](spec/chips/ttl_74x482.md) |
| 74x484 | BCD-to-binary converter | Unknown | [implemented](spec/chips/ttl_74x484.md) |
| 74x485 | binary-to-BCD converter | Unknown | [implemented](spec/chips/ttl_74x485.md) |
| 74x488 | IEEE-488 bus interface | Unknown | [implemented](spec/chips/ttl_74x488.md) |
| 74x490 | dual decade counter | Unknown | [implemented](spec/chips/ttl_74x490.md) |
| 74x491 | 10-bit binary up/down counter, limited preset | Unknown | [implemented](spec/chips/ttl_74x491.md) |
| 74x498 | 8-bit bidirectional shift register, parallel inputs | Unknown | [implemented](spec/chips/ttl_74x498.md) |
| 74x500 | 6-bit flash analog-to-digital converter (ADC) | Unknown | [excluded](spec/chips/ttl_74x500.md) |
| 74x502 | 8-bit successive approximation register | Unknown | [implemented](spec/chips/ttl_74x502.md) |
| 74x503 | 8-bit successive approximation register with expansion control | Unknown | [implemented](spec/chips/ttl_74x503.md) |
| 74x504 | 12-bit successive approximation register with expansion control | Unknown | [implemented](spec/chips/ttl_74x504.md) |
| 74x505 | 8-bit successive approximation ADC | Unknown | [excluded](spec/chips/ttl_74x505.md) |
| 74x508 | 8-bit multiplier/divider | Unknown | [implemented](spec/chips/ttl_74x508.md) |
| 74x515 | programmable mapping decoder (2-to-4 line decoder with 9 programmable enable inputs) | Unknown | [implemented](spec/chips/ttl_74x515.md) |
| 74x516 | 16-bit multiplier/divider | Unknown | [implemented](spec/chips/ttl_74x516.md) |
| 74x518 | 8-bit comparator | Unknown | [implemented](spec/chips/ttl_74x518.md) |
| 74x519 | 8-bit comparator | Unknown | [implemented](spec/chips/ttl_74x519.md) |
| 74x520 | 8-bit comparator, inverting output | Unknown | [implemented](spec/chips/ttl_74x520.md) |
| 74x521 | 8-bit comparator, inverting output | Unknown | [implemented](spec/chips/ttl_74x521.md) |
| 74x522 | 8-bit comparator, inverting output | Unknown | [implemented](spec/chips/ttl_74x522.md) |
| 74x524 | 8-bit registered comparator | Unknown | [implemented](spec/chips/ttl_74x524.md) |
| 74x525 | 16-bit programmable counter | Unknown | [implemented](spec/chips/ttl_74x525.md) |
| 74x526 | fuse programmable identity comparator, 16-bit | Unknown | [implemented](spec/chips/ttl_74x526.md) |
| 74x527 | fuse programmable identity comparator, 8-bit + 4-bit conventional Identity comparator | Unknown | [implemented](spec/chips/ttl_74x527.md) |
| 74x528 | fuse programmable Identity comparator, 12-bit | Unknown | [implemented](spec/chips/ttl_74x528.md) |
| 74x531 | octal transparent latch | Unknown | [implemented](spec/chips/ttl_74x531.md) |
| 74x532 | octal register | Unknown | [implemented](spec/chips/ttl_74x532.md) |
| 74x533 | octal D-type transparent latch, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x533.md) |
| 74x534 | octal D-type edge-triggered flip-flop, inverting outputs, shared clock and output enable | Unknown | [implemented](spec/chips/ttl_74x534.md) |
| 74x535 | octal transparent latch, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x535.md) |
| 74x536 | octal register, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x536.md) |
| 74x537 | BCD to decimal decoder | Unknown | [implemented](spec/chips/ttl_74x537.md) |
| 74x538 | 3-to-8 line decoder/demultiplexer | Unknown | [implemented](spec/chips/ttl_74x538.md) |
| 74x539 | dual 2-to-4 line decoder/demultiplexer | Unknown | [implemented](spec/chips/ttl_74x539.md) |
| 74x540 | octal buffer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x540.md) |
| 74x541 | octal buffer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x541.md) |
| 74x543 | octal registered transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x543.md) |
| 74x544 | octal registered transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x544.md) |
| 74x545 | octal bidirectional transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x545.md) |
| 74x546 | 8-bit bidirectional registered transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x546.md) |
| 74LS547 | 8-bit bidirectional latched transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74ls547.md) |
| 74LS548 | 8-bit two-stage pipelined register | Unknown | [implemented](spec/chips/ttl_74ls548.md) |
| 74x549 | 8-bit two-stage pipelined latch | Unknown | [implemented](spec/chips/ttl_74x549.md) |
| 74x550 | octal registered transceiver with status flags, non-inverting | Unknown | [implemented](spec/chips/ttl_74x550.md) |
| 74x551 | octal registered transceiver with status flags, inverting | Unknown | [implemented](spec/chips/ttl_74x551.md) |
| 74x552 | octal registered transceiver with parity and flags | Unknown | [implemented](spec/chips/ttl_74x552.md) |
| 74x556 | 16x16-bit multiplier slice | Unknown | [implemented](spec/chips/ttl_74x556.md) |
| 74x557 | 8-bit by 8-bit multiplier | Unknown | [implemented](spec/chips/ttl_74x557.md) |
| 74x558 | 8-bit by 8-bit multiplier | Unknown | [implemented](spec/chips/ttl_74x558.md) |
| 74x559 | 8-bit expandable two's complement multiplier/divider | Unknown | [implemented](spec/chips/ttl_74x559.md) |
| 74x560 | 4-bit decade counter | Unknown | [implemented](spec/chips/ttl_74x560.md) |
| 74x561 | synchronous 4-bit binary counter | Unknown | [implemented](spec/chips/ttl_74x561.md) |
| 74x563 | octal D-type transparent latch, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x563.md) |
| 74x564 | octal D-type edge-triggered flip-flop, inverting outputs, shared clock and output enable | Unknown | [implemented](spec/chips/ttl_74x564.md) |
| 74x566 | 8-bit bidirectional registered transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x566.md) |
| 74x567 | 8-bit bidirectional latched transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x567.md) |
| 74x568 | decade up/down counter | Unknown | [implemented](spec/chips/ttl_74x568.md) |
| 74x569 | binary up/down counter | Unknown | [implemented](spec/chips/ttl_74x569.md) |
| 74x570 | 2048-bit PROM (512x4) | Unknown | [implemented](spec/chips/ttl_74x570.md) |
| 74x571 | 2048-bit PROM (512x4) | Unknown | [implemented](spec/chips/ttl_74x571.md) |
| 74x572 | 4096-bit PROM (1024x4) | Unknown | [implemented](spec/chips/ttl_74x572.md) |
| 74x573 | octal D-type transparent latch | Unknown | [implemented](spec/chips/ttl_74x573.md) |
| 74x574 | octal D-type edge-triggered flip-flop | Unknown | [implemented](spec/chips/ttl_74x574.md) |
| 74x575 | octal D-type edge-triggered flip-flop, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x575.md) |
| 74x576 | octal D-type edge-triggered flip-flop, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x576.md) |
| 74x577 | octal D-type edge-triggered flip-flop, synchronous clear, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x577.md) |
| 74x579 | 8-bit bidirectional binary counter | Unknown | [implemented](spec/chips/ttl_74x579.md) |
| 74x580 | octal D-type transparent latch, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x580.md) |
| 74x582 | 4-bit BCD arithmetic logic unit | Unknown | [implemented](spec/chips/ttl_74x582.md) |
| 74x583 | 4-bit BCD adder | Unknown | [implemented](spec/chips/ttl_74x583.md) |
| 74x588 | octal bidirectional transceiver with IEEE-488 termination resistors | Unknown | [implemented](spec/chips/ttl_74x588.md) |
| 74x589 | 8-bit shift register, input latch | Unknown | [implemented](spec/chips/ttl_74x589.md) |
| 74x590 | 8-bit binary counter, output registers | Unknown | [implemented](spec/chips/ttl_74x590.md) |
| 74x591 | 8-bit binary counter, output registers | Unknown | [implemented](spec/chips/ttl_74x591.md) |
| 74x592 | 8-bit binary counter, input registers | Unknown | [implemented](spec/chips/ttl_74x592.md) |
| 74x593 | 8-bit binary counter, input registers | Unknown | [implemented](spec/chips/ttl_74x593.md) |
| 74x594 | 8-bit shift registers, serial-in, parallel-out, output latches | Unknown | [implemented](spec/chips/ttl_74x594.md) |
| 74x595 | 8-bit shift registers, serial-in, parallel-out, output latches, output enable | Unknown | [implemented](spec/chips/ttl_74x595.md) |
| 74x596 | 8-bit shift registers, serial-in, parallel-out, output latches, output enable | Unknown | [implemented](spec/chips/ttl_74x596.md) |
| 74x597 | 8-bit shift registers, parallel-in, serial-out, input latches | Unknown | [implemented](spec/chips/ttl_74x597.md) |
| 74x598 | 8-bit shift register, selectable parallel-in/out input latches | Unknown | [implemented](spec/chips/ttl_74x598.md) |
| 74x599 | 8-bit shift registers, serial-in, parallel-out, output latches | Unknown | [implemented](spec/chips/ttl_74x599.md) |
| 74x600 | dynamic memory refresh controller, transparent and burst modes, for 4K or 16K dRAM | Unknown | [implemented](spec/chips/ttl_74x600.md) |
| 74x601 | dynamic memory refresh controller, transparent and burst modes, for 64K dRAM | Unknown | [implemented](spec/chips/ttl_74x601.md) |
| 74x602 | dynamic memory refresh controller, cycle steal and burst modes, for 4K or 16K dRAM | Unknown | [implemented](spec/chips/ttl_74x602.md) |
| 74x603 | dynamic memory refresh controller, cycle steal and burst modes, for 64K dRAM | Unknown | [implemented](spec/chips/ttl_74x603.md) |
| 74x604 | octal 2-input multiplexer, latch, high-speed | Unknown | [implemented](spec/chips/ttl_74x604.md) |
| 74x605 | octal 2-input multiplexer, latch, high-speed | Unknown | [implemented](spec/chips/ttl_74x605.md) |
| 74x606 | octal 2-input multiplexer, latch, glitch-free | Unknown | [implemented](spec/chips/ttl_74x606.md) |
| 74x607 | octal 2-input multiplexer, latch, glitch-free | Unknown | [implemented](spec/chips/ttl_74x607.md) |
| 74x608 | memory cycle controller | Unknown | [implemented](spec/chips/ttl_74x608.md) |
| 74x610 | memory mapper, latched | Unknown | [implemented](spec/chips/ttl_74x610.md) |
| 74x611 | memory mapper, latched | Unknown | [implemented](spec/chips/ttl_74x611.md) |
| 74x612 | memory mapper | Unknown | [implemented](spec/chips/ttl_74x612.md) |
| 74x613 | memory mapper | Unknown | [implemented](spec/chips/ttl_74x613.md) |
| 74x614 | octal bus transceiver and register, inverting | Unknown | [implemented](spec/chips/ttl_74x614.md) |
| 74x615 | octal bus transceiver and register, non-inverting | Unknown | [implemented](spec/chips/ttl_74x615.md) |
| 74x616 | 16-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x616.md) |
| 74x617 | 16-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x617.md) |
| 74x620 | octal bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x620.md) |
| 74x621 | octal bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x621.md) |
| 74x622 | octal bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x622.md) |
| 74x623 | octal bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x623.md) |
| 74x624 | voltage-controlled oscillator, enable control, range control, two-phase outputs | Unknown | [excluded](spec/chips/ttl_74x624.md) |
| 74x625 | dual voltage-controlled oscillator, two-phase outputs | Unknown | [excluded](spec/chips/ttl_74x625.md) |
| 74x626 | dual voltage-controlled oscillator, enable control, two-phase outputs | Unknown | [excluded](spec/chips/ttl_74x626.md) |
| 74x627 | dual voltage-controlled oscillator | Unknown | [excluded](spec/chips/ttl_74x627.md) |
| 74x628 | voltage-controlled oscillator, enable control, range control, external temperature compensation, two-phase outputs | Unknown | [excluded](spec/chips/ttl_74x628.md) |
| 74x629 | dual voltage-controlled oscillator, enable control, range control | Unknown | [excluded](spec/chips/ttl_74x629.md) |
| 74x630 | 16-bit error detection and correction (EDAC) | Unknown | [implemented](spec/chips/ttl_74x630.md) |
| 74x631 | 16-bit error detection and correction | Unknown | [implemented](spec/chips/ttl_74x631.md) |
| 74x632 | 32-bit parallel error detection and correction, byte-write | Unknown | [implemented](spec/chips/ttl_74x632.md) |
| 74x633 | 32-bit parallel error detection and correction, byte-write | Unknown | [implemented](spec/chips/ttl_74x633.md) |
| 74x634 | 32-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x634.md) |
| 74x635 | 32-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x635.md) |
| 74x636 | 8-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x636.md) |
| 74x637 | 8-bit parallel error detection and correction | Unknown | [implemented](spec/chips/ttl_74x637.md) |
| 74x638 | octal bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x638.md) |
| 74x639 | octal bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x639.md) |
| 74x640 | octal bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x640.md) |
| 74x641 | octal bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x641.md) |
| 74x642 | octal bus transceiver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x642.md) |
| 74x643 | octal bus transceiver, mix of inverting and non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x643.md) |
| 74x644 | octal bus transceiver, mix of inverting and non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x644.md) |
| 74x645 | octal bus transceiver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x645.md) |
| 74x646 | octal bus transceiver/latch/multiplexer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x646.md) |
| 74x647 | octal bus transceiver/latch/multiplexer, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x647.md) |
| 74x648 | octal bus transceiver/latch/multiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x648.md) |
| 74x649 | octal bus transceiver/latch/multiplexer, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x649.md) |
| 74x651 | octal bus transceiver/register, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x651.md) |
| 74x652 | octal bus transceiver/register, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x652.md) |
| 74x653 | octal bus transceiver/register, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x653.md) |
| 74x654 | octal bus transceiver/register, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x654.md) |
| 74x655 | octal buffer / line driver with parity, inverting | Unknown | [pending](spec/chips/ttl_74x655.md) |
| 74x656 | octal buffer / line driver with parity, non-inverting | Unknown | [pending](spec/chips/ttl_74x656.md) |
| 74x657 | octal bidirectional transceiver with 8-bit parity generator/checker | Unknown | [implemented](spec/chips/ttl_74x657.md) |
| 74x658 | octal bus transceiver, parity, inverting | Unknown | [pending](spec/chips/ttl_74x658.md) |
| 74x659 | octal bus transceiver, parity, non-inverting | Unknown | [pending](spec/chips/ttl_74x659.md) |
| 74x664 | octal bus transceiver, parity, inverting | Unknown | [pending](spec/chips/ttl_74x664.md) |
| 74x665 | octal bus transceiver, parity, non-inverting | Unknown | [pending](spec/chips/ttl_74x665.md) |
| 74x666 | 8-bit D-type transparent read-back latch, non-inverting | Unknown | [implemented](spec/chips/ttl_74x666.md) |
| 74x667 | 8-bit D-type transparent read-back latch, inverting | Unknown | [implemented](spec/chips/ttl_74x667.md) |
| 74x668 | synchronous 4-bit decade up/down counter | Unknown | [implemented](spec/chips/ttl_74x668.md) |
| 74x669 | synchronous 4-bit binary up/down counter | Unknown | [implemented](spec/chips/ttl_74x669.md) |
| 74x670 | 16-bit register file (4x4) | Unknown | [implemented](spec/chips/ttl_74x670.md) |
| 74x671 | 4-bit bidirectional shift register/latch/multiplexer, direct clear | Unknown | [implemented](spec/chips/ttl_74x671.md) |
| 74x672 | 4-bit bidirectional shift register/latch/multiplexer, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x672.md) |
| 74x673 | 16-bit serial-in, serial/parallel-out shift register, output storage registers | Unknown | [implemented](spec/chips/ttl_74x673.md) |
| 74x674 | 16-bit parallel-in, serial-out shift register | Unknown | [implemented](spec/chips/ttl_74x674.md) |
| 74x675 | 16-bit serial-in, serial/parallel-out shift register | Unknown | [implemented](spec/chips/ttl_74x675.md) |
| 74x676 | 16-bit serial/parallel-in, serial-out shift register | Unknown | [implemented](spec/chips/ttl_74x676.md) |
| 74x677 | 16-bit address comparator, enable | Unknown | [implemented](spec/chips/ttl_74x677.md) |
| 74x678 | 16-bit address comparator, latch | Unknown | [implemented](spec/chips/ttl_74x678.md) |
| 74x679 | 12-bit address comparator, latch | Unknown | [implemented](spec/chips/ttl_74x679.md) |
| 74x680 | 12-bit address comparator, enable | Unknown | [implemented](spec/chips/ttl_74x680.md) |
| 74x681 | 4-bit parallel binary accumulator | Unknown | [pending](spec/chips/ttl_74x681.md) |
| 74x682 | 8-bit magnitude comparator, P>Q output | Unknown | [implemented](spec/chips/ttl_74x682.md) |
| 74x683 | 8-bit magnitude comparator, P>Q output | Unknown | [implemented](spec/chips/ttl_74x683.md) |
| 74x684 | 8-bit magnitude comparator, P>Q output | Unknown | [implemented](spec/chips/ttl_74x684.md) |
| 74x685 | 8-bit magnitude comparator, P>Q output | Unknown | [implemented](spec/chips/ttl_74x685.md) |
| 74x686 | 8-bit magnitude comparator, P>Q output, enable | Unknown | [implemented](spec/chips/ttl_74x686.md) |
| 74x687 | 8-bit magnitude comparator, P>Q output, enable | Unknown | [implemented](spec/chips/ttl_74x687.md) |
| 74x688 | 8-bit magnitude comparator, enable | Unknown | [implemented](spec/chips/ttl_74x688.md) |
| 74x689 | 8-bit magnitude comparator, enable | Unknown | [implemented](spec/chips/ttl_74x689.md) |
| 74x690 | 4-bit decimal counter/latch/multiplexer, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x690.md) |
| 74x691 | 4-bit binary counter/latch/multiplexer, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x691.md) |
| 74x692 | 4-bit decimal counter/latch/multiplexer, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x692.md) |
| 74x693 | 4-bit binary counter/latch/multiplexer, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x693.md) |
| 74x694 | 4-bit decimal counter/latch/multiplexer, synchronous and asynchronous clears | Unknown | [pending](spec/chips/ttl_74x694.md) |
| 74x695 | 4-bit binary counter/latch/multiplexer, synchronous and asynchronous clears | Unknown | [pending](spec/chips/ttl_74x695.md) |
| 74x696 | 4-bit decimal counter/register/multiplexer, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x696.md) |
| 74x697 | 4-bit binary counter/register/multiplexer, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x697.md) |
| 74x698 | 4-bit decimal counter/register/multiplexer, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x698.md) |
| 74x699 | 4-bit binary counter/register/multiplexer, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x699.md) |
| 74x700 | octal dRAM driver, inverting | Unknown | [implemented](spec/chips/ttl_74x700.md) |
| 74x701 | 8-bit register/counter/comparator | Unknown | [pending](spec/chips/ttl_74x701.md) |
| 74x702 | 8-bit registered read-back transceiver | Unknown | [pending](spec/chips/ttl_74x702.md) |
| 74x705 | arithmetic logic unit for digital signal processing applications | Unknown | [pending](spec/chips/ttl_74x705.md) |
| 74x707 | 8-bit TTL-ECL shift register | Unknown | [pending](spec/chips/ttl_74x707.md) |
| 74x708 | 576-bit FIFO memory (64x9) | Unknown | [implemented](spec/chips/ttl_74x708.md) |
| 74x710 | 8-bit single-supply TTL-ECL shift register | Unknown | [pending](spec/chips/ttl_74x710.md) |
| 74x711 | quint 2-to-1 multiplexers | Unknown | [implemented](spec/chips/ttl_74x711.md) |
| 74x712 | quint 3-to-1 multiplexers | Unknown | [implemented](spec/chips/ttl_74x712.md) |
| 74x715 | programmable video sync generator | Unknown | [pending](spec/chips/ttl_74x715.md) |
| 74x716 | programmable decade counter | Unknown | [pending](spec/chips/ttl_74x716.md) |
| 74x718 | programmable binary counter | Unknown | [pending](spec/chips/ttl_74x718.md) |
| 74x723 | 576-bit FIFO memory (64x9) | Unknown | [implemented](spec/chips/ttl_74x723.md) |
| 74x724 | voltage-controlled multivibrator | Unknown | [excluded](spec/chips/ttl_74x724.md) |
| 74x725 | 4608-bit FIFO memory (512x9) | Unknown | [implemented](spec/chips/ttl_74x725.md) |
| 74x730 | octal dRAM driver, inverting | Unknown | [implemented](spec/chips/ttl_74x730.md) |
| 74x731 | octal dRAM driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x731.md) |
| 74x732 | 4-bit 3-bus multiplexer, inverting | Unknown | [pending](spec/chips/ttl_74x732.md) |
| 74x733 | 4-bit 3-bus multiplexer, non-inverting | Unknown | [pending](spec/chips/ttl_74x733.md) |
| 74x734 | octal dRAM driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x734.md) |
| 74x740 | dual 4-bit line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x740.md) |
| 74x741 | dual 4-bit line driver, non-inverting, complementary enable inputs | Unknown | [implemented](spec/chips/ttl_74x741.md) |
| 74x742 | octal line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x742.md) |
| 74x743 | octal line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x743.md) |
| 74x744 | dual 4-bit line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x744.md) |
| 74x746 | octal buffer / line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x746.md) |
| 74x747 | octal buffer / line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x747.md) |
| 74x748 | 8 to 3-line priority encoder (glitch-less) | Unknown | [implemented](spec/chips/ttl_74x748.md) |
| 74x756 | octal buffer/line driver, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x756.md) |
| 74x757 | octal buffer/line driver, non-inverting outputs, complementary enable inputs | Unknown | [implemented](spec/chips/ttl_74x757.md) |
| 74x758 | quadruple bus transceivers, inverting outputs | Unknown | [pending](spec/chips/ttl_74x758.md) |
| 74x759 | quadruple bus transceivers, non-inverting outputs | Unknown | [pending](spec/chips/ttl_74x759.md) |
| 74x760 | octal buffer/line driver, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x760.md) |
| 74x762 | octal buffer/line driver, inverting and non-inverting outputs | Unknown | [pending](spec/chips/ttl_74x762.md) |
| 74x763 | octal buffer/line driver, inverting outputs, complementary enable inputs | Unknown | [implemented](spec/chips/ttl_74x763.md) |
| 74x764 | dual-port dRAM controller | Unknown | [pending](spec/chips/ttl_74x764.md) |
| 74x765 | dual-port dRAM controller with address latch | Unknown | [pending](spec/chips/ttl_74x765.md) |
| 74x776 | 8-bit latched transceiver for FutureBus | Unknown | [pending](spec/chips/ttl_74x776.md) |
| 74x777 | triple latched transceiver | Unknown | [pending](spec/chips/ttl_74x777.md) |
| 74x779 | 8-bit bidirectional binary counter | Unknown | [pending](spec/chips/ttl_74x779.md) |
| 74x783 | synchronous address multiplexer for display systems | Unknown | [pending](spec/chips/ttl_74x783.md) |
| 74x784 | 8-bit serial/parallel multiplier with adder/subtractor | Unknown | [pending](spec/chips/ttl_74x784.md) |
| 74x785 | synchronous address multiplexer for display systems with 256-column refresh | Unknown | [pending](spec/chips/ttl_74x785.md) |
| 74x786 | 4-input asynchronous bus arbiter | Unknown | [pending](spec/chips/ttl_74x786.md) |
| 74x790 | error detection and correction (EDAC) | Unknown | [pending](spec/chips/ttl_74x790.md) |
| 74x793 | 8-bit latch, readback | Unknown | [pending](spec/chips/ttl_74x793.md) |
| 74x794 | 8-bit register, readback | Unknown | [pending](spec/chips/ttl_74x794.md) |
| 74x795 | octal buffer, non-inverting, shared enable | Unknown | [implemented](spec/chips/ttl_74x795.md) |
| 74x796 | octal buffer, inverting, shared enable | Unknown | [implemented](spec/chips/ttl_74x796.md) |
| 74x797 | octal buffer, non-inverting, enable for 4 buffers each | Unknown | [implemented](spec/chips/ttl_74x797.md) |
| 74x798 | octal buffer, inverting, enable for 4 buffers each | Unknown | [implemented](spec/chips/ttl_74x798.md) |
| 74x800 | triple 4-input AND/NAND drivers | Unknown | [implemented](spec/chips/ttl_74x800.md) |
| 74x802 | triple 4-input OR/NOR drivers | Unknown | [implemented](spec/chips/ttl_74x802.md) |
| 74x803 | quad D flip flops with matched propagation delays | Unknown | [implemented](spec/chips/ttl_74x803.md) |
| 74x804 | hex 2-input NAND drivers | Unknown | [implemented](spec/chips/ttl_74x804.md) |
| 74x805 | hex 2-input NOR drivers | Unknown | [implemented](spec/chips/ttl_74x805.md) |
| 74x807 | 1-to-10 clock driver | Unknown | [pending](spec/chips/ttl_74x807.md) |
| 74x808 | hex 2-input AND drivers | Unknown | [implemented](spec/chips/ttl_74x808.md) |
| 74x810 | quad 2-input XNOR gates | Unknown | [implemented](spec/chips/ttl_74x810.md) |
| 74x811 | quad 2-input XNOR gates | Unknown | [implemented](spec/chips/ttl_74x811.md) |
| 74x817 | GTL+ to LV-TTL 1-to-6 fanout / LV-TTL to GTL+ 1-to-2 fanout driver | Unknown | [pending](spec/chips/ttl_74x817.md) |
| 74x818 | 8-bit diagnostic register | Unknown | [pending](spec/chips/ttl_74x818.md) |
| 74x819 | 8-bit diagnostic / pipeline register | Unknown | [pending](spec/chips/ttl_74x819.md) |
| 74x821 | 10-bit bus interface flip-flop | Unknown | [implemented](spec/chips/ttl_74x821.md) |
| 74x822 | 10-bit bus interface flip-flop, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x822.md) |
| 74x823 | 9-bit D-type flip-flops, clear and clock enable inputs | Unknown | [implemented](spec/chips/ttl_74x823.md) |
| 74x824 | 9-bit D-type flip-flops, clear and clock enable inputs, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x824.md) |
| 74x825 | 8-bit D-type flip-flop, clear and clock enable inputs | Unknown | [implemented](spec/chips/ttl_74x825.md) |
| 74x826 | 8-bit D-type flip-flop, clear and clock enable inputs, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x826.md) |
| 74x827 | 10-bit buffer, non-inverting | Unknown | [implemented](spec/chips/ttl_74x827.md) |
| 74x828 | 10-bit buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x828.md) |
| 74x832 | hex 2-input OR drivers | Unknown | [implemented](spec/chips/ttl_74x832.md) |
| 74x833 | 8-bit to 9-bit bus transceiver with parity register, non-inverting | Unknown | [implemented](spec/chips/ttl_74x833.md) |
| 74x834 | 8-bit to 9-bit bus transceiver with parity register, inverting | Unknown | [implemented](spec/chips/ttl_74x834.md) |
| 74x835 | 8-bit shift register with 2:1 input multiplexers, one input latched, serial output | Unknown | [implemented](spec/chips/ttl_74x835.md) |
| 74x839 | field-programmable logic array 14x32x6 | Unknown | [pending](spec/chips/ttl_74x839.md) |
| 74x840 | field-programmable logic array 14x32x6 | Unknown | [pending](spec/chips/ttl_74x840.md) |
| 74x841 | 10-bit D-type flip-flop | Unknown | [implemented](spec/chips/ttl_74x841.md) |
| 74x842 | 10-bit D-type flip-flop, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x842.md) |
| 74x843 | 9-bit D flip-flops, clear and set inputs | Unknown | [implemented](spec/chips/ttl_74x843.md) |
| 74x844 | 9-bit D flip-flops, clear and set inputs, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x844.md) |
| 74x845 | 8-bit D flip-flops, clear and set inputs | Unknown | [implemented](spec/chips/ttl_74x845.md) |
| 74x846 | 8-bit D flip-flops, clear and set inputs, inverting inputs | Unknown | [implemented](spec/chips/ttl_74x846.md) |
| 74x848 | 8 to 3-line priority encoder (glitch-less) | Unknown | [pending](spec/chips/ttl_74x848.md) |
| 74x850 | 1 of 16 data selector/multiplexer, clocked select | Unknown | [implemented](spec/chips/ttl_74x850.md) |
| 74x851 | 1 of 16 data selector/multiplexer | Unknown | [implemented](spec/chips/ttl_74x851.md) |
| 74x852 | 8-bit universal transceiver port controller | Unknown | [pending](spec/chips/ttl_74x852.md) |
| 74x853 | 8-bit to 9-bit bus transceiver with parity latch, non-inverting | Unknown | [pending](spec/chips/ttl_74x853.md) |
| 74x854 | 8-bit to 9-bit bus transceiver with parity latch, inverting | Unknown | [pending](spec/chips/ttl_74x854.md) |
| 74x856 | 8-bit universal transceiver port controller | Unknown | [pending](spec/chips/ttl_74x856.md) |
| 74x857 | hex 2-line to 1-line multiplexer | Unknown | [implemented](spec/chips/ttl_74x857.md) |
| 74x861 | 10-bit bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x861.md) |
| 74x862 | 10-bit bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x862.md) |
| 74x863 | 9-bit bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x863.md) |
| 74x864 | 9-bit bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x864.md) |
| 74x866 | 8-bit magnitude comparator with latches | Unknown | [implemented](spec/chips/ttl_74x866.md) |
| 74x867 | synchronous 8-bit up/down counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x867.md) |
| 74x869 | synchronous 8-bit up/down counter, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x869.md) |
| 74x870 | dual 16x4 register files | Unknown | [pending](spec/chips/ttl_74x870.md) |
| 74x871 | dual 16x4 register files | Unknown | [pending](spec/chips/ttl_74x871.md) |
| 74x873 | dual 4-bit transparent latch with clear | Unknown | [implemented](spec/chips/ttl_74x873.md) |
| 74x874 | dual 4-bit edge-triggered D flip-flops with clear | Unknown | [implemented](spec/chips/ttl_74x874.md) |
| 74x876 | dual 4-bit edge-triggered D flip-flops with set, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x876.md) |
| 74x877 | 8-bit universal transceiver port controller | Unknown | [pending](spec/chips/ttl_74x877.md) |
| 74x878 | dual 4-bit D-type flip-flop, synchronous clear, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x878.md) |
| 74x879 | dual 4-bit D-type flip-flop, synchronous clear, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x879.md) |
| 74x880 | dual 4-bit transparent latch with clear, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x880.md) |
| 74x881 | 4-bit arithmetic logic unit | Unknown | [implemented](spec/chips/ttl_74x881.md) |
| 74x882 | 32-bit lookahead carry generator | Unknown | [implemented](spec/chips/ttl_74x882.md) |
| 74x885 | 8-bit magnitude comparator | Unknown | [implemented](spec/chips/ttl_74x885.md) |
| 74x887 | 8-bit processor element (non-cascadable version of 74x888) | Unknown | [pending](spec/chips/ttl_74x887.md) |
| 74x888 | 8-bit processor slice | Unknown | [pending](spec/chips/ttl_74x888.md) |
| 74x889 | 8-bit processor slice | Unknown | [pending](spec/chips/ttl_74x889.md) |
| 74x890 | microoperation sequencer | Unknown | [pending](spec/chips/ttl_74x890.md) |
| 74x891 | microoperation sequencer | Unknown | [pending](spec/chips/ttl_74x891.md) |
| 74x895 | 8-bit memory address generator | Unknown | [pending](spec/chips/ttl_74x895.md) |
| 74x897 | 16-bit parallel/serial barrel shifter | Unknown | [pending](spec/chips/ttl_74x897.md) |
| 74x899 | 9-bit latchable transceiver with parity generator / checker | Unknown | [pending](spec/chips/ttl_74x899.md) |
| 74x900 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x900.md) |
| 74x901 | hex inverting TTL buffer | Unknown | [implemented](spec/chips/ttl_74x901.md) |
| 74x904 | hex non-inverting PMOS buffer | Unknown | [implemented](spec/chips/ttl_74x904.md) |
| 74x905 | 12-bit successive approximation register | Unknown | [pending](spec/chips/ttl_74x905.md) |
| 74x906 | hex open drain n-channel buffers | Unknown | [implemented](spec/chips/ttl_74x906.md) |
| 74x907 | hex open drain p-channel buffers | Unknown | [implemented](spec/chips/ttl_74x907.md) |
| 74x908 | dual 2-input NAND 30 V / 250 mA relay driver | Unknown | [implemented](spec/chips/ttl_74x908.md) |
| 74x909 | quad voltage comparator | Unknown | [excluded](spec/chips/ttl_74x909.md) |
| 74x910 | 256-bit RAM (64x4) | Unknown | [implemented](spec/chips/ttl_74x910.md) |
| 74x911 | 4-digit expandable display controller | Unknown | [pending](spec/chips/ttl_74x911.md) |
| 74x912 | 6-digit BCD display controller and driver | Unknown | [pending](spec/chips/ttl_74x912.md) |
| 74x913 | 6-digit BCD display controller and driver, no decimal point | Unknown | [pending](spec/chips/ttl_74x913.md) |
| 74x914 | hex inverter gate, extended input voltage | Unknown | [implemented](spec/chips/ttl_74x914.md) |
| 74x915 | 7-segment to BCD converter | Unknown | [implemented](spec/chips/ttl_74x915.md) |
| 74x917 | 6-digit hex display controller and driver | Unknown | [pending](spec/chips/ttl_74x917.md) |
| 74x918 | dual 2-input NAND 30 V / 250 mA relay driver | Unknown | [implemented](spec/chips/ttl_74x918.md) |
| 74x920 | 1024-bit RAM (256x4), separate data inputs and outputs | Unknown | [implemented](spec/chips/ttl_74x920.md) |
| 74x921 | 1024-bit RAM (256x4) | Unknown | [implemented](spec/chips/ttl_74x921.md) |
| 74x922 | 16-key encoder | Unknown | [pending](spec/chips/ttl_74x922.md) |
| 74x923 | 20-key encoder | Unknown | [pending](spec/chips/ttl_74x923.md) |
| 74x925 | 4-digit counter/display driver | Unknown | [pending](spec/chips/ttl_74x925.md) |
| 74x926 | 4-digit decade counter/display driver, carry out and latch (up to 9999) | Unknown | [pending](spec/chips/ttl_74x926.md) |
| 74x927 | 4-digit timer counter/display driver (up to 9599, intended as time elapsed, i.e. 9:59.9 min) | Unknown | [pending](spec/chips/ttl_74x927.md) |
| 74x928 | 4-digit counter/display driver (up to 1999) | Unknown | [pending](spec/chips/ttl_74x928.md) |
| 74x929 | 1024-bit RAM (1024x1), single chip select | Unknown | [implemented](spec/chips/ttl_74x929.md) |
| 74x930 | 1024-bit RAM (1024x1), three chip selects | Unknown | [implemented](spec/chips/ttl_74x930.md) |
| 74x932 | phase comparator | Unknown | [pending](spec/chips/ttl_74x932.md) |
| 74x933 | 7-bit address bus comparator | Unknown | [implemented](spec/chips/ttl_74x933.md) |
| 74934 | ADC similar to ADC0829, see corresponding NSC datasheet | Unknown | [excluded](spec/chips/ttl_74934.md) |
| 74x935 | ADC for 3.5-digit digital voltmeters, multiplexed 7-segment display outputs | Unknown | [excluded](spec/chips/ttl_74x935.md) |
| 74x936 | ADC for 3.75-digit digital voltmeters, multiplexed 7-segment display outputs | Unknown | [excluded](spec/chips/ttl_74x936.md) |
| 74x937 | ADC for 3.5-digit digital voltmeters, multiplexed BCD outputs | Unknown | [excluded](spec/chips/ttl_74x937.md) |
| 74x938 | ADC for 3.75-digit digital voltmeters, multiplexed BCD outputs | Unknown | [excluded](spec/chips/ttl_74x938.md) |
| 74x940 | octal bus/line drivers/line receivers | Unknown | [implemented](spec/chips/ttl_74x940.md) |
| 74x941 | octal bus/line drivers/line receivers | Unknown | [implemented](spec/chips/ttl_74x941.md) |
| 74x942 | 300 baud Bell 103 modem (+/- 5 V supply) | Unknown | [pending](spec/chips/ttl_74x942.md) |
| 74x943 | 300 baud Bell 103 modem (single 5 V supply) | Unknown | [pending](spec/chips/ttl_74x943.md) |
| 74x945 | 4-digit up/down counter, decoder and LCD driver, output latch | Unknown | [pending](spec/chips/ttl_74x945.md) |
| 74x946 | 4.5-digit counter, decoder and LCD driver, leading zero blanking | Unknown | [pending](spec/chips/ttl_74x946.md) |
| 74x947 | 4-digit up/down counter, decoder and LCD driver, leading zero blanking | Unknown | [pending](spec/chips/ttl_74x947.md) |
| 74x948 | 8-bit ADC with 16-channel analog multiplexer | Unknown | [excluded](spec/chips/ttl_74x948.md) |
| 74x949 | 8-bit ADC with 8-channel analog multiplexer | Unknown | [excluded](spec/chips/ttl_74x949.md) |
| 74x950 | 8-bit ADC with 8-channel analog multiplexer and sample and hold | Unknown | [excluded](spec/chips/ttl_74x950.md) |
| 74x952 | dual rank 8-bit shift register, synchronous clear | Unknown | [pending](spec/chips/ttl_74x952.md) |
| 74x962 | dual rank 8-bit shift register, register exchange mode | Unknown | [implemented](spec/chips/ttl_74x962.md) |
| 74x963 | dual rank 8-bit shift register, synchronous clear | Unknown | [implemented](spec/chips/ttl_74x963.md) |
| 74x964 | dual rank 8-bit shift register, synchronous and asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x964.md) |
| 74x968 | controller/driver for 16k/64k/256k/1M dRAM | Unknown | [implemented](spec/chips/ttl_74x968.md) |
| 74x978 | octal flip-flop with serial scanner | Unknown | [implemented](spec/chips/ttl_74x978.md) |
| 74x979 | 9-bit registered transceiver with parity generator/checker for FutureBus | Unknown | [implemented](spec/chips/ttl_74x979.md) |
| 74x989 | 64-bit RAM (16x4), inverting output | Unknown | [implemented](spec/chips/ttl_74x989.md) |
| 74x990 | 8-bit D-type transparent read-back latch, non-inverting | Unknown | [implemented](spec/chips/ttl_74x990.md) |
| 74x991 | 8-bit D-type transparent read-back latch, inverting | Unknown | [implemented](spec/chips/ttl_74x991.md) |
| 74x992 | 9-bit D-type transparent read-back latch, non-inverting | Unknown | [implemented](spec/chips/ttl_74x992.md) |
| 74x993 | 9-bit D-type transparent read-back latch, inverting | Unknown | [implemented](spec/chips/ttl_74x993.md) |
| 74x994 | 10-bit D-type transparent read-back latch, non-inverting | Unknown | [implemented](spec/chips/ttl_74x994.md) |
| 74x995 | 10-bit D-type transparent read-back latch, inverting | Unknown | [implemented](spec/chips/ttl_74x995.md) |
| 74x996 | 8-bit D-type edge-triggered read-back latch | Unknown | [implemented](spec/chips/ttl_74x996.md) |
| 74x1000 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x1000.md) |
| 74x1002 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x1002.md) |
| 74x1003 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x1003.md) |
| 74x1004 | hex inverting buffer | Unknown | [implemented](spec/chips/ttl_74x1004.md) |
| 74x1005 | hex inverting buffer | Unknown | [implemented](spec/chips/ttl_74x1005.md) |
| 74x1008 | quad 2-input AND gate | Unknown | [implemented](spec/chips/ttl_74x1008.md) |
| 74x1011 | triple 3-input AND gate | Unknown | [implemented](spec/chips/ttl_74x1011.md) |
| 74x1017 | 16x16-bit parallel multiplier | Unknown | [pending](spec/chips/ttl_74x1017.md) |
| 74x1018 | 18-bit Schottky diode R-C bus termination array | Unknown | [pending](spec/chips/ttl_74x1018.md) |
| 74x1020 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x1020.md) |
| 74x1032 | quad 2-input OR gate | Unknown | [implemented](spec/chips/ttl_74x1032.md) |
| 74x1034 | hex non-inverting buffer | Unknown | [implemented](spec/chips/ttl_74x1034.md) |
| 74x1035 | hex non-inverting buffer | Unknown | [implemented](spec/chips/ttl_74x1035.md) |
| 74x1036 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x1036.md) |
| 74x1050 | 12-bit Schottky diode bus termination array, clamp to GND | Unknown | [pending](spec/chips/ttl_74x1050.md) |
| 74x1051 | 12-bit Schottky diode bus termination array, clamp to GND/V | Unknown | [pending](spec/chips/ttl_74x1051.md) |
| 74x1052 | 16-bit Schottky diode bus termination array, clamp to GND | Unknown | [pending](spec/chips/ttl_74x1052.md) |
| 74x1053 | 16-bit Schottky diode bus termination array, clamp to GND/V | Unknown | [pending](spec/chips/ttl_74x1053.md) |
| 74x1056 | 8-bit Schottky diode bus termination array, clamp to GND | Unknown | [pending](spec/chips/ttl_74x1056.md) |
| 74x1071 | 10-bit bus termination array with bus-hold function | Unknown | [pending](spec/chips/ttl_74x1071.md) |
| 74x1073 | 16-bit bus termination array with bus-hold function | Unknown | [pending](spec/chips/ttl_74x1073.md) |
| 74x1074 | dual D negative edge triggered flip-flop, asynchronous preset and clear | Unknown | [implemented](spec/chips/ttl_74x1074.md) |
| 74x1181 | 4-bit arithmetic logic unit | Unknown | [implemented](spec/chips/ttl_74x1181.md) |
| 74x1240 | octal buffer / line driver, inverting (lower-power version of 74x240) | Unknown | [implemented](spec/chips/ttl_74x1240.md) |
| 74x1241 | octal buffer / line driver, non-inverting (lower-power version of 74x241) | Unknown | [implemented](spec/chips/ttl_74x1241.md) |
| 74x1242 | quad bus transceiver, inverting (lower-power version of 74x242) | Unknown | [implemented](spec/chips/ttl_74x1242.md) |
| 74x1243 | quad bus transceiver, non-inverting (lower-power version of 74x243) | Unknown | [implemented](spec/chips/ttl_74x1243.md) |
| 74x1244 | octal buffer / driver, non-inverting (lower-power version of 74x244) | Unknown | [implemented](spec/chips/ttl_74x1244.md) |
| 74x1245 | octal bus transceiver (lower-power version of 74x245) | Unknown | [implemented](spec/chips/ttl_74x1245.md) |
| 74x1280 | 9-bit parity generator/checker with registered outputs | Unknown | [implemented](spec/chips/ttl_74x1280.md) |
| 74x1284 | parallel printer interface transceiver / buffer (IEEE 1284) | Unknown | [pending](spec/chips/ttl_74x1284.md) |
| 74x1394 | 2-bit GTLP transceiver with split LV-TTL port | Unknown | [pending](spec/chips/ttl_74x1394.md) |
| 74x1395 | Dual 1-bit GTLP transceiver with split LV-TTL port | Unknown | [pending](spec/chips/ttl_74x1395.md) |
| 74x1403 | 8-bit bus receiver plus 4-bit bus driver | Unknown | [implemented](spec/chips/ttl_74x1403.md) |
| 74x1404 | oscillator driver | Unknown | [pending](spec/chips/ttl_74x1404.md) |
| 74x1604 | dual 8-bit transparent latch with output multiplexer | Unknown | [implemented](spec/chips/ttl_74x1604.md) |
| 74x1612 | 18-bit LV-TTL-to-GTLP adjustable-edge-rate universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x1612.md) |
| 74x1620 | octal bus transceiver, inverting | Unknown | [pending](spec/chips/ttl_74x1620.md) |
| 74x1621 | octal bus transceiver, non-inverting | Unknown | [pending](spec/chips/ttl_74x1621.md) |
| 74x1622 | octal bus transceiver, inverting | Unknown | [pending](spec/chips/ttl_74x1622.md) |
| 74x1623 | octal bus transceiver, non-inverting | Unknown | [pending](spec/chips/ttl_74x1623.md) |
| 74x1627 | 18-bit LV-TTL-to-GTLP adjustable-edge-rate bus transceiver with source synchronous clock outputs | Unknown | [pending](spec/chips/ttl_74x1627.md) |
| 74x1631 | quad bus driver with complementary outputs | Unknown | [pending](spec/chips/ttl_74x1631.md) |
| 74x1638 | octal bus transceiver, inverting (lower-power version of 74x638) | Unknown | [implemented](spec/chips/ttl_74x1638.md) |
| 74x1639 | octal bus transceiver, non-inverting (lower-power version of 74x639) | Unknown | [implemented](spec/chips/ttl_74x1639.md) |
| 74x1640 | octal bus transceiver, inverting (lower-power version of 74x640) | Unknown | [implemented](spec/chips/ttl_74x1640.md) |
| 74x1641 | octal bus transceiver, non-inverting (lower-power version of 74x641) | Unknown | [implemented](spec/chips/ttl_74x1641.md) |
| 74x1642 | octal bus transceiver, inverting (lower-power version of 74x642) | Unknown | [implemented](spec/chips/ttl_74x1642.md) |
| 74x1643 | octal bus transceiver, inverting and non-inverting (lower-power version of 74x643) | Unknown | [implemented](spec/chips/ttl_74x1643.md) |
| 74x1644 | octal bus transceiver, inverting and non-inverting (lower-power version of 74x644) | Unknown | [implemented](spec/chips/ttl_74x1644.md) |
| 74x1650 | dual 9-bit Futurebus universal storage transceiver with split TTL I/O | Unknown | [pending](spec/chips/ttl_74x1650.md) |
| 74x1651 | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split TTL I/O | Unknown | [pending](spec/chips/ttl_74x1651.md) |
| 74x1653 | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split 3.3V TTL I/O | Unknown | [pending](spec/chips/ttl_74x1653.md) |
| 74x1655 | dual 8-bit GTL universal storage transceivers with live insertion | Unknown | [pending](spec/chips/ttl_74x1655.md) |
| 74x1760 | 10-bit 4-way latched address multiplexer | Unknown | [implemented](spec/chips/ttl_74x1760.md) |
| 74x1761 | dRAM and interrupt vector controller | Unknown | [pending](spec/chips/ttl_74x1761.md) |
| 74x1762 | dRAM address controller | Unknown | [implemented](spec/chips/ttl_74x1762.md) |
| 74x1763 | single-port dRAM controller | Unknown | [pending](spec/chips/ttl_74x1763.md) |
| 74x1764 | dual-port dRAM controller | Unknown | [pending](spec/chips/ttl_74x1764.md) |
| 74x1765 | dual-port dRAM controller with address latch | Unknown | [pending](spec/chips/ttl_74x1765.md) |
| 74x1766 | burst mode dRAM controller | Unknown | [pending](spec/chips/ttl_74x1766.md) |
| 74x1779 | 8-bit bidirectional binary counter | Unknown | [implemented](spec/chips/ttl_74x1779.md) |
| 74x1801 | FM, MFM, and DM encoder / decoder, data rates up to 10 MHz | Unknown | [pending](spec/chips/ttl_74x1801.md) |
| 74x1802 | SerDes with ECC and CRC, data rates up to 10 MHz | Unknown | [pending](spec/chips/ttl_74x1802.md) |
| 74x1803 | quad clock driver | Unknown | [implemented](spec/chips/ttl_74x1803.md) |
| 74x1804 | hex 2-input NAND | Unknown | [implemented](spec/chips/ttl_74x1804.md) |
| 74x1805 | hex 2-input NOR | Unknown | [implemented](spec/chips/ttl_74x1805.md) |
| 74x1808 | hex 2-input AND | Unknown | [implemented](spec/chips/ttl_74x1808.md) |
| 74x1811 | FM, MFM, and DM encoder / decoder, data rates up to 20 MHz | Unknown | [pending](spec/chips/ttl_74x1811.md) |
| 74x1812 | SerDes with ECC and CRC, data rates up to 30 MHz | Unknown | [pending](spec/chips/ttl_74x1812.md) |
| 74x1821 | 10-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x1821.md) |
| 74x1823 | 9-bit bus interface flip-flops with clear | Unknown | [implemented](spec/chips/ttl_74x1823.md) |
| 74x1832 | hex 2-input OR | Unknown | [implemented](spec/chips/ttl_74x1832.md) |
| 74x1841 | 10-bit bus interface transparent latches | Unknown | [implemented](spec/chips/ttl_74x1841.md) |
| 74x1843 | 9-bit bus interface transparent latches with clear | Unknown | [implemented](spec/chips/ttl_74x1843.md) |
| 74x2000 | direction discriminator with microprocessor interface | Unknown | [pending](spec/chips/ttl_74x2000.md) |
| 74x2003 | 8-bit level translator | Unknown | [pending](spec/chips/ttl_74x2003.md) |
| 74x2006 | 13-bit GTL to 3.3V TTL level translator | Unknown | [pending](spec/chips/ttl_74x2006.md) |
| 74x2007 | 12-bit GTL to 3.3V TTL level translator | Unknown | [pending](spec/chips/ttl_74x2007.md) |
| 74x2010 | 10-bit level translator | Unknown | [pending](spec/chips/ttl_74x2010.md) |
| 74x2014 | 4-bit GTL to TTL transceiver | Unknown | [pending](spec/chips/ttl_74x2014.md) |
| 74x2031 | 9-bit Futurebus address/data transceiver | Unknown | [pending](spec/chips/ttl_74x2031.md) |
| 74x2032 | 9-bit Futurebus competition transceiver | Unknown | [pending](spec/chips/ttl_74x2032.md) |
| 74x2034 | 8-bit GTLP adjustable-edge-rate registered transceiver with split LV-TTL I/O | Unknown | [pending](spec/chips/ttl_74x2034.md) |
| 74x2040 | 8-bit Futurebus transceiver with split TTL I/O | Unknown | [pending](spec/chips/ttl_74x2040.md) |
| 74x2041 | 7-bit Futurebus transceiver with split TTL I/O | Unknown | [pending](spec/chips/ttl_74x2041.md) |
| 74x2107 | 12-bit GTL to 3.3V TTL level translator | Unknown | [pending](spec/chips/ttl_74x2107.md) |
| 74x2125 | quad bus buffer | Unknown | [implemented](spec/chips/ttl_74x2125.md) |
| 74x2140 | 8k x 18 cache data RAM | Unknown | [implemented](spec/chips/ttl_74x2140.md) |
| 74x2150 | 512 x 8 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2150.md) |
| 74x2152 | 2k x 8 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2152.md) |
| 74x2154 | 2k x 8 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2154.md) |
| 74x2155 | 2k x 8 burst cache address comparator | Unknown | [pending](spec/chips/ttl_74x2155.md) |
| 74x2156 | 16k x 4 burst cache address comparator | Unknown | [pending](spec/chips/ttl_74x2156.md) |
| 74x2158 | 8k x 9 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2158.md) |
| 74x2159 | 8k x 9 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2159.md) |
| 74x2160 | 8k x 4 2-way cache address comparator | Unknown | [pending](spec/chips/ttl_74x2160.md) |
| 74x2161 | synchronous presettable 4-bit binary counter, asynchronous clear | Unknown | [implemented](spec/chips/ttl_74x2161.md) |
| 74x2164 | 16k x 5 cache address comparator | Unknown | [pending](spec/chips/ttl_74x2164.md) |
| 74x2166 | 16k x 5 cache address comparator with input latches | Unknown | [pending](spec/chips/ttl_74x2166.md) |
| 74x2191 | synchronous presettable 4-bit binary up/down counter, up/down direction pin | Unknown | [implemented](spec/chips/ttl_74x2191.md) |
| 74x2193 | synchronous presettable 4-bit binary counter, separate up/down clocks | Unknown | [implemented](spec/chips/ttl_74x2193.md) |
| 74x2226 | dual 64-bit FIFO memories (64x1) | Unknown | [implemented](spec/chips/ttl_74x2226.md) |
| 74x2227 | dual 64-bit FIFO memories (64x1) | Unknown | [implemented](spec/chips/ttl_74x2227.md) |
| 74x2228 | dual 256-bit FIFO memories (256x1) | Unknown | [implemented](spec/chips/ttl_74x2228.md) |
| 74x2229 | dual 256-bit FIFO memories (256x1) | Unknown | [implemented](spec/chips/ttl_74x2229.md) |
| 74x2232 | 512-bit FIFO memory (64x8) | Unknown | [implemented](spec/chips/ttl_74x2232.md) |
| 74x2233 | 576-bit FIFO memory (64x9) | Unknown | [implemented](spec/chips/ttl_74x2233.md) |
| 74x2235 | 18432-bit bidirectional FIFO memory (2x1024x9) | Unknown | [implemented](spec/chips/ttl_74x2235.md) |
| 74x2236 | 18432-bit bidirectional FIFO memory (2x1024x9) | Unknown | [implemented](spec/chips/ttl_74x2236.md) |
| 74x2238 | 576-bit bidirectional FIFO memory (2x32x9) | Unknown | [implemented](spec/chips/ttl_74x2238.md) |
| 74x2240 | dual 4-bit bidirectional buffer / line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x2240.md) |
| 74x2241 | dual 4-bit bidirectional buffer / line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2241.md) |
| 74x2242 | 4-bit bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x2242.md) |
| 74x2243 | 4-bit bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2243.md) |
| 74x2244 | dual 4-bit buffer / line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2244.md) |
| 74x2245 | octal bus transceiver | Unknown | [implemented](spec/chips/ttl_74x2245.md) |
| 74x2253 | dual 4-line to 1-line multiplexer | Unknown | [implemented](spec/chips/ttl_74x2253.md) |
| 74x2257 | quad 2-line to 1-line multiplexer | Unknown | [implemented](spec/chips/ttl_74x2257.md) |
| 74x2273 | octal D-type flip-flop, shared clock and clear | Unknown | [implemented](spec/chips/ttl_74x2273.md) |
| 74x2299 | 8-bit universal shift register | Unknown | [implemented](spec/chips/ttl_74x2299.md) |
| 74x2323 | dual line receiver | Unknown | [pending](spec/chips/ttl_74x2323.md) |
| 74x2373 | 8-bit transparent latch | Unknown | [implemented](spec/chips/ttl_74x2373.md) |
| 74x2374 | octal D-type flip-flop, shared clock | Unknown | [implemented](spec/chips/ttl_74x2374.md) |
| 74x2377 | 8-bit register, clock enable | Unknown | [implemented](spec/chips/ttl_74x2377.md) |
| 74x2400 | dual 4-bit buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x2400.md) |
| 74x2410 | 11-bit MOS memory driver, non-inverting | Unknown | [pending](spec/chips/ttl_74x2410.md) |
| 74x2411 | 11-bit MOS memory driver, inverting | Unknown | [pending](spec/chips/ttl_74x2411.md) |
| 74x2414 | dual 2-to-4 line decoder with supply voltage monitor | Unknown | [pending](spec/chips/ttl_74x2414.md) |
| 74x2420 | 16-bit NuBus address/data transceiver and register | Unknown | [pending](spec/chips/ttl_74x2420.md) |
| 74x2423 | 16-bit latched multiplexer/demultiplexer NuBus transceiver, inverting | Unknown | [pending](spec/chips/ttl_74x2423.md) |
| 74x2424 | 16-bit latched multiplexer/demultiplexer NuBus transceiver, non-inverting | Unknown | [pending](spec/chips/ttl_74x2424.md) |
| 74x2425 | Macintosh Coprocessor Platform NuBus address/data registered transceiver | Unknown | [pending](spec/chips/ttl_74x2425.md) |
| 74x2440 | NuBus interface controller | Unknown | [pending](spec/chips/ttl_74x2440.md) |
| 74x2441 | NuBus interface controller | Unknown | [pending](spec/chips/ttl_74x2441.md) |
| 74x2442 | NuBus block slave address generator | Unknown | [pending](spec/chips/ttl_74x2442.md) |
| 74x2509 | 9-output clock driver with PLL | Unknown | [excluded](spec/chips/ttl_74x2509.md) |
| 74x2510 | 10-output clock driver with PLL | Unknown | [excluded](spec/chips/ttl_74x2510.md) |
| 74x2525 | 8-output clock driver | Unknown | [pending](spec/chips/ttl_74x2525.md) |
| 74x2526 | 8-output clock driver with input multiplexer | Unknown | [pending](spec/chips/ttl_74x2526.md) |
| 74x2533 | 8-bit bus interface latch, inverting | Unknown | [implemented](spec/chips/ttl_74x2533.md) |
| 74x2534 | 8-bit bus interface register, inverting | Unknown | [implemented](spec/chips/ttl_74x2534.md) |
| 74x2540 | 8-bit buffer / line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x2540.md) |
| 74x2541 | 8-bit buffer / line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2541.md) |
| 74x2543 | 8-bit latched transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2543.md) |
| 74x2544 | 8-bit latched transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x2544.md) |
| 74x2573 | 8-bit transparent latch | Unknown | [implemented](spec/chips/ttl_74x2573.md) |
| 74x2574 | octal D-type flip-flop, shared clock | Unknown | [implemented](spec/chips/ttl_74x2574.md) |
| 74x2620 | octal bus transceiver / MOS driver, inverting | Unknown | [pending](spec/chips/ttl_74x2620.md) |
| 74x2623 | octal bus transceiver / MOS driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2623.md) |
| 74x2640 | octal bus transceiver / MOS driver, inverting | Unknown | [implemented](spec/chips/ttl_74x2640.md) |
| 74x2643 | octal bus transceiver, mix of inverting and non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x2643.md) |
| 74x2645 | octal bus transceiver / MOS driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2645.md) |
| 74x2646 | octal registered transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2646.md) |
| 74x2648 | octal registered transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x2648.md) |
| 74x2651 | octal registered transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x2651.md) |
| 74x2652 | octal registered transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2652.md) |
| 74S2708 | 8192-bit PROM (1024x8) | Unknown | [implemented](spec/chips/ttl_74s2708.md) |
| 74x2725 | 4608-bit FIFO memory (512x9) | Unknown | [implemented](spec/chips/ttl_74x2725.md) |
| 74x2726 | 4608-bit bidirectional FIFO memory (512x9) | Unknown | [implemented](spec/chips/ttl_74x2726.md) |
| 74x2821 | 10-bit D-type flip-flop | Unknown | [implemented](spec/chips/ttl_74x2821.md) |
| 74x2823 | 9-bit D-type flip-flop with clear | Unknown | [implemented](spec/chips/ttl_74x2823.md) |
| 74x2825 | 8-bit D-type flip-flop with clear and clock enable | Unknown | [implemented](spec/chips/ttl_74x2825.md) |
| 74x2827 | 10-bit buffer, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2827.md) |
| 74x2828 | 10-bit buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x2828.md) |
| 74x2833 | 8-bit bus transceiver with parity error flip-flop | Unknown | [implemented](spec/chips/ttl_74x2833.md) |
| 74x2841 | 10-bit transparent latch | Unknown | [implemented](spec/chips/ttl_74x2841.md) |
| 74x2843 | 9-bit transparent latch with asynchronous reset | Unknown | [implemented](spec/chips/ttl_74x2843.md) |
| 74x2845 | 8-bit transparent latch with asynchronous reset and multiple output enable | Unknown | [implemented](spec/chips/ttl_74x2845.md) |
| 74x2853 | 8-bit bus transceiver with parity error latch | Unknown | [implemented](spec/chips/ttl_74x2853.md) |
| 74x2861 | 10-bit non-inverting bus transceiver | Unknown | [implemented](spec/chips/ttl_74x2861.md) |
| 74x2862 | 10-bit inverting bus transceiver | Unknown | [implemented](spec/chips/ttl_74x2862.md) |
| 74x2863 | 9-bit non-inverting bus transceiver with dual output enable | Unknown | [implemented](spec/chips/ttl_74x2863.md) |
| 74x2864 | 9-bit inverting bus transceiver with dual output enable | Unknown | [implemented](spec/chips/ttl_74x2864.md) |
| 74x2952 | octal bus transceiver and register, non-inverting | Unknown | [implemented](spec/chips/ttl_74x2952.md) |
| 74x2953 | octal bus transceiver and register, inverting | Unknown | [implemented](spec/chips/ttl_74x2953.md) |
| 74x2960 | error detection and correction (EDAC), equivalent to Am2960 | Unknown | [pending](spec/chips/ttl_74x2960.md) |
| 74x2961 | 4-bit EDAC bus buffer, inverting, equivalent to Am2961 | Unknown | [implemented](spec/chips/ttl_74x2961.md) |
| 74x2962 | 4-bit EDAC bus buffer, non-inverting, equivalent to Am2962 | Unknown | [implemented](spec/chips/ttl_74x2962.md) |
| 74x2967 | controller/driver for 16k/64k/256k dRAM | Unknown | [implemented](spec/chips/ttl_74x2967.md) |
| 74x2968 | controller/driver for 16k/64k/256k dRAM | Unknown | [implemented](spec/chips/ttl_74x2968.md) |
| 74x2969 | memory timing controller for use with EDAC | Unknown | [pending](spec/chips/ttl_74x2969.md) |
| 74x2970 | memory timing controller for use without EDAC | Unknown | [pending](spec/chips/ttl_74x2970.md) |
| 74x3004 | selectable GTL voltage reference | Unknown | [pending](spec/chips/ttl_74x3004.md) |
| 74x3037 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x3037.md) |
| 74x3038 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x3038.md) |
| 74x3040 | dual 4-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x3040.md) |
| 74x3125 | quad FET bus switch, output enable active low | Unknown | [pending](spec/chips/ttl_74x3125.md) |
| 74x3126 | quad FET bus switch, output enable active high | Unknown | [pending](spec/chips/ttl_74x3126.md) |
| 74x3251 | 8-line to 1-line FET multiplexer / demultiplexer | Unknown | [pending](spec/chips/ttl_74x3251.md) |
| 74x3253 | dual 4-line to 1-line FET multiplexer / demultiplexer | Unknown | [pending](spec/chips/ttl_74x3253.md) |
| 74x3257 | quad 2-line to 1-line FET multiplexer / demultiplexer | Unknown | [pending](spec/chips/ttl_74x3257.md) |
| 74x3283 | 32-bit latchable transceiver with parity checker / generator | Unknown | [implemented](spec/chips/ttl_74x3283.md) |
| 74x3284 | 18-bit synchronous datapath multiplexer | Unknown | [implemented](spec/chips/ttl_74x3284.md) |
| 74x3305 | dual FET bus switch with extended voltage range | Unknown | [pending](spec/chips/ttl_74x3305.md) |
| 74x3306 | dual FET bus switch | Unknown | [pending](spec/chips/ttl_74x3306.md) |
| 74x3345 | octal FET bus switch, dual output enable | Unknown | [pending](spec/chips/ttl_74x3345.md) |
| 74x3374 | 8-bit metastable-resistant D-type flip-flop | Unknown | [implemented](spec/chips/ttl_74x3374.md) |
| 74x3383 | 5-bit 4-port FET bus exchange switch | Unknown | [pending](spec/chips/ttl_74x3383.md) |
| 74x3384 | dual 5-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x3384.md) |
| 74x3386 | 5-bit 4-port FET bus exchange switch with extended voltage range | Unknown | [pending](spec/chips/ttl_74x3386.md) |
| 74x3390 | octal 2-line to 1-line FET multiplexer / bus switch | Unknown | [pending](spec/chips/ttl_74x3390.md) |
| 74x3573 | octal transparent latch | Unknown | [implemented](spec/chips/ttl_74x3573.md) |
| 74x3574 | octal D-type flip flop | Unknown | [implemented](spec/chips/ttl_74x3574.md) |
| 74x3584 | dual 5-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x3584.md) |
| 74x3611 | 2304-bit FIFO memory (64x36) | Unknown | [implemented](spec/chips/ttl_74x3611.md) |
| 74x3612 | 4608-bit bidirectional FIFO memory (2x64x36) | Unknown | [implemented](spec/chips/ttl_74x3612.md) |
| 74x3613 | 2304-bit FIFO memory (64x36) | Unknown | [implemented](spec/chips/ttl_74x3613.md) |
| 74x3614 | 4608-bit bidirectional FIFO memory (2x64x36) | Unknown | [implemented](spec/chips/ttl_74x3614.md) |
| 74x3622 | 18432-bit bidirectional FIFO memory (2x256x36) | Unknown | [implemented](spec/chips/ttl_74x3622.md) |
| 74x3631 | 18432-bit FIFO memory (512x36) | Unknown | [implemented](spec/chips/ttl_74x3631.md) |
| 74x3632 | 36864-bit bidirectional FIFO memory (2x512x36) | Unknown | [implemented](spec/chips/ttl_74x3632.md) |
| 74x3638 | 32768-bit bidirectional FIFO memory (2x512x32) | Unknown | [implemented](spec/chips/ttl_74x3638.md) |
| 74x3641 | 36864-bit FIFO memory (1024x36) | Unknown | [implemented](spec/chips/ttl_74x3641.md) |
| 74x3642 | 73728-bit bidirectional FIFO memory (2x1024x36) | Unknown | [implemented](spec/chips/ttl_74x3642.md) |
| 74x3651 | 73728-bit FIFO memory (2048x36) | Unknown | [implemented](spec/chips/ttl_74x3651.md) |
| 74x3708 | 8192-bit PROM (1024x8) | Unknown | [implemented](spec/chips/ttl_74x3708.md) |
| 74x3807 | 1-to-10 clock driver | Unknown | [pending](spec/chips/ttl_74x3807.md) |
| 74x3827 | 10-bit buffer | Unknown | [implemented](spec/chips/ttl_74x3827.md) |
| 74x3861 | 10-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x3861.md) |
| 74x3862 | 10-bit FET bus switch with dual output enable | Unknown | [pending](spec/chips/ttl_74x3862.md) |
| 74x3893 | quad Futurebus backplane transceiver | Unknown | [pending](spec/chips/ttl_74x3893.md) |
| 74x3907 | Pentium clock synthesizer | Unknown | [pending](spec/chips/ttl_74x3907.md) |
| 74x3932 | PLL-based clock driver | Unknown | [excluded](spec/chips/ttl_74x3932.md) |
| 74x4002 | dual 4-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x4002.md) |
| 74x4015 | dual 4-bit shift registers | Unknown | [implemented](spec/chips/ttl_74x4015.md) |
| 74x4016 | quad bilateral switch | Unknown | [pending](spec/chips/ttl_74x4016.md) |
| 74x4017 | 5-stage ÷10 Johnson counter | Unknown | [implemented](spec/chips/ttl_74x4017.md) |
| 74x4020 | 14-stage binary counter | Unknown | [implemented](spec/chips/ttl_74x4020.md) |
| 74x4022 | 4-stage ÷8 Johnson counter | Unknown | [implemented](spec/chips/ttl_74x4022.md) |
| 74x4024 | 7-stage ripple carry binary counter | Unknown | [implemented](spec/chips/ttl_74x4024.md) |
| 74x4028 | BCD to decimal decoder | Unknown | [implemented](spec/chips/ttl_74x4028.md) |
| 74x4040 | 12-stage binary ripple counter | Unknown | [implemented](spec/chips/ttl_74x4040.md) |
| 74x4046 | phase-locked loop and voltage-controlled oscillator | Unknown | [excluded](spec/chips/ttl_74x4046.md) |
| 74x4049 | hex inverting buffer | Unknown | [implemented](spec/chips/ttl_74x4049.md) |
| 74x4050 | hex buffer/converter (non-inverting) | Unknown | [implemented](spec/chips/ttl_74x4050.md) |
| 74x4051 | high-speed 8-channel analog multiplexer/demultiplexer | Unknown | [excluded](spec/chips/ttl_74x4051.md) |
| 74x4052 | dual 4-channel analog multiplexer/demultiplexers | Unknown | [excluded](spec/chips/ttl_74x4052.md) |
| 74x4053 | triple 2-channel analog multiplexer/demultiplexers | Unknown | [excluded](spec/chips/ttl_74x4053.md) |
| 74x4059 | programmable divide-by-N counter | Unknown | [pending](spec/chips/ttl_74x4059.md) |
| 74x4060 | 14-stage binary ripple counter with oscillator | Unknown | [pending](spec/chips/ttl_74x4060.md) |
| 74x4061 | 14-stage asynchronous binary counter with oscillator | Unknown | [pending](spec/chips/ttl_74x4061.md) |
| 74x4066 | quad single-pole single-throw analog switch | Unknown | [excluded](spec/chips/ttl_74x4066.md) |
| 74x4067 | 16-channel analog multiplexer/demultiplexer | Unknown | [excluded](spec/chips/ttl_74x4067.md) |
| 74x4072 | dual 4-input OR gate | Unknown | [implemented](spec/chips/ttl_74x4072.md) |
| 74x4075 | triple 3-input OR gate | Unknown | [implemented](spec/chips/ttl_74x4075.md) |
| 74x4078 | single 8-input OR/NOR gate | Unknown | [implemented](spec/chips/ttl_74x4078.md) |
| 74x4094 | 8-bit three-state shift register/latch | Unknown | [implemented](spec/chips/ttl_74x4094.md) |
| 74x4102 | 2-digit BCD presettable synchronous down counter | Unknown | [implemented](spec/chips/ttl_74x4102.md) |
| 74x4103 | 8-bit binary presettable synchronous down counter | Unknown | [implemented](spec/chips/ttl_74x4103.md) |
| 74x4245 | 8-bit 3V/5V translating transceiver | Unknown | [implemented](spec/chips/ttl_74x4245.md) |
| 74x4301 | 8-bit latch, inverting | Unknown | [implemented](spec/chips/ttl_74x4301.md) |
| 74x4302 | 8-bit latch, non-inverting | Unknown | [implemented](spec/chips/ttl_74x4302.md) |
| 74x4303 | 8-bit D-type flip-flop, inverting outputs | Unknown | [implemented](spec/chips/ttl_74x4303.md) |
| 74x4304 | 8-bit D-type flip-flop, non-inverting outputs | Unknown | [implemented](spec/chips/ttl_74x4304.md) |
| 74x4305 | dual 4-bit buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x4305.md) |
| 74x4306 | dual 4-bit buffer, non-inverting | Unknown | [implemented](spec/chips/ttl_74x4306.md) |
| 74x4316 | quad analog switch | Unknown | [excluded](spec/chips/ttl_74x4316.md) |
| 74x4351 | 8-channel analog multiplexer/demultiplexer with latch | Unknown | [excluded](spec/chips/ttl_74x4351.md) |
| 74x4352 | dual 4-channel analog multiplexer/demultiplexer with latch | Unknown | [excluded](spec/chips/ttl_74x4352.md) |
| 74x4353 | triple 2-channel analog multiplexer/demultiplexer with latch | Unknown | [excluded](spec/chips/ttl_74x4353.md) |
| 74x4374 | 8-bit dual-rank synchronizer | Unknown | [implemented](spec/chips/ttl_74x4374.md) |
| 74x4503 | controller for 64k/256k/1M dynamic RAM | Unknown | [pending](spec/chips/ttl_74x4503.md) |
| 74x4510 | BCD decade up/down counter | Unknown | [implemented](spec/chips/ttl_74x4510.md) |
| 74x4511 | BCD to 7-segment decoder | Unknown | [implemented](spec/chips/ttl_74x4511.md) |
| 74x4514 | 4-to-16 line decoder/demultiplexer, input latches | Unknown | [implemented](spec/chips/ttl_74x4514.md) |
| 74x4515 | 4-to-16 line decoder/demultiplexer with input latches; inverting | Unknown | [implemented](spec/chips/ttl_74x4515.md) |
| 74x4516 | 4-bit binary up/down counter | Unknown | [implemented](spec/chips/ttl_74x4516.md) |
| 74x4518 | dual 4-bit synchronous decade counter | Unknown | [implemented](spec/chips/ttl_74x4518.md) |
| 74x4520 | dual 4-bit synchronous binary counter | Unknown | [implemented](spec/chips/ttl_74x4520.md) |
| 74x4538 | dual retriggerable precision monostable multivibrator | Unknown | [excluded](spec/chips/ttl_74x4538.md) |
| 74x4543 | BCD to 7-segment latch/decoder/driver for LCDs | Unknown | [implemented](spec/chips/ttl_74x4543.md) |
| 74x4560 | 4-bit BCD adder | Unknown | [implemented](spec/chips/ttl_74x4560.md) |
| 74x4724 | 8-bit addressable latch | Unknown | [implemented](spec/chips/ttl_74x4724.md) |
| 74x4764 | programmable dRAM controller | Unknown | [pending](spec/chips/ttl_74x4764.md) |
| 74x4799 | Timer for NiCd and NiMH chargers | Unknown | [pending](spec/chips/ttl_74x4799.md) |
| 74x4851 | 8-channel analog multiplexer/demultiplexer | Unknown | [excluded](spec/chips/ttl_74x4851.md) |
| 74x4852 | dual 4-channel analog multiplexer/demultiplexer | Unknown | [excluded](spec/chips/ttl_74x4852.md) |
| 74x5074 | dual positive edge-triggered D-type flip-flop (metastable immune) | Unknown | [implemented](spec/chips/ttl_74x5074.md) |
| 74x5245 | octal bidirectional transceiver | Unknown | [implemented](spec/chips/ttl_74x5245.md) |
| 74x5300 | fiber optic LED driver | Unknown | [excluded](spec/chips/ttl_74x5300.md) |
| 74x5302 | dual fiber optic LED / clock driver | Unknown | [excluded](spec/chips/ttl_74x5302.md) |
| 74x5400 | 11-bit line/memory driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x5400.md) |
| 74x5401 | 11-bit line/memory driver, inverting | Unknown | [implemented](spec/chips/ttl_74x5401.md) |
| 74x5402 | 12-bit line/memory driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x5402.md) |
| 74x5403 | 12-bit line/memory driver, inverting | Unknown | [implemented](spec/chips/ttl_74x5403.md) |
| 74x5555 | programmable delay timer with oscillator | Unknown | [pending](spec/chips/ttl_74x5555.md) |
| 74x5620 | octal bidirectional transceiver | Unknown | [implemented](spec/chips/ttl_74x5620.md) |
| 74x6000 | logic-to-logic optocoupler, non-inverting | Unknown | [pending](spec/chips/ttl_74x6000.md) |
| 74x6001 | logic-to-logic optocoupler, inverting | Unknown | [pending](spec/chips/ttl_74x6001.md) |
| 74x6010 | logic-to-logic optocoupler, non-inverting | Unknown | [pending](spec/chips/ttl_74x6010.md) |
| 74x6011 | logic-to-logic optocoupler, inverting | Unknown | [pending](spec/chips/ttl_74x6011.md) |
| 74x6300 | programmable dynamic memory refresh timer | Unknown | [pending](spec/chips/ttl_74x6300.md) |
| 74x6301 | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | Unknown | [pending](spec/chips/ttl_74x6301.md) |
| 74x6302 | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | Unknown | [pending](spec/chips/ttl_74x6302.md) |
| 74x6310 | static column and page mode access detector for dRAM | Unknown | [pending](spec/chips/ttl_74x6310.md) |
| 74x6311 | static column and page mode access detector for dRAM | Unknown | [pending](spec/chips/ttl_74x6311.md) |
| 74x6323 | programmable ripple counter with oscillator | Unknown | [pending](spec/chips/ttl_74x6323.md) |
| 74x6364 | 64-bit flow-through error detection and correction circuit | Unknown | [pending](spec/chips/ttl_74x6364.md) |
| 74x6800 | 10-bit FET bus switch with precharge | Unknown | [pending](spec/chips/ttl_74x6800.md) |
| 74x6845 | 8-bit FET bus switch with precharge and extended voltage range | Unknown | [pending](spec/chips/ttl_74x6845.md) |
| 74x7001 | quad 2-input AND gate | Unknown | [implemented](spec/chips/ttl_74x7001.md) |
| 74x7002 | quad 2-input NOR gate | Unknown | [implemented](spec/chips/ttl_74x7002.md) |
| 74x7003 | quad 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x7003.md) |
| 74x7006 | two inverters, one 3-input NAND, one 4-input NAND, one 3-input NOR, one 4-input NOR | Unknown | [implemented](spec/chips/ttl_74x7006.md) |
| 74x7007 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x7007.md) |
| 74x7008 | two inverters, three 2-input NAND, three 2-input NOR | Unknown | [implemented](spec/chips/ttl_74x7008.md) |
| 74x7014 | hex buffer gate | Unknown | [implemented](spec/chips/ttl_74x7014.md) |
| 74x7022 | 4-stage ÷8 Johnson counter with power-up clear | Unknown | [implemented](spec/chips/ttl_74x7022.md) |
| 74x7030 | 576-bit FIFO memory (64x9) | Unknown | [implemented](spec/chips/ttl_74x7030.md) |
| 74x7032 | quad 2-input OR gates | Unknown | [implemented](spec/chips/ttl_74x7032.md) |
| 74x7038 | 9-bit bus transceiver with latch | Unknown | [implemented](spec/chips/ttl_74x7038.md) |
| 74x7046 | phase-locked loop with voltage-controlled oscillator and lock detector | Unknown | [excluded](spec/chips/ttl_74x7046.md) |
| 74x7060 | 14-stage binary counter with oscillator | Unknown | [pending](spec/chips/ttl_74x7060.md) |
| 74x7074 | two inverters, one 2-input NAND, one 2-input NOR, two D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x7074.md) |
| 74x7075 | two inverters, two 2-input NAND, two D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x7075.md) |
| 74x7076 | two inverters, two 2-input NOR, two D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x7076.md) |
| 74x7080 | 16-bit parity generator / checker | Unknown | [implemented](spec/chips/ttl_74x7080.md) |
| 74x7132 | quad adjustable comparator with output latches | Unknown | [excluded](spec/chips/ttl_74x7132.md) |
| 74x7200 | 2304-bit FIFO memory (256x9) | Unknown | [implemented](spec/chips/ttl_74x7200.md) |
| 74x7201 | 4608-bit FIFO memory (512x9) | Unknown | [implemented](spec/chips/ttl_74x7201.md) |
| 74x7202 | 9216-bit FIFO memory (1024x9) | Unknown | [implemented](spec/chips/ttl_74x7202.md) |
| 74x7203 | 18432-bit FIFO memory (2048x9) | Unknown | [implemented](spec/chips/ttl_74x7203.md) |
| 74x7205 | 73728-bit FIFO memory (8192x9) | Unknown | [implemented](spec/chips/ttl_74x7205.md) |
| 74x7206 | 147456-bit FIFO memory (16384x9) | Unknown | [implemented](spec/chips/ttl_74x7206.md) |
| 74x7240 | octal bus buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x7240.md) |
| 74x7241 | octal bus buffer, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7241.md) |
| 74x7244 | octal bus buffer, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7244.md) |
| 74x7245 | octal bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7245.md) |
| 74x7266 | quad 2-input XNOR gate | Unknown | [implemented](spec/chips/ttl_74x7266.md) |
| 74x7273 | octal positive edge-triggered D-type flip-flop with reset | Unknown | [implemented](spec/chips/ttl_74x7273.md) |
| 74x7292 | programmable divider/timer | Unknown | [implemented](spec/chips/ttl_74x7292.md) |
| 74x7294 | programmable divider/timer | Unknown | [implemented](spec/chips/ttl_74x7294.md) |
| 74x7340 | 8-bit bus driver with bidirectional registers | Unknown | [implemented](spec/chips/ttl_74x7340.md) |
| 74x7403 | 256-bit FIFO memory (64x4) | Unknown | [implemented](spec/chips/ttl_74x7403.md) |
| 74x7404 | 320-bit FIFO memory (64x5) | Unknown | [implemented](spec/chips/ttl_74x7404.md) |
| 74x7540 | octal buffer/line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x7540.md) |
| 74x7541 | octal buffer/line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7541.md) |
| 74x7597 | 8-bit shift register with input latches | Unknown | [implemented](spec/chips/ttl_74x7597.md) |
| 74x7623 | octal bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7623.md) |
| 74x7640 | octal bus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x7640.md) |
| 74x7643 | octal bus transceiver, non-inverting/inverting | Unknown | [implemented](spec/chips/ttl_74x7643.md) |
| 74x7645 | octal bus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x7645.md) |
| 74x7731 | quad 64-bit static shift register | Unknown | [implemented](spec/chips/ttl_74x7731.md) |
| 74x7793 | 8-bit noninverting transparent latch with readback | Unknown | [implemented](spec/chips/ttl_74x7793.md) |
| 74x7801 | 18432-bit FIFO memory (1024x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7801.md) |
| 74x7802 | 18432-bit FIFO memory (1024x18) | Unknown | [implemented](spec/chips/ttl_74x7802.md) |
| 74x7803 | 9216-bit FIFO memory (512x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7803.md) |
| 74x7804 | 9216-bit FIFO memory (512x18) | Unknown | [implemented](spec/chips/ttl_74x7804.md) |
| 74x7805 | 4608-bit FIFO memory (256x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7805.md) |
| 74x7806 | 4608-bit FIFO memory (256x18) | Unknown | [implemented](spec/chips/ttl_74x7806.md) |
| 74x7807 | 18432-bit FIFO memory (2048x9), clocked | Unknown | [implemented](spec/chips/ttl_74x7807.md) |
| 74x7808 | 18432-bit FIFO memory (2048x9) | Unknown | [implemented](spec/chips/ttl_74x7808.md) |
| 74x7811 | 18432-bit FIFO memory (1024x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7811.md) |
| 74x7813 | 1152-bit FIFO memory (64x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7813.md) |
| 74x7814 | 1152-bit FIFO memory (64x18) | Unknown | [implemented](spec/chips/ttl_74x7814.md) |
| 74x7815 | 4608-bit bidirectional FIFO memory(2x64x36) | Unknown | [implemented](spec/chips/ttl_74x7815.md) |
| 74x7816 | 4608-bit bidirectional FIFO memory(2x64x36) | Unknown | [implemented](spec/chips/ttl_74x7816.md) |
| 74x7817 | 2304-bit FIFO memory(64x36) | Unknown | [implemented](spec/chips/ttl_74x7817.md) |
| 74x7818 | 2304-bit FIFO memory(64x36) | Unknown | [implemented](spec/chips/ttl_74x7818.md) |
| 74x7819 | 18432-bit bidirectional FIFO memory (2x512x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7819.md) |
| 74x7820 | 18432-bit bidirectional FIFO memory (2x512x18) | Unknown | [implemented](spec/chips/ttl_74x7820.md) |
| 74x7821 | 32768-bit bidirectional FIFO memory (2x512x32) | Unknown | [implemented](spec/chips/ttl_74x7821.md) |
| 74x7822 | 32768-bit bidirectional FIFO memory (2x512x32), clocked | Unknown | [implemented](spec/chips/ttl_74x7822.md) |
| 74x7823 | 36864-bit FIFO memory (1024x36), clocked | Unknown | [implemented](spec/chips/ttl_74x7823.md) |
| 74x7881 | 18432-bit FIFO memory (1024x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7881.md) |
| 74x7882 | 36864-bit FIFO memory (2048x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7882.md) |
| 74x7884 | 73728-bit FIFO memory (4096x18), clocked | Unknown | [implemented](spec/chips/ttl_74x7884.md) |
| 74x8003 | dual 2-input NAND gate | Unknown | [implemented](spec/chips/ttl_74x8003.md) |
| 74x8151 | 10-bit inverting/non-inverting buffer | Unknown | [implemented](spec/chips/ttl_74x8151.md) |
| 74x8153 | 8-bit serial-to-parallel interface | Unknown | [implemented](spec/chips/ttl_74x8153.md) |
| 74x8154 | dual 16-bit counters with output registers | Unknown | [implemented](spec/chips/ttl_74x8154.md) |
| 74x8161 | 8-bit synchronous binary counter | Unknown | [implemented](spec/chips/ttl_74x8161.md) |
| 74x8240 | octal inverting buffer with JTAG port | Unknown | [pending](spec/chips/ttl_74x8240.md) |
| 74x8244 | octal non-inverting buffer with JTAG port | Unknown | [pending](spec/chips/ttl_74x8244.md) |
| 74x8245 | octal bus transceiver with JTAG port | Unknown | [pending](spec/chips/ttl_74x8245.md) |
| 74x8373 | octal D-type latch with JTAG port | Unknown | [pending](spec/chips/ttl_74x8373.md) |
| 74x8374 | octal D-type edge-triggered flip-flop with JTAG port | Unknown | [pending](spec/chips/ttl_74x8374.md) |
| 74x8400 | expandable error checker / corrector | Unknown | [pending](spec/chips/ttl_74x8400.md) |
| 74x8541 | 8-bit buffer, selectable inverting/non-inverting | Unknown | [implemented](spec/chips/ttl_74x8541.md) |
| 74x8543 | octal registered bus transceiver with JTAG port | Unknown | [pending](spec/chips/ttl_74x8543.md) |
| 74x8646 | octal bus transceiver and register with JTAG port | Unknown | [pending](spec/chips/ttl_74x8646.md) |
| 74x8652 | octal bus transceiver and register with JTAG port | Unknown | [pending](spec/chips/ttl_74x8652.md) |
| 74x8818 | 16-bit microprogram sequencer, cascadable | Unknown | [pending](spec/chips/ttl_74x8818.md) |
| 74x8832 | 32-bit registered ALU | Unknown | [pending](spec/chips/ttl_74x8832.md) |
| 74x8834 | 40-bit register file | Unknown | [pending](spec/chips/ttl_74x8834.md) |
| 74x8835 | 16-bit microprogram sequencer, cascadable | Unknown | [pending](spec/chips/ttl_74x8835.md) |
| 74x8836 | 32x32-bit multiplier/accumulator | Unknown | [pending](spec/chips/ttl_74x8836.md) |
| 74x8837 | 64-bit floating point unit | Unknown | [pending](spec/chips/ttl_74x8837.md) |
| 74x8838 | 64-bit barrel shifter | Unknown | [implemented](spec/chips/ttl_74x8838.md) |
| 74x8839 | 32-bit shuffle/exchange network | Unknown | [pending](spec/chips/ttl_74x8839.md) |
| 74x8840 | digital crossbar switch | Unknown | [pending](spec/chips/ttl_74x8840.md) |
| 74x8841 | digital crossbar switch | Unknown | [pending](spec/chips/ttl_74x8841.md) |
| 74x8847 | 64-bit floating point and integer unit | Unknown | [pending](spec/chips/ttl_74x8847.md) |
| 74x8867 | 32-bit vector processor unit | Unknown | [pending](spec/chips/ttl_74x8867.md) |
| 74x8952 | octal registered bus transceiver with JTAG port | Unknown | [pending](spec/chips/ttl_74x8952.md) |
| 74x8960 | 8-bit bidirectional latched FutureBus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x8960.md) |
| 74x8961 | 8-bit bidirectional latched FutureBus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x8961.md) |
| 74x8962 | 9-bit bidirectional latched FutureBus transceiver, inverting | Unknown | [implemented](spec/chips/ttl_74x8962.md) |
| 74x8963 | 9-bit bidirectional latched FutureBus transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x8963.md) |
| 74x8965 | 9-bit bidirectional latched FutureBus transceiver, latch select | Unknown | [implemented](spec/chips/ttl_74x8965.md) |
| 74x8966 | 9-bit bidirectional latched FutureBus transceiver, idle arbitration request / output | Unknown | [implemented](spec/chips/ttl_74x8966.md) |
| 74x8980 | JTAG test access port master with 8-bit host interface | Unknown | [pending](spec/chips/ttl_74x8980.md) |
| 74x8986 | linkable, multidrop-addressable JTAG transceiver | Unknown | [pending](spec/chips/ttl_74x8986.md) |
| 74x8990 | JTAG test access port master with 16-bit host interface | Unknown | [pending](spec/chips/ttl_74x8990.md) |
| 74x8994 | JTAG scan-controlled logic/signature analyzer | Unknown | [pending](spec/chips/ttl_74x8994.md) |
| 74x8996 | multidrop-addressable JTAG transceiver | Unknown | [pending](spec/chips/ttl_74x8996.md) |
| 74x8997 | scan-controlled JTAG concatenator | Unknown | [pending](spec/chips/ttl_74x8997.md) |
| 74x8999 | scan-controlled JTAG multiplexer | Unknown | [pending](spec/chips/ttl_74x8999.md) |
| 74x9000 | programmable timer with oscillator | Unknown | [pending](spec/chips/ttl_74x9000.md) |
| 74x9014 | nine-wide buffer/line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x9014.md) |
| 74x9015 | nine-wide buffer/line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x9015.md) |
| 74x9034 | nine-wide buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x9034.md) |
| 74x9035 | nine-wide buffer, noninverting | Unknown | [implemented](spec/chips/ttl_74x9035.md) |
| 74x9046 | PLL with band gap controlled VCO | Unknown | [excluded](spec/chips/ttl_74x9046.md) |
| 74x9114 | nine-wide inverter | Unknown | [implemented](spec/chips/ttl_74x9114.md) |
| 74x9115 | nine-wide buffer | Unknown | [implemented](spec/chips/ttl_74x9115.md) |
| 74x9134 | nine-wide buffer, inverting | Unknown | [implemented](spec/chips/ttl_74x9134.md) |
| 74x9135 | nine-wide buffer, noninverting | Unknown | [implemented](spec/chips/ttl_74x9135.md) |
| 74x9164 | 8-bit shift register (serial in/out, parallel in/out) | Unknown | [implemented](spec/chips/ttl_74x9164.md) |
| 74x9240 | 9-bit buffer / line driver, inverting | Unknown | [implemented](spec/chips/ttl_74x9240.md) |
| 74x9244 | 9-bit buffer / line driver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x9244.md) |
| 74x9245 | 9-bit bidirectional transceiver, non-inverting | Unknown | [implemented](spec/chips/ttl_74x9245.md) |
| 74x9323 | programmable ripple counter with oscillator | Unknown | [pending](spec/chips/ttl_74x9323.md) |
| 74x9510 | 16×16-bit multiplier/accumulator (compatible to Am29510 and TDC1010) | Unknown | [pending](spec/chips/ttl_74x9510.md) |
| 74x9541 | 8-bit buffer / line driver, inverting / non-inverting | Unknown | [implemented](spec/chips/ttl_74x9541.md) |
| 74x9595 | 8-bit shift register with latch (serial in, parallel out) | Unknown | [implemented](spec/chips/ttl_74x9595.md) |
| 74x40102 | presettable synchronous 2-decade BCD down counter | Unknown | [implemented](spec/chips/ttl_74x40102.md) |
| 74x40103 | presettable 8-bit synchronous down counter | Unknown | [implemented](spec/chips/ttl_74x40103.md) |
| 74x40104 | 4-bit bidirectional universal shift register | Unknown | [implemented](spec/chips/ttl_74x40104.md) |
| 74x40105 | 64-bit FIFO memory (16x4) | Unknown | [implemented](spec/chips/ttl_74x40105.md) |
| 74x1616 | 17-bit LVTTL-to-GTLP adjustable edge rate universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x1616.md) |
| 74x1645 | 16-bit LVTTL-to-GTLP adjustable edge rate bus transceiver | Unknown | [pending](spec/chips/ttl_74x1645.md) |
| 74x16209 | 18-bit FET bus exchange switches | Unknown | [pending](spec/chips/ttl_74x16209.md) |
| 74x16210 | 20-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x16210.md) |
| 74x16211 | 24-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x16211.md) |
| 74x16212 | 24-bit FET bus exchange switches | Unknown | [pending](spec/chips/ttl_74x16212.md) |
| 74x16213 | 24-bit FET bus exchange switches | Unknown | [pending](spec/chips/ttl_74x16213.md) |
| 74x16214 | 12-bit 1-of-3 FET multiplexer/demultiplexer | Unknown | [pending](spec/chips/ttl_74x16214.md) |
| 74x16222 | 22-bit voltage clamp | Unknown | [excluded](spec/chips/ttl_74x16222.md) |
| 74x16232 | synchronous 16-bit 1-of-2 FET multiplexer/demultiplexer | Unknown | [pending](spec/chips/ttl_74x16232.md) |
| 74x16233 | 16-bit 1-of-2 FET multiplexer/demultiplexer | Unknown | [pending](spec/chips/ttl_74x16233.md) |
| 74x16240 | 16-bit inverting buffer/driver with grouped 4-bit output enables (all active-low) | Unknown | [implemented](spec/chips/ttl_74x16240.md) |
| 74x16241 | 16-bit non-inverting buffer/driver with grouped 4-bit output enables (1 and 4 active-low) | Unknown | [pending](spec/chips/ttl_74x16241.md) |
| 74x16244 | 16-bit non-inverting buffer/driver with grouped 4-bit output enables (all active-low) | Unknown | [implemented](spec/chips/ttl_74x16244.md) |
| 74x16245 | 16-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16245.md) |
| 74x16246 | 11-bit incident wave switching bus transceiver | Unknown | [pending](spec/chips/ttl_74x16246.md) |
| 74x16260 | 12-bit to 24-bit multiplexed D-type latches | Unknown | [pending](spec/chips/ttl_74x16260.md) |
| 74x16269 | 12-bit to 24-bit registered bus exchanger | Unknown | [pending](spec/chips/ttl_74x16269.md) |
| 74x16270 | 12-bit to 24-bit registered bus exchanger | Unknown | [pending](spec/chips/ttl_74x16270.md) |
| 74x16271 | 12-bit to 24-bit multiplexed bus exchanger | Unknown | [pending](spec/chips/ttl_74x16271.md) |
| 74x16282 | 18-bit to 36-bit registered bus exchanger | Unknown | [pending](spec/chips/ttl_74x16282.md) |
| 74x16292 | 12-bit 1-of-2 FET multiplexer/demultiplexer | Unknown | [pending](spec/chips/ttl_74x16292.md) |
| 74x16334 | 16-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x16334.md) |
| 74x16344 | 1-bit to 4-bit address driver | Unknown | [pending](spec/chips/ttl_74x16344.md) |
| 74x16373 | 16-bit transparent D-type latches | Unknown | [implemented](spec/chips/ttl_74x16373.md) |
| 74x16374 | 16-bit edge-triggered D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x16374.md) |
| 74x16377 | 16-bit edge-triggered D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x16377.md) |
| 74x16390 | 16-bit to 32-bit FET multiplexer/demultiplexer bus switch | Unknown | [pending](spec/chips/ttl_74x16390.md) |
| 74x16409 | 9-bit 4-port universal bus exchanger | Unknown | [pending](spec/chips/ttl_74x16409.md) |
| 74x16460 | 4-to-1 multiplexed/demultiplexed registered transceiver | Unknown | [pending](spec/chips/ttl_74x16460.md) |
| 74x16470 | 16-bit registered transceiver | Unknown | [pending](spec/chips/ttl_74x16470.md) |
| 74x16500 | 18-bit universal bus transceiver (registered, active low clock) | Unknown | [pending](spec/chips/ttl_74x16500.md) |
| 74x16501 | 18-bit universal bus transceiver (registered, active high clock) | Unknown | [pending](spec/chips/ttl_74x16501.md) |
| 74x16524 | 18-bit registered bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16524.md) |
| 74x16525 | 18-bit registered bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16525.md) |
| 74x16540 | 16-bit inverting buffer/driver with grouped 8-bit output enables (active-low) | Unknown | [implemented](spec/chips/ttl_74x16540.md) |
| 74x16541 | 16-bit non-inverting buffer/driver with grouped 8-bit output enables (active-low) | Unknown | [implemented](spec/chips/ttl_74x16541.md) |
| 74x16543 | 16-bit registered tranceiver | Unknown | [implemented](spec/chips/ttl_74x16543.md) |
| 74x16600 | 18-bit universal bus transceiver (registered, active low clock) | Unknown | [pending](spec/chips/ttl_74x16600.md) |
| 74x16601 | 18-bit universal bus transceiver (registered, active high clock) | Unknown | [pending](spec/chips/ttl_74x16601.md) |
| 74x16612 | 18-bit LVTTL-to-GTL+ universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x16612.md) |
| 74x16616 | 17-bit LVTTL-to-GTL+ universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x16616.md) |
| 74x16620 | 16-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16620.md) |
| 74x16622 | 18-bit LVTTL-to-GTL+ bus transceiver | Unknown | [pending](spec/chips/ttl_74x16622.md) |
| 74x16623 | 16-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16623.md) |
| 74x16640 | 16-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16640.md) |
| 74x16646 | 16-bit bus transceiver and registers | Unknown | [pending](spec/chips/ttl_74x16646.md) |
| 74x16648 | 16-bit bus transceiver and registers | Unknown | [pending](spec/chips/ttl_74x16648.md) |
| 74x16651 | 16-bit bus transceiver and registers | Unknown | [pending](spec/chips/ttl_74x16651.md) |
| 74x16652 | 16-bit bus transceiver and registers | Unknown | [pending](spec/chips/ttl_74x16652.md) |
| 74x16657 | 16-bit bus transceiver with parity generators/checkers | Unknown | [pending](spec/chips/ttl_74x16657.md) |
| 74x16721 | 3.3-V 20-bit flip-flop | Unknown | [implemented](spec/chips/ttl_74x16721.md) |
| 74x16722 | 22-bit flip-flop | Unknown | [implemented](spec/chips/ttl_74x16722.md) |
| 74x16800 | 20-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x16800.md) |
| 74x16811 | 24-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x16811.md) |
| 74x16820 | 3.3-V 10-bit flip-flop with dual outputs | Unknown | [implemented](spec/chips/ttl_74x16820.md) |
| 74x16821 | 20-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x16821.md) |
| 74x16823 | 18-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x16823.md) |
| 74x16825 | 18-bit non-inverting bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x16825.md) |
| 74x16826 | 18-bit inverting bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x16826.md) |
| 74x16827 | 20-bit non-inverting bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x16827.md) |
| 74x16828 | 20-bit inverting bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x16828.md) |
| 74x16831 | 1-to-4 address register/driver | Unknown | [pending](spec/chips/ttl_74x16831.md) |
| 74x16832 | 1-to-4 address register/driver | Unknown | [pending](spec/chips/ttl_74x16832.md) |
| 74x16833 | dual 8-bit to 9-bit parity bus transceivers | Unknown | [pending](spec/chips/ttl_74x16833.md) |
| 74x16834 | 18-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x16834.md) |
| 74x16835 | 18-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x16835.md) |
| 74x16841 | 20-bit bus interface D-type latches | Unknown | [implemented](spec/chips/ttl_74x16841.md) |
| 74x16843 | 18-bit bus interface D-type latches | Unknown | [implemented](spec/chips/ttl_74x16843.md) |
| 74x16853 | dual 8-bit to 9-bit parity bus transceiver | Unknown | [pending](spec/chips/ttl_74x16853.md) |
| 74x16857 | 14-bit registered buffer | Unknown | [pending](spec/chips/ttl_74x16857.md) |
| 74x16859 | 13-bit to 26-bit registered buffer | Unknown | [pending](spec/chips/ttl_74x16859.md) |
| 74x16861 | 20-bit FET bus switch | Unknown | [pending](spec/chips/ttl_74x16861.md) |
| 74x16863 | 18-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x16863.md) |
| 74x16901 | 18-bit universal bus transceiver with parity generators/checkers | Unknown | [pending](spec/chips/ttl_74x16901.md) |
| 74x16903 | 3.3-V 12-bit universal bus driver with parity checker | Unknown | [pending](spec/chips/ttl_74x16903.md) |
| 74x16912 | 18-bit LVTTL-to-GTLP universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x16912.md) |
| 74x16916 | 17-bit LVTTL-to-GTLP universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x16916.md) |
| 74x16923 | 18-bit LVTTL-to-GTLP universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x16923.md) |
| 74x16945 | 16-bit LVTTL-to-GTLP bus transceiver | Unknown | [pending](spec/chips/ttl_74x16945.md) |
| 74x16952 | 16-bit registered transceiver | Unknown | [pending](spec/chips/ttl_74x16952.md) |
| 74x16973 | 8-bit bus transceiver and transparent D-type latch | Unknown | [implemented](spec/chips/ttl_74x16973.md) |
| 74x161284 | 19-bit bus interface | Unknown | [implemented](spec/chips/ttl_74x161284.md) |
| 74x162240 | 3.3-V ABT 16-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x162240.md) |
| 74x162241 | 3.3-V ABT 16-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x162241.md) |
| 74x162244 | 16-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x162244.md) |
| 74x162245 | 16-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x162245.md) |
| 74x162260 | 12-bit to 24-bit multiplexed D-type latch | Unknown | [pending](spec/chips/ttl_74x162260.md) |
| 74x162268 | 12-bit to 24-bit registered bus exchanger | Unknown | [pending](spec/chips/ttl_74x162268.md) |
| 74x162280 | 16-bit to 32-bit registered bus exchanger with byte masks | Unknown | [pending](spec/chips/ttl_74x162280.md) |
| 74x162282 | 18-bit to 36-bit registered bus exchanger | Unknown | [pending](spec/chips/ttl_74x162282.md) |
| 74x162292 | 12-bit 1-of-2 FET multiplexer/demultiplexer | Unknown | [pending](spec/chips/ttl_74x162292.md) |
| 74x162334 | 16-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x162334.md) |
| 74x162344 | 1-bit to 4-bit address driver | Unknown | [pending](spec/chips/ttl_74x162344.md) |
| 74x162373 | 3.3-V ABT 16-bit transparent D-type latch | Unknown | [implemented](spec/chips/ttl_74x162373.md) |
| 74x162374 | 3.3-V ABT 16-bit edge triggered D-type flip-flop | Unknown | [implemented](spec/chips/ttl_74x162374.md) |
| 74x162460 | 4-to-1 multiplexed/demultiplexed registered transceiver | Unknown | [pending](spec/chips/ttl_74x162460.md) |
| 74x162500 | 18-bit universal bus transceiver | Unknown | [pending](spec/chips/ttl_74x162500.md) |
| 74x162501 | 18-bit registered transceiver | Unknown | [pending](spec/chips/ttl_74x162501.md) |
| 74x162525 | 18-bit registered bus transceiver | Unknown | [pending](spec/chips/ttl_74x162525.md) |
| 74x162541 | 3.3-V ABT 16-bit buffers/drivers | Unknown | [implemented](spec/chips/ttl_74x162541.md) |
| 74x162543 | 16-bit latched transceiver | Unknown | [pending](spec/chips/ttl_74x162543.md) |
| 74x162601 | 18-bit universal bus tranceiver | Unknown | [pending](spec/chips/ttl_74x162601.md) |
| 74x162646 | 16-bit registered transceiver | Unknown | [pending](spec/chips/ttl_74x162646.md) |
| 74x162652 | 16-bit registered transceiver | Unknown | [pending](spec/chips/ttl_74x162652.md) |
| 74x162721 | 3.3-V 20-bit flip-flop | Unknown | [implemented](spec/chips/ttl_74x162721.md) |
| 74x162820 | 3.3-V 10-bit flip-flop | Unknown | [implemented](spec/chips/ttl_74x162820.md) |
| 74x162821 | 20-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x162821.md) |
| 74x162823 | 18-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x162823.md) |
| 74x162825 | 18-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x162825.md) |
| 74x162827 | 20-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x162827.md) |
| 74x162830 | 1-bit to 2-bit address driver | Unknown | [pending](spec/chips/ttl_74x162830.md) |
| 74x162831 | 1-bit to 4-bit address register/driver | Unknown | [pending](spec/chips/ttl_74x162831.md) |
| 74x162832 | 1-bit to 4-bit address register/driver | Unknown | [pending](spec/chips/ttl_74x162832.md) |
| 74x162834 | 3.3-V CMOS 18-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x162834.md) |
| 74x162835 | 18-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x162835.md) |
| 74x162836 | 20-bit universal bus driver | Unknown | [pending](spec/chips/ttl_74x162836.md) |
| 74x162841 | 20-bit bus interface D-type latch | Unknown | [implemented](spec/chips/ttl_74x162841.md) |
| 74x164245 | 16-bit dual supply bus transceiver | Unknown | [implemented](spec/chips/ttl_74x164245.md) |
| 74x18245 | scan test devices with 18-bit bus transceivers | Unknown | [pending](spec/chips/ttl_74x18245.md) |
| 74x18502 | scan test devices with 18-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x18502.md) |
| 74x18504 | scan test devices with 20-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x18504.md) |
| 74x18512 | scan test devices with 18-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x18512.md) |
| 74x18640 | scan test devices with 18-bit inverting bus transceivers | Unknown | [pending](spec/chips/ttl_74x18640.md) |
| 74x18646 | scan test devices with 18-bit transceivers and registers | Unknown | [pending](spec/chips/ttl_74x18646.md) |
| 74x18652 | scan test devices with 18-bit transceivers and registers | Unknown | [pending](spec/chips/ttl_74x18652.md) |
| 74x182502 | scan test devices with 18-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x182502.md) |
| 74x182504 | scan test devices with 20-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x182504.md) |
| 74x182512 | scan test devices with 18-bit universal bus transceivers | Unknown | [pending](spec/chips/ttl_74x182512.md) |
| 74x182646 | scan test devices with 18-bit transceivers and registers | Unknown | [pending](spec/chips/ttl_74x182646.md) |
| 74x182652 | scan test devices with 18-bit transceivers and registers | Unknown | [pending](spec/chips/ttl_74x182652.md) |
| 74x20245 | 20-bit dual supply bus transceiver | Unknown | [implemented](spec/chips/ttl_74x20245.md) |
| 74x22033 | 8-bit LVTTL-to-GTLP adjustable edge rate registered transceiver | Unknown | [pending](spec/chips/ttl_74x22033.md) |
| 74x22501 | 8-bit universal bus transceiver and two 1-bit bus transceivers | Unknown | [implemented](spec/chips/ttl_74x22501.md) |
| 74x25244 | 25-Ω octal bus transceiver | Unknown | [implemented](spec/chips/ttl_74x25244.md) |
| 74x25245 | 25-Ω octal bus transceiver | Unknown | [implemented](spec/chips/ttl_74x25245.md) |
| 74x25642 | 25-Ω octal bus transceiver | Unknown | [implemented](spec/chips/ttl_74x25642.md) |
| 74x29821 | 10-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x29821.md) |
| 74x29825 | 8-bit bus interface flip-flops | Unknown | [implemented](spec/chips/ttl_74x29825.md) |
| 74x29827 | 10-bit bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x29827.md) |
| 74x29828 | 10-bit bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x29828.md) |
| 74x29841 | 10-bit bus interface D-type latches | Unknown | [implemented](spec/chips/ttl_74x29841.md) |
| 74x29843 | 9-bit bus interface D-type latches | Unknown | [implemented](spec/chips/ttl_74x29843.md) |
| 74x29854 | 8-bit to 9-bit parity bus transceiver | Unknown | [implemented](spec/chips/ttl_74x29854.md) |
| 74x29863 | 9-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x29863.md) |
| 74x29864 | 9-bit bus transceiver | Unknown | [implemented](spec/chips/ttl_74x29864.md) |
| 74x32240 | 32-bit bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x32240.md) |
| 74x32244 | 32-bit bus buffer/driver | Unknown | [implemented](spec/chips/ttl_74x32244.md) |
| 74x32245 | 36-bit bus tranceiver | Unknown | [implemented](spec/chips/ttl_74x32245.md) |
| 74x32316 | 16-bit tri-port universal bus exchangers | Unknown | [pending](spec/chips/ttl_74x32316.md) |
| 74x32318 | 18-bit tri-port universal bus exchangers | Unknown | [pending](spec/chips/ttl_74x32318.md) |
| 74x32373 | 32-bit D-type latches | Unknown | [implemented](spec/chips/ttl_74x32373.md) |
| 74x32374 | 32-bit D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x32374.md) |
| 74x32501 | 36-bit universal bus transceiver | Unknown | [implemented](spec/chips/ttl_74x32501.md) |
| 74x32543 | 36-bit registered bus transceiver | Unknown | [implemented](spec/chips/ttl_74x32543.md) |
| 74x32973 | 16-bit bus transceiver and transparent D-type latch | Unknown | [implemented](spec/chips/ttl_74x32973.md) |
| 74x322244 | 32-bit buffer/driver | Unknown | [implemented](spec/chips/ttl_74x322244.md) |
| 74x322374 | 32-bit D-type flip-flops | Unknown | [implemented](spec/chips/ttl_74x322374.md) |
| 74x324245 | 32-bit dual supply bus transceiver | Unknown | [implemented](spec/chips/ttl_74x324245.md) |
