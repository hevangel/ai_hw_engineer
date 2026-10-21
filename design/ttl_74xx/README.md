# Classic 7400–74299 digital logic library

The shared 74-series folder contains **289 distinct digital function models**,
their testbenches and specifications. Seven RC/analog timing devices are explicitly
excluded: 7431, 74121, 74122, 74123, 74124, 74130 and 74221. Unassigned part numbers
are not invented. Schmitt gates retain their Boolean function without hysteresis.
The numeric range and pure-digital scope were approved on 2026-10-20.

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

All 289 modules receive strict Verilator RTL lint, xezim simulation and Yosys
synthesis/structural checks. Independent formal truth tables cover 46 gate modules;
additional formal contracts cover counter, shift and symbolic-address RAM behavior,
plus bounded FIFO ordering and reachable full/empty states. These targeted formal
checks are not a claim of exhaustive formal coverage for every one of the 289
devices. The original 74181 retains its full exhaustive/UVM/prove/cover flow.
Source fingerprints prevent successful stale phase results from being reused.

- [Library specification](spec/spec.md)
- [Implementation plan](plans/library_plan.md)
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

## Chip index

`Unknown*` means the exact first-introduced year has not been established, not
that the device is undocumented. Follow the specification link for manufacturer
sources and interface details.

| Chip/function | Description | First introduced | Specification |
|---|---|---|---|
| 74x00 | quad 2-input NAND gate | Unknown* | [ttl_74x00](spec/chips/ttl_74x00.md) |
| 74x01 | quad 2-input NAND gate; different pinout for 74H01 | Unknown* | [ttl_74x01](spec/chips/ttl_74x01.md) |
| 74x02 | quad 2-input NOR gate | Unknown* | [ttl_74x02](spec/chips/ttl_74x02.md) |
| 74x03 | quad 2-input NAND gate | Unknown* | [ttl_74x03](spec/chips/ttl_74x03.md) |
| 74x04 | hex inverter gate | Unknown* | [ttl_74x04](spec/chips/ttl_74x04.md) |
| 74x05 | hex inverter gate | Unknown* | [ttl_74x05](spec/chips/ttl_74x05.md) |
| 74x06 | hex inverter gate | Unknown* | [ttl_74x06](spec/chips/ttl_74x06.md) |
| 74x07 | hex buffer gate | Unknown* | [ttl_74x07](spec/chips/ttl_74x07.md) |
| 74x08 | quad 2-input AND gate | Unknown* | [ttl_74x08](spec/chips/ttl_74x08.md) |
| 74x09 | quad 2-input AND gate | Unknown* | [ttl_74x09](spec/chips/ttl_74x09.md) |
| 74x10 | triple 3-input NAND gate | Unknown* | [ttl_74x10](spec/chips/ttl_74x10.md) |
| 74x11 | triple 3-input AND gate | Unknown* | [ttl_74x11](spec/chips/ttl_74x11.md) |
| 74x12 | triple 3-input NAND gate | Unknown* | [ttl_74x12](spec/chips/ttl_74x12.md) |
| 74x13 | dual 4-input NAND gate | Unknown* | [ttl_74x13](spec/chips/ttl_74x13.md) |
| 74x14 | hex inverter gate | Unknown* | [ttl_74x14](spec/chips/ttl_74x14.md) |
| 74x15 | triple 3-input AND gate | Unknown* | [ttl_74x15](spec/chips/ttl_74x15.md) |
| 74x16 | hex inverter gate | Unknown* | [ttl_74x16](spec/chips/ttl_74x16.md) |
| 74x17 | hex buffer gate | Unknown* | [ttl_74x17](spec/chips/ttl_74x17.md) |
| 74x18 | dual 4-input NAND gate | Unknown* | [ttl_74x18](spec/chips/ttl_74x18.md) |
| 74x19 | hex inverter gate | Unknown* | [ttl_74x19](spec/chips/ttl_74x19.md) |
| 74x20 | dual 4-input NAND gate | Unknown* | [ttl_74x20](spec/chips/ttl_74x20.md) |
| 74x21 | dual 4-input AND gate | Unknown* | [ttl_74x21](spec/chips/ttl_74x21.md) |
| 74x22 | dual 4-input NAND gate | Unknown* | [ttl_74x22](spec/chips/ttl_74x22.md) |
| 74x23 | dual 4-input NOR gate with strobe, one gate expandable with 74x60 | Unknown* | [ttl_74x23](spec/chips/ttl_74x23.md) |
| 74x24 | quad 2-input NAND gate | Unknown* | [ttl_74x24](spec/chips/ttl_74x24.md) |
| 74x25 | dual 4-input NOR gate with strobe | Unknown* | [ttl_74x25](spec/chips/ttl_74x25.md) |
| 74x26 | quad 2-input NAND gate | Unknown* | [ttl_74x26](spec/chips/ttl_74x26.md) |
| 74x27 | triple 3-input NOR gate | Unknown* | [ttl_74x27](spec/chips/ttl_74x27.md) |
| 74x28 | quad 2-input NOR gate | Unknown* | [ttl_74x28](spec/chips/ttl_74x28.md) |
| 74x29 | dual 4-input NOR gate | Unknown* | [ttl_74x29](spec/chips/ttl_74x29.md) |
| 74x30 | single 8-input NAND gate | Unknown* | [ttl_74x30](spec/chips/ttl_74x30.md) |
| 74x32 | quad 2-input OR gate | Unknown* | [ttl_74x32](spec/chips/ttl_74x32.md) |
| 74x33 | quad 2-input NOR gate | Unknown* | [ttl_74x33](spec/chips/ttl_74x33.md) |
| 74x34 | hex buffer gate | Unknown* | [ttl_74x34](spec/chips/ttl_74x34.md) |
| 74x35 | hex buffer gate | Unknown* | [ttl_74x35](spec/chips/ttl_74x35.md) |
| 74x36 | quad 2-input NOR gate (different pinout than 7402) | Unknown* | [ttl_74x36](spec/chips/ttl_74x36.md) |
| 74x37 | quad 2-input NAND gate | Unknown* | [ttl_74x37](spec/chips/ttl_74x37.md) |
| 74x38 | quad 2-input NAND gate | Unknown* | [ttl_74x38](spec/chips/ttl_74x38.md) |
| 74x39 | quad 2-input NAND gate (different pinout than 7438) | Unknown* | [ttl_74x39](spec/chips/ttl_74x39.md) |
| 74x40 | dual 4-input NAND gate | Unknown* | [ttl_74x40](spec/chips/ttl_74x40.md) |
| 74x41 | BCD to decimal decoder / Nixie tube driver | Unknown* | [ttl_74x41](spec/chips/ttl_74x41.md) |
| 74x42 | BCD to decimal decoder | Unknown* | [ttl_74x42](spec/chips/ttl_74x42.md) |
| 74x43 | excess-3 to decimal decoder | Unknown* | [ttl_74x43](spec/chips/ttl_74x43.md) |
| 74x44 | Gray code to decimal decoder | Unknown* | [ttl_74x44](spec/chips/ttl_74x44.md) |
| 74x45 | BCD to decimal decoder/driver | Unknown* | [ttl_74x45](spec/chips/ttl_74x45.md) |
| 74x46 | BCD to 7-segment display decoder/driver | Unknown* | [ttl_74x46](spec/chips/ttl_74x46.md) |
| 74x47 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x47](spec/chips/ttl_74x47.md) |
| 74x48 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x48](spec/chips/ttl_74x48.md) |
| 74x49 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x49](spec/chips/ttl_74x49.md) |
| 74x50 | dual 2-2-input AND-OR-Invert gate, one gate expandable | Unknown* | [ttl_74x50](spec/chips/ttl_74x50.md) |
| 7451 | dual 2-2-input AND-OR-Invert (AOI) gate | Unknown* | [ttl_7451](spec/chips/ttl_7451.md) |
| 74L51 | 3-3-input AND-OR-Invert gate and 2-2-input AND-OR-Invert gate | Unknown* | [ttl_74l51](spec/chips/ttl_74l51.md) |
| 74x52 | 3-2-2-2-input AND-OR gate, expandable with 74x61 | Unknown* | [ttl_74x52](spec/chips/ttl_74x52.md) |
| 7453 | 2-2-2-2-input AND-OR-Invert gate, expandable | Unknown* | [ttl_7453](spec/chips/ttl_7453.md) |
| 74H53 | 3-2-2-2-input AND-OR-Invert gate, expandable | Unknown* | [ttl_74h53](spec/chips/ttl_74h53.md) |
| 7454 | 2-2-2-2-input AND-OR-Invert gate | Unknown* | [ttl_7454](spec/chips/ttl_7454.md) |
| 74H54 | 3-2-2-2-input AND-OR-Invert gate | Unknown* | [ttl_74h54](spec/chips/ttl_74h54.md) |
| 74L54 | 3-3-2-2-input AND-OR-Invert gate | Unknown* | [ttl_74l54](spec/chips/ttl_74l54.md) |
| 74x55 | 4-4-input AND-OR-Invert gate, 74H55 is expandable | Unknown* | [ttl_74x55](spec/chips/ttl_74x55.md) |
| 74x56 | 50:1 frequency divider | Unknown* | [ttl_74x56](spec/chips/ttl_74x56.md) |
| 74x57 | 60:1 frequency divider | Unknown* | [ttl_74x57](spec/chips/ttl_74x57.md) |
| 74x58 | 3-3-input AND-OR gate and 2-2-input AND-OR gate | Unknown* | [ttl_74x58](spec/chips/ttl_74x58.md) |
| 74x59 | dual 3-2-input AND-OR-Invert gate | Unknown* | [ttl_74x59](spec/chips/ttl_74x59.md) |
| 74x60 | dual 4-input expander for 74x23, 74x50, 74x53, 74x55 | Unknown* | [ttl_74x60](spec/chips/ttl_74x60.md) |
| 74x61 | triple 3-input expander for 74x52 | Unknown* | [ttl_74x61](spec/chips/ttl_74x61.md) |
| 74x62 | 3-3-2-2-input AND-OR expander for 74x50, 74x53, 74x55 | Unknown* | [ttl_74x62](spec/chips/ttl_74x62.md) |
| 74x63 | hex current sensing interface gates | Unknown* | [ttl_74x63](spec/chips/ttl_74x63.md) |
| 74x64 | 4-3-2-2-input AND-OR-Invert gate | Unknown* | [ttl_74x64](spec/chips/ttl_74x64.md) |
| 74x65 | 4-3-2-2 input AND-OR-Invert gate | Unknown* | [ttl_74x65](spec/chips/ttl_74x65.md) |
| 74x67 | AND gated J-K master-slave flip-flop, asynchronous preset and clear (improved 74L72) | Unknown* | [ttl_74x67](spec/chips/ttl_74x67.md) |
| 74L68 | dual J-K flip-flop, asynchronous clear (improved 74L73) | Unknown* | [ttl_74l68](spec/chips/ttl_74l68.md) |
| 74LS68 | dual 4-bit decade counters | Unknown* | [ttl_74ls68](spec/chips/ttl_74ls68.md) |
| 74L69 | dual J-K flip-flop, asynchronous preset, shared clock and clear | Unknown* | [ttl_74l69](spec/chips/ttl_74l69.md) |
| 74LS69 | dual 4-bit binary counters | Unknown* | [ttl_74ls69](spec/chips/ttl_74ls69.md) |
| 74x70 | AND-gated positive-edge-triggered J-K flip-flop, asynchronous preset and clear | Unknown* | [ttl_74x70](spec/chips/ttl_74x70.md) |
| 74H71 | AND-OR-gated J-K master-slave flip-flop, preset | Unknown* | [ttl_74h71](spec/chips/ttl_74h71.md) |
| 74L71 | AND-gated R-S master-slave flip-flop, preset and clear | Unknown* | [ttl_74l71](spec/chips/ttl_74l71.md) |
| 74x72 | AND gated J-K master-slave flip-flop, asynchronous preset and clear | Unknown* | [ttl_74x72](spec/chips/ttl_74x72.md) |
| 74x73 | dual J-K flip-flop, asynchronous clear | Unknown* | [ttl_74x73](spec/chips/ttl_74x73.md) |
| 74x74 | dual D positive-edge-triggered flip-flop, asynchronous clear & preset, Q & /Q outputs | Unknown* | [ttl_74x74](spec/chips/ttl_74x74.md) |
| 74x75 | 4-bit bistable latch, complementary outputs | Unknown* | [ttl_74x75](spec/chips/ttl_74x75.md) |
| 74x76 | dual J-K flip-flop, asynchronous preset and clear | Unknown* | [ttl_74x76](spec/chips/ttl_74x76.md) |
| 74x77 | 4-bit bistable latch | Unknown* | [ttl_74x77](spec/chips/ttl_74x77.md) |
| 74H78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | Unknown* | [ttl_74h78](spec/chips/ttl_74h78.md) |
| 74L78 | dual positive-pulse-triggered J-K flip-flop, preset, shared clock and clear | Unknown* | [ttl_74l78](spec/chips/ttl_74l78.md) |
| 74LS78 | dual negative-edge-triggered J-K flip-flop, preset, shared clock and clear | Unknown* | [ttl_74ls78](spec/chips/ttl_74ls78.md) |
| 74x79 | dual D positive-edge-triggered flip-flop, asynchronous preset and clear | Unknown* | [ttl_74x79](spec/chips/ttl_74x79.md) |
| 74x80 | gated full adder | Unknown* | [ttl_74x80](spec/chips/ttl_74x80.md) |
| 74x81 | 16-bit RAM | Unknown* | [ttl_74x81](spec/chips/ttl_74x81.md) |
| 74x82 | 2-bit binary full adder | Unknown* | [ttl_74x82](spec/chips/ttl_74x82.md) |
| 74x83 | 4-bit binary full adder | Unknown* | [ttl_74x83](spec/chips/ttl_74x83.md) |
| 74x84 | 16-bit RAM | Unknown* | [ttl_74x84](spec/chips/ttl_74x84.md) |
| 74x85 | 4-bit magnitude comparator | Unknown* | [ttl_74x85](spec/chips/ttl_74x85.md) |
| 74x86 | quad 2-input XOR gate | Unknown* | [ttl_74x86](spec/chips/ttl_74x86.md) |
| 74x87 | 4-bit true/complement/zero/one element | Unknown* | [ttl_74x87](spec/chips/ttl_74x87.md) |
| 74x88 | 256-bit ROM (32x8) | Unknown* | [ttl_74x88](spec/chips/ttl_74x88.md) |
| 74x89 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown* | [ttl_74x89](spec/chips/ttl_74x89.md) |
| 74x90 | decade counter (separate divide-by-2 and divide-by-5 sections) | Unknown* | [ttl_74x90](spec/chips/ttl_74x90.md) |
| 74x91 | 8-bit shift register, serial in, serial out, gated input | Unknown* | [ttl_74x91](spec/chips/ttl_74x91.md) |
| 74x92 | divide-by-12 counter (separate divide-by-2 and divide-by-6 sections) | Unknown* | [ttl_74x92](spec/chips/ttl_74x92.md) |
| 74x93 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections); different pinout for 74L93 | Unknown* | [ttl_74x93](spec/chips/ttl_74x93.md) |
| 74x94 | 4-bit shift register, dual asynchronous presets | Unknown* | [ttl_74x94](spec/chips/ttl_74x94.md) |
| 74x95 | 4-bit shift register, parallel in, parallel out, serial input; different pinout for 74L95 | Unknown* | [ttl_74x95](spec/chips/ttl_74x95.md) |
| 74x96 | 5-bit parallel-in/parallel-out shift register, asynchronous preset | Unknown* | [ttl_74x96](spec/chips/ttl_74x96.md) |
| 74x97 | synchronous 6-bit binary rate multiplier | Unknown* | [ttl_74x97](spec/chips/ttl_74x97.md) |
| 74x98 | 4-bit data selector/storage register | Unknown* | [ttl_74x98](spec/chips/ttl_74x98.md) |
| 74x99 | 4-bit bidirectional universal shift register | Unknown* | [ttl_74x99](spec/chips/ttl_74x99.md) |
| 74x100 | dual 4-bit bistable latch | Unknown* | [ttl_74x100](spec/chips/ttl_74x100.md) |
| 74x101 | AND-OR-gated J-K negative-edge-triggered flip-flop, preset | Unknown* | [ttl_74x101](spec/chips/ttl_74x101.md) |
| 74x102 | AND-gated J-K negative-edge-triggered flip-flop, preset and clear | Unknown* | [ttl_74x102](spec/chips/ttl_74x102.md) |
| 74x103 | dual J-K negative-edge-triggered flip-flop, clear | Unknown* | [ttl_74x103](spec/chips/ttl_74x103.md) |
| 74x104 | J-K master-slave flip-flop | Unknown* | [ttl_74x104](spec/chips/ttl_74x104.md) |
| 74x105 | J-K master-slave flip-flop, J2 and K2 inverted | Unknown* | [ttl_74x105](spec/chips/ttl_74x105.md) |
| 74x106 | dual J-K negative-edge-triggered flip-flop, preset and clear | Unknown* | [ttl_74x106](spec/chips/ttl_74x106.md) |
| 74x107 | dual J-K flip-flop, clear | Unknown* | [ttl_74x107](spec/chips/ttl_74x107.md) |
| 74x108 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | Unknown* | [ttl_74x108](spec/chips/ttl_74x108.md) |
| 74x109 | dual J-NotK positive-edge-triggered flip-flop, clear and preset | Unknown* | [ttl_74x109](spec/chips/ttl_74x109.md) |
| 74x110 | AND-gated J-K master-slave flip-flop, data lockout | Unknown* | [ttl_74x110](spec/chips/ttl_74x110.md) |
| 74x111 | dual J-K master-slave flip-flop, data lockout, reset, set | Unknown* | [ttl_74x111](spec/chips/ttl_74x111.md) |
| 74x112 | dual J-K negative-edge-triggered flip-flop, clear & preset, Q & /Q outputs | Unknown* | [ttl_74x112](spec/chips/ttl_74x112.md) |
| 74x113 | dual J-K negative-edge-triggered flip-flop, preset | Unknown* | [ttl_74x113](spec/chips/ttl_74x113.md) |
| 74x114 | dual J-K negative-edge-triggered flip-flop, preset, shared clock and clear | Unknown* | [ttl_74x114](spec/chips/ttl_74x114.md) |
| 74x115 | dual J-K master-slave flip-flop, data lockout, reset | Unknown* | [ttl_74x115](spec/chips/ttl_74x115.md) |
| 74116 | dual 4-bit latch, clear | Unknown* | [ttl_74116](spec/chips/ttl_74116.md) |
| 74H116 | AND-gated J-K flip flop | Unknown* | [ttl_74h116](spec/chips/ttl_74h116.md) |
| 74x117 | AND-gated J-K flip flop, one J and K input inverted | Unknown* | [ttl_74x117](spec/chips/ttl_74x117.md) |
| 74x118 | hex set/reset latch, shared reset | Unknown* | [ttl_74x118](spec/chips/ttl_74x118.md) |
| 74119 | hex set/reset latch | Unknown* | [ttl_74119](spec/chips/ttl_74119.md) |
| 74H119 | dual J-K flip-flop, shared clock and clear | Unknown* | [ttl_74h119](spec/chips/ttl_74h119.md) |
| 74120 | dual pulse synchronizer/drivers | Unknown* | [ttl_74120](spec/chips/ttl_74120.md) |
| 74H120 | dual J-K flip-flop, separate clock inputs | Unknown* | [ttl_74h120](spec/chips/ttl_74h120.md) |
| 74x125 | quad bus buffer, negative enable | Unknown* | [ttl_74x125](spec/chips/ttl_74x125.md) |
| 74x126 | quad bus buffer, positive enable | Unknown* | [ttl_74x126](spec/chips/ttl_74x126.md) |
| 74x128 | quad 2-input NOR gate | Unknown* | [ttl_74x128](spec/chips/ttl_74x128.md) |
| 74131 | quad 2-input AND gate | Unknown* | [ttl_74131](spec/chips/ttl_74131.md) |
| 74x132 | quad 2-input NAND gate | Unknown* | [ttl_74x132](spec/chips/ttl_74x132.md) |
| 74x133 | single 13-input NAND gate | Unknown* | [ttl_74x133](spec/chips/ttl_74x133.md) |
| 74x134 | single 12-input NAND gate | Unknown* | [ttl_74x134](spec/chips/ttl_74x134.md) |
| 74x135 | quad XOR/XNOR gate, two inputs to select logic type | Unknown* | [ttl_74x135](spec/chips/ttl_74x135.md) |
| 74x136 | quad 2-input XOR gate | Unknown* | [ttl_74x136](spec/chips/ttl_74x136.md) |
| 74x137 | 3-to-8 line decoder/demultiplexer, address latch, inverting outputs | Unknown* | [ttl_74x137](spec/chips/ttl_74x137.md) |
| 74x138 | 3-to-8 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x138](spec/chips/ttl_74x138.md) |
| 74x139 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x139](spec/chips/ttl_74x139.md) |
| 74x140 | dual 4-input NAND gate | Unknown* | [ttl_74x140](spec/chips/ttl_74x140.md) |
| 74x141 | BCD to decimal decoder/driver for cold-cathode indicator / Nixie tube | Unknown* | [ttl_74x141](spec/chips/ttl_74x141.md) |
| 74x142 | decade counter/latch/decoder/driver for Nixie tubes | Unknown* | [ttl_74x142](spec/chips/ttl_74x142.md) |
| 74x143 | decade counter/latch/decoder/7-segment driver | Unknown* | [ttl_74x143](spec/chips/ttl_74x143.md) |
| 74x144 | decade counter/latch/decoder/7-segment driver | Unknown* | [ttl_74x144](spec/chips/ttl_74x144.md) |
| 74x145 | BCD to decimal decoder/driver | Unknown* | [ttl_74x145](spec/chips/ttl_74x145.md) |
| 74x146 | 3-to-8 line decoder | Unknown* | [ttl_74x146](spec/chips/ttl_74x146.md) |
| 74x147 | 10-line to 4-line priority encoder | Unknown* | [ttl_74x147](spec/chips/ttl_74x147.md) |
| 74x148 | 8-line to 3-line priority encoder | Unknown* | [ttl_74x148](spec/chips/ttl_74x148.md) |
| 74x149 | 8-line to 8-line priority encoder | Unknown* | [ttl_74x149](spec/chips/ttl_74x149.md) |
| 74x150 | 16-line to 1-line data selector/multiplexer | Unknown* | [ttl_74x150](spec/chips/ttl_74x150.md) |
| 74x151 | 8-line to 1-line data selector/multiplexer | Unknown* | [ttl_74x151](spec/chips/ttl_74x151.md) |
| 74x152 | 8-line to 1-line data selector/multiplexer, inverting output | Unknown* | [ttl_74x152](spec/chips/ttl_74x152.md) |
| 74x153 | dual 4-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown* | [ttl_74x153](spec/chips/ttl_74x153.md) |
| 74x154 | 4-to-16 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x154](spec/chips/ttl_74x154.md) |
| 74x155 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x155](spec/chips/ttl_74x155.md) |
| 74x156 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x156](spec/chips/ttl_74x156.md) |
| 74x157 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown* | [ttl_74x157](spec/chips/ttl_74x157.md) |
| 74x158 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | Unknown* | [ttl_74x158](spec/chips/ttl_74x158.md) |
| 74x159 | 4-to-16 line decoder/demultiplexer | Unknown* | [ttl_74x159](spec/chips/ttl_74x159.md) |
| 74x160 | synchronous presettable 4-bit decade counter, asynchronous clear | Unknown* | [ttl_74x160](spec/chips/ttl_74x160.md) |
| 74x161 | synchronous presettable 4-bit binary counter, asynchronous clear | Unknown* | [ttl_74x161](spec/chips/ttl_74x161.md) |
| 74x162 | synchronous presettable 4-bit decade counter, synchronous clear | Unknown* | [ttl_74x162](spec/chips/ttl_74x162.md) |
| 74x163 | synchronous presettable 4-bit binary counter, synchronous clear | Unknown* | [ttl_74x163](spec/chips/ttl_74x163.md) |
| 74x164 | 8-bit serial-in parallel-out (SIPO) shift register, asynchronous clear, not output latch | Unknown* | [ttl_74x164](spec/chips/ttl_74x164.md) |
| 74x165 | 8-bit parallel-in serial-out (PISO) shift register, parallel load, complementary outputs | Unknown* | [ttl_74x165](spec/chips/ttl_74x165.md) |
| 74x166 | parallel-load 8-bit shift register | Unknown* | [ttl_74x166](spec/chips/ttl_74x166.md) |
| 74x167 | synchronous decade rate multiplier | Unknown* | [ttl_74x167](spec/chips/ttl_74x167.md) |
| 74x168 | synchronous presettable 4-bit up/down decade counter | Unknown* | [ttl_74x168](spec/chips/ttl_74x168.md) |
| 74x169 | synchronous presettable 4-bit up/down binary counter | Unknown* | [ttl_74x169](spec/chips/ttl_74x169.md) |
| 74x170 | 16-bit register file (4x4) | Unknown* | [ttl_74x170](spec/chips/ttl_74x170.md) |
| 74x171 | quad D flip-flops, shared clock and clear | Unknown* | [ttl_74x171](spec/chips/ttl_74x171.md) |
| 74x172 | 16-bit multiple port register file (8x2) | Unknown* | [ttl_74x172](spec/chips/ttl_74x172.md) |
| 74x173 | quad D flip-flop, shared clock and asynchronous clear and enable, Q & /Q outputs | Unknown* | [ttl_74x173](spec/chips/ttl_74x173.md) |
| 74x174 | hex D flip-flop, shared clock and asynchronous clear, Q outputs | Unknown* | [ttl_74x174](spec/chips/ttl_74x174.md) |
| 74x175 | quad D edge-triggered flip-flop, shared clock and asynchronous clear, Q & /Q outputs | Unknown* | [ttl_74x175](spec/chips/ttl_74x175.md) |
| 74x176 | presettable decade (bi-quinary) counter/latch | Unknown* | [ttl_74x176](spec/chips/ttl_74x176.md) |
| 74x177 | presettable binary counter/latch | Unknown* | [ttl_74x177](spec/chips/ttl_74x177.md) |
| 74x178 | 4-bit parallel-access shift register | Unknown* | [ttl_74x178](spec/chips/ttl_74x178.md) |
| 74x179 | 4-bit parallel-access shift register, asynchronous clear input, complementary Q output | Unknown* | [ttl_74x179](spec/chips/ttl_74x179.md) |
| 74x180 | 9-bit odd/even parity bit generator and checker | Unknown* | [ttl_74x180](spec/chips/ttl_74x180.md) |
| 74x181 | 4-bit arithmetic logic unit and function generator | 1970 | [ttl_74x181](spec/chips/ttl_74x181.md) |
| 74x182 | lookahead carry generator | Unknown* | [ttl_74x182](spec/chips/ttl_74x182.md) |
| 74x183 | dual carry-save full adder | Unknown* | [ttl_74x183](spec/chips/ttl_74x183.md) |
| 74x184 | BCD to binary converter | Unknown* | [ttl_74x184](spec/chips/ttl_74x184.md) |
| 74x185 | 6-bit binary to BCD converter | Unknown* | [ttl_74x185](spec/chips/ttl_74x185.md) |
| 74x186 | 512-bit ROM (64x8) | Unknown* | [ttl_74x186](spec/chips/ttl_74x186.md) |
| 74x187 | 1024-bit ROM (256x4) | Unknown* | [ttl_74x187](spec/chips/ttl_74x187.md) |
| 74x188 | 256-bit PROM (32x8) | Unknown* | [ttl_74x188](spec/chips/ttl_74x188.md) |
| 74x189 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown* | [ttl_74x189](spec/chips/ttl_74x189.md) |
| 74x190 | synchronous presettable up/down 4-bit decade counter | Unknown* | [ttl_74x190](spec/chips/ttl_74x190.md) |
| 74x191 | synchronous presettable up/down 4-bit binary counter | Unknown* | [ttl_74x191](spec/chips/ttl_74x191.md) |
| 74x192 | synchronous presettable up/down 4-bit decade counter, clear | Unknown* | [ttl_74x192](spec/chips/ttl_74x192.md) |
| 74x193 | synchronous presettable up/down 4-bit binary counter, clear | Unknown* | [ttl_74x193](spec/chips/ttl_74x193.md) |
| 74x194 | 4-bit bidirectional universal shift register | Unknown* | [ttl_74x194](spec/chips/ttl_74x194.md) |
| 74x195 | 4-bit parallel-access shift register | Unknown* | [ttl_74x195](spec/chips/ttl_74x195.md) |
| 74x196 | presettable 4-bit decade counter/latch | Unknown* | [ttl_74x196](spec/chips/ttl_74x196.md) |
| 74x197 | presettable 4-bit binary counter/latch | Unknown* | [ttl_74x197](spec/chips/ttl_74x197.md) |
| 74x198 | 8-bit bidirectional universal shift register | Unknown* | [ttl_74x198](spec/chips/ttl_74x198.md) |
| 74x199 | 8-bit universal shift register, J-NotK serial inputs | Unknown* | [ttl_74x199](spec/chips/ttl_74x199.md) |
| 74x200 | 256-bit RAM (256x1) | Unknown* | [ttl_74x200](spec/chips/ttl_74x200.md) |
| 74x201 | 256-bit RAM (256x1) | Unknown* | [ttl_74x201](spec/chips/ttl_74x201.md) |
| 74x202 | 256-bit RAM (256x1) with power down | Unknown* | [ttl_74x202](spec/chips/ttl_74x202.md) |
| 74x206 | 256-bit RAM (256x1) | Unknown* | [ttl_74x206](spec/chips/ttl_74x206.md) |
| 74x207 | 1024-bit RAM (256x4) | Unknown* | [ttl_74x207](spec/chips/ttl_74x207.md) |
| 74x208 | 1024-bit RAM (256x4), separate data in- and outputs | Unknown* | [ttl_74x208](spec/chips/ttl_74x208.md) |
| 74x209 | 1024-bit RAM (1024x1) | Unknown* | [ttl_74x209](spec/chips/ttl_74x209.md) |
| 74x210 | octal buffer, inverting | Unknown* | [ttl_74x210](spec/chips/ttl_74x210.md) |
| 74x211 | 144-bit RAM (16x9) with output latch | Unknown* | [ttl_74x211](spec/chips/ttl_74x211.md) |
| 74x212 | 144-bit RAM (16x9) | Unknown* | [ttl_74x212](spec/chips/ttl_74x212.md) |
| 74x213 | 192-bit RAM (16x12) | Unknown* | [ttl_74x213](spec/chips/ttl_74x213.md) |
| 74x214 | 1024-bit RAM (1024x1) | Unknown* | [ttl_74x214](spec/chips/ttl_74x214.md) |
| 74x215 | 1024-bit RAM (1024x1) with power-down mode | Unknown* | [ttl_74x215](spec/chips/ttl_74x215.md) |
| 74x216 | 256-bit RAM (64x4), common I/O | Unknown* | [ttl_74x216](spec/chips/ttl_74x216.md) |
| 74x217 | 256-bit RAM (64x4) | Unknown* | [ttl_74x217](spec/chips/ttl_74x217.md) |
| 74x218 | 256-bit RAM (32x8) | Unknown* | [ttl_74x218](spec/chips/ttl_74x218.md) |
| 74x219 | 64-bit RAM (16x4), non-inverting outputs | Unknown* | [ttl_74x219](spec/chips/ttl_74x219.md) |
| 74x222 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | Unknown* | [ttl_74x222](spec/chips/ttl_74x222.md) |
| 74x224 | 64-bit FIFO memory (16x4), synchronous | Unknown* | [ttl_74x224](spec/chips/ttl_74x224.md) |
| 74x225 | 80-bit FIFO memory (16x5), asynchronous | Unknown* | [ttl_74x225](spec/chips/ttl_74x225.md) |
| 74x226 | 4-bit parallel latched bus transceiver | Unknown* | [ttl_74x226](spec/chips/ttl_74x226.md) |
| 74x227 | 64-bit FIFO memory (16x4), synchronous, input/output ready enable | Unknown* | [ttl_74x227](spec/chips/ttl_74x227.md) |
| 74x228 | 64-bit FIFO memory (16x4), synchronous | Unknown* | [ttl_74x228](spec/chips/ttl_74x228.md) |
| 74x229 | 80-bit FIFO memory (16x5), asynchronous | Unknown* | [ttl_74x229](spec/chips/ttl_74x229.md) |
| 74x230 | dual 4-bit buffer/driver, one inverted, one non-inverted; negative enable | Unknown* | [ttl_74x230](spec/chips/ttl_74x230.md) |
| 74x231 | dual 4-bit buffer/driver, both inverted; one positive and one negative enable | Unknown* | [ttl_74x231](spec/chips/ttl_74x231.md) |
| 74x232 | 64-bit FIFO memory (16x4), asynchronous | Unknown* | [ttl_74x232](spec/chips/ttl_74x232.md) |
| 74x233 | 80-bit FIFO memory (16x5), asynchronous | Unknown* | [ttl_74x233](spec/chips/ttl_74x233.md) |
| 74x234 | 256-bit FIFO memory (64x4), asynchronous | Unknown* | [ttl_74x234](spec/chips/ttl_74x234.md) |
| 74x235 | 320-bit FIFO memory (64x5), asynchronous | Unknown* | [ttl_74x235](spec/chips/ttl_74x235.md) |
| 74x236 | 256-bit FIFO memory (64x4), asynchronous | Unknown* | [ttl_74x236](spec/chips/ttl_74x236.md) |
| 74x237 | 3-to-8 line decoder/demultiplexer, address latch, active high outputs | Unknown* | [ttl_74x237](spec/chips/ttl_74x237.md) |
| 74x238 | 3-to-8 line decoder/demultiplexer, active high outputs | Unknown* | [ttl_74x238](spec/chips/ttl_74x238.md) |
| 74x239 | dual 2-to-4 line decoder/demultiplexer, active high outputs | Unknown* | [ttl_74x239](spec/chips/ttl_74x239.md) |
| 74x240 | octal buffer, inverting outputs | Unknown* | [ttl_74x240](spec/chips/ttl_74x240.md) |
| 74x241 | octal buffer, non-inverting outputs | Unknown* | [ttl_74x241](spec/chips/ttl_74x241.md) |
| 74x242 | quad bus transceiver, inverting outputs | Unknown* | [ttl_74x242](spec/chips/ttl_74x242.md) |
| 74x243 | quad bus transceiver, non-inverting outputs | Unknown* | [ttl_74x243](spec/chips/ttl_74x243.md) |
| 74x244 | octal buffer, non-inverting outputs | Unknown* | [ttl_74x244](spec/chips/ttl_74x244.md) |
| 74x245 | octal bus transceiver, non-inverting outputs | Unknown* | [ttl_74x245](spec/chips/ttl_74x245.md) |
| 74x246 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x246](spec/chips/ttl_74x246.md) |
| 74x247 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x247](spec/chips/ttl_74x247.md) |
| 74x248 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x248](spec/chips/ttl_74x248.md) |
| 74x249 | BCD to 7-segment decoder/driver | Unknown* | [ttl_74x249](spec/chips/ttl_74x249.md) |
| 74x250 | 1 of 16 data selector/multiplexer | Unknown* | [ttl_74x250](spec/chips/ttl_74x250.md) |
| 74x251 | 8-line to 1-line data selector/multiplexer, complementary outputs | Unknown* | [ttl_74x251](spec/chips/ttl_74x251.md) |
| 74x253 | dual 4-line to 1-line data selector/multiplexer | Unknown* | [ttl_74x253](spec/chips/ttl_74x253.md) |
| 74x255 | dual 2-to-4 line decoder/demultiplexer, inverting outputs | Unknown* | [ttl_74x255](spec/chips/ttl_74x255.md) |
| 74x256 | dual 4-bit addressable latch | Unknown* | [ttl_74x256](spec/chips/ttl_74x256.md) |
| 74x257 | quad 2-line to 1-line data selector/multiplexer, non-inverting outputs | Unknown* | [ttl_74x257](spec/chips/ttl_74x257.md) |
| 74x258 | quad 2-line to 1-line data selector/multiplexer, inverting outputs | Unknown* | [ttl_74x258](spec/chips/ttl_74x258.md) |
| 74x259 | 8-bit bit addressable input latch with clr | Unknown* | [ttl_74x259](spec/chips/ttl_74x259.md) |
| 74x260 | dual 5-input NOR gate | Unknown* | [ttl_74x260](spec/chips/ttl_74x260.md) |
| 74x261 | 2-bit by 4-bit parallel binary multiplier | Unknown* | [ttl_74x261](spec/chips/ttl_74x261.md) |
| 74x262 | 5760-bit read-only character memory (128 by 45-bit bitmaps) | Unknown* | [ttl_74x262](spec/chips/ttl_74x262.md) |
| 74x264 | look ahead carry generator | Unknown* | [ttl_74x264](spec/chips/ttl_74x264.md) |
| 74x265 | quad complementary output elements | Unknown* | [ttl_74x265](spec/chips/ttl_74x265.md) |
| 74x266 | quad 2-input XNOR gate | Unknown* | [ttl_74x266](spec/chips/ttl_74x266.md) |
| 74x268 | hex D-type latches, shared enable and output control | Unknown* | [ttl_74x268](spec/chips/ttl_74x268.md) |
| 74x269 | 8-bit bidirectional binary counter | Unknown* | [ttl_74x269](spec/chips/ttl_74x269.md) |
| 74x270 | 2048-bit ROM (512x4) | Unknown* | [ttl_74x270](spec/chips/ttl_74x270.md) |
| 74x271 | 2048-bit ROM (256x8) | Unknown* | [ttl_74x271](spec/chips/ttl_74x271.md) |
| 74x273 | 8-bit register, asynchronous clear | Unknown* | [ttl_74x273](spec/chips/ttl_74x273.md) |
| 74x274 | 4-bit by 4-bit binary multiplier | Unknown* | [ttl_74x274](spec/chips/ttl_74x274.md) |
| 74x275 | 7-bit slice Wallace tree | Unknown* | [ttl_74x275](spec/chips/ttl_74x275.md) |
| 74x276 | quad J-NotK edge-triggered flip-flops, separate clocks, shared preset and clear | Unknown* | [ttl_74x276](spec/chips/ttl_74x276.md) |
| 74x278 | 4-bit cascadeable priority registers, latched data inputs | Unknown* | [ttl_74x278](spec/chips/ttl_74x278.md) |
| 74x279 | quad set-reset latch | Unknown* | [ttl_74x279](spec/chips/ttl_74x279.md) |
| 74x280 | 9-bit odd/even parity bit generator/checker | Unknown* | [ttl_74x280](spec/chips/ttl_74x280.md) |
| 74x281 | 4-bit parallel binary accumulator | Unknown* | [ttl_74x281](spec/chips/ttl_74x281.md) |
| 74x282 | look-ahead carry generator, selectable carry inputs | Unknown* | [ttl_74x282](spec/chips/ttl_74x282.md) |
| 74x283 | 4-bit binary full adder (has carry in function) | Unknown* | [ttl_74x283](spec/chips/ttl_74x283.md) |
| 74x284 | 4-bit by 4-bit parallel binary multiplier (high order 4 bits of product) | Unknown* | [ttl_74x284](spec/chips/ttl_74x284.md) |
| 74x285 | 4-bit by 4-bit parallel binary multiplier (low order 4 bits of product) | Unknown* | [ttl_74x285](spec/chips/ttl_74x285.md) |
| 74x286 | 9-bit parity generator/checker, bus driver parity I/O port | Unknown* | [ttl_74x286](spec/chips/ttl_74x286.md) |
| 74x287 | 1024-bit PROM (256x4) | Unknown* | [ttl_74x287](spec/chips/ttl_74x287.md) |
| 74x288 | 256-bit PROM (32x8) | Unknown* | [ttl_74x288](spec/chips/ttl_74x288.md) |
| 74x289 | 64-bit RAM (16x4), 4 data inputs, 4 inverted data outputs | Unknown* | [ttl_74x289](spec/chips/ttl_74x289.md) |
| 74x290 | decade counter (separate divide-by-2 and divide-by-5 sections) | Unknown* | [ttl_74x290](spec/chips/ttl_74x290.md) |
| 74x292 | programmable frequency divider/digital timer | Unknown* | [ttl_74x292](spec/chips/ttl_74x292.md) |
| 74x293 | 4-bit binary counter (separate divide-by-2 and divide-by-8 sections) | Unknown* | [ttl_74x293](spec/chips/ttl_74x293.md) |
| 74x294 | programmable frequency divider/digital timer | Unknown* | [ttl_74x294](spec/chips/ttl_74x294.md) |
| 74x295 | 4-bit bidirectional shift register | Unknown* | [ttl_74x295](spec/chips/ttl_74x295.md) |
| 74x297 | digital phase-locked loop filter | Unknown* | [ttl_74x297](spec/chips/ttl_74x297.md) |
| 74x298 | quad 2-input multiplexer, storage | Unknown* | [ttl_74x298](spec/chips/ttl_74x298.md) |
| 74x299 | 8-bit bidirectional universal shift/storage register | Unknown* | [ttl_74x299](spec/chips/ttl_74x299.md) |

## Excluded analog/timing devices

- 74x31: hex delay elements (two 6ns, two 23-32ns, two 45-48ns).
- 74x121: monostable multivibrator.
- 74x122: retriggerable monostable multivibrator, clear.
- 74x123: dual retriggerable monostable multivibrator, clear.
- 74x124: dual voltage-controlled oscillator.
- 74x130: retriggerable monostable multivibrator.
- 74x221: dual monostable multivibrator.
