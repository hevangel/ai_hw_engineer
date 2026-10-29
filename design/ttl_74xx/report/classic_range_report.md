# Classic 7400–74299 library verification report

Verified: 2026-10-21 03:26 UTC

## Result

**289 digital function models; 867/867 current-source per-part checks passed.**
Each part passed strict RTL lint, self-checking simulation and generic synthesis
including structural assertions. Seven user-excluded analog/timing devices are
explicitly listed in the manifest. No modules are created for unassigned numbers.

All ten independent family formal check/cover tasks passed. The original 74181
also passed strict Verilator/Verible lint, 16,384 exhaustive binary input vectors
(81,920 output-field comparisons), its 64-transaction UVM test, BMC, unbounded
proof, cover and generic synthesis. `ttl_74x181` wraps that unchanged RTL.

## Tools

- Verilator 5.052 2026-09-05 rev v5.052
- Yosys 0.69 (git sha1 9f75ca1f9, Release, GNU /usr/bin/g++ 15.2.0)
- xezim (bundled image; version flag unavailable)

The repository's `ai-hw-engineer:latest` Docker image supplies the tools and UVM.
Builds use only local library sources, tests and test images; upstream code is
pinned by revision and its MIT license is retained.

## Formal evidence and limits

| Family | Check | Non-vacuity |
|---|---|---|
| 46 gate/strobe modules | Unbounded independent truth-table proofs | All covers PASS |
| 74160/161/162/163 | Unbounded transition/carry contracts | Reset/load/hold/terminal count covers PASS |
| 74164 | Unbounded bit-history contract | Nonzero serial sequence cover PASS |
| 74189 | Unbounded symbolic-address read/write/drive invariant (ABC PDR) | Written-address readback cover PASS |
| 74222 | Bounded ordering/flag contract, 8 steps | Full and mixed-operation covers, depth 20, PASS |
| Original 74181 | BMC and unbounded proof | Cover PASS |

The FIFO bounded result is not an unbounded ordering proof. All FIFO models also
run full/empty, overflow/underflow prevention, pointer wraparound and 2,000 mixed
transactions against independent queues in simulation. Targeted formal coverage
does not certify every part's complete native datasheet behavior.

## Corrections and test depth

The initial imported functional baseline was not accepted on its prior pass claims.
Local tool and source review corrected strobe polarity, expander support, complete
7485 cascade semantics, independent clock storage, forced 7474 output state,
falling-edge ripple counters and 7492 state order, asynchronous 74165 loading,
serial bit ordering, 74279 set controls, storage synthesis feedback, drive enables,
74299 serial endpoints, ROM-versus-RAM distinctions, 74289 inversion, converter
truncation and divider ratios. The generic substitute 74297 filter was replaced
by a documented digital K-counter/I-D/phase-detector model.

RAM tests exercise every address with three data patterns and check inactive
write/chip-select protection. ROM tests load nontrivial image fixtures and read
every address. Shift-register tests cover all 256 byte loads and complete serial
chains. Expander tests cover both input states. Tests flush unreset storage before
requiring known contents; power-up zeros are not assumed.

## Functional-interface boundaries

These are the documented **normalized digital function models**. They are not all
native package-pin-compatible replicas. Some RAM, FIFO, rate multiplier and
multi-clock devices use explicit clock/transaction adapters. Native asynchronous
handshake timing, exact rate-multiplier pulse distribution and the 74297 internal
pipeline placement are not certified. See each part's specification before board
integration. Three-state buses use drive enables/split I/O, and open-collector
levels require board-level wired-AND resolution. ROM masks, including the 74262
teletext character image, must be supplied; synthetic test fixtures are not
historical contents. Exact launch years outside the sourced 1970 74181 date
remain explicitly unknown.

## Reproduction

```sh
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  ai-hw-engineer:latest sh design/ttl_74xx/scripts/run_all.sh
```

Per-part phase logs and source fingerprints are under `work/library/<module>/`.
Proof logs/traces are under `work/formal/`. Build artifacts are git-ignored.
The aggregate command fails on tool errors, missing PASS markers, missing parts,
unexpected exclusions, failed covers or stale successful per-part results.

## Per-part checks

| Module | Strict lint | Simulation | Generic synthesis | Contract |
|---|---|---|---|---|
| ttl_74x00 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x00.md) |
| ttl_74x01 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x01.md) |
| ttl_74x02 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x02.md) |
| ttl_74x03 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x03.md) |
| ttl_74x04 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x04.md) |
| ttl_74x05 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x05.md) |
| ttl_74x06 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x06.md) |
| ttl_74x07 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x07.md) |
| ttl_74x08 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x08.md) |
| ttl_74x09 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x09.md) |
| ttl_74x10 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x10.md) |
| ttl_74x11 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x11.md) |
| ttl_74x12 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x12.md) |
| ttl_74x13 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x13.md) |
| ttl_74x14 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x14.md) |
| ttl_74x15 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x15.md) |
| ttl_74x16 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x16.md) |
| ttl_74x17 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x17.md) |
| ttl_74x18 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x18.md) |
| ttl_74x19 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x19.md) |
| ttl_74x20 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x20.md) |
| ttl_74x21 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x21.md) |
| ttl_74x22 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x22.md) |
| ttl_74x23 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x23.md) |
| ttl_74x24 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x24.md) |
| ttl_74x25 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x25.md) |
| ttl_74x26 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x26.md) |
| ttl_74x27 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x27.md) |
| ttl_74x28 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x28.md) |
| ttl_74x29 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x29.md) |
| ttl_74x30 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x30.md) |
| ttl_74x32 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x32.md) |
| ttl_74x33 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x33.md) |
| ttl_74x34 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x34.md) |
| ttl_74x35 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x35.md) |
| ttl_74x36 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x36.md) |
| ttl_74x37 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x37.md) |
| ttl_74x38 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x38.md) |
| ttl_74x39 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x39.md) |
| ttl_74x40 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x40.md) |
| ttl_74x41 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x41.md) |
| ttl_74x42 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x42.md) |
| ttl_74x43 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x43.md) |
| ttl_74x44 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x44.md) |
| ttl_74x45 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x45.md) |
| ttl_74x46 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x46.md) |
| ttl_74x47 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x47.md) |
| ttl_74x48 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x48.md) |
| ttl_74x49 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x49.md) |
| ttl_74x50 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x50.md) |
| ttl_7451 | PASS | PASS | PASS | [specification](../spec/chips/ttl_7451.md) |
| ttl_74l51 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l51.md) |
| ttl_74x52 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x52.md) |
| ttl_7453 | PASS | PASS | PASS | [specification](../spec/chips/ttl_7453.md) |
| ttl_74h53 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h53.md) |
| ttl_7454 | PASS | PASS | PASS | [specification](../spec/chips/ttl_7454.md) |
| ttl_74h54 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h54.md) |
| ttl_74l54 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l54.md) |
| ttl_74x55 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x55.md) |
| ttl_74x56 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x56.md) |
| ttl_74x57 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x57.md) |
| ttl_74x58 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x58.md) |
| ttl_74x59 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x59.md) |
| ttl_74x60 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x60.md) |
| ttl_74x61 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x61.md) |
| ttl_74x62 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x62.md) |
| ttl_74x63 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x63.md) |
| ttl_74x64 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x64.md) |
| ttl_74x65 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x65.md) |
| ttl_74x67 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x67.md) |
| ttl_74l68 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l68.md) |
| ttl_74ls68 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74ls68.md) |
| ttl_74l69 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l69.md) |
| ttl_74ls69 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74ls69.md) |
| ttl_74x70 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x70.md) |
| ttl_74h71 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h71.md) |
| ttl_74l71 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l71.md) |
| ttl_74x72 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x72.md) |
| ttl_74x73 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x73.md) |
| ttl_74x74 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x74.md) |
| ttl_74x75 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x75.md) |
| ttl_74x76 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x76.md) |
| ttl_74x77 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x77.md) |
| ttl_74h78 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h78.md) |
| ttl_74l78 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74l78.md) |
| ttl_74ls78 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74ls78.md) |
| ttl_74x79 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x79.md) |
| ttl_74x80 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x80.md) |
| ttl_74x81 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x81.md) |
| ttl_74x82 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x82.md) |
| ttl_74x83 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x83.md) |
| ttl_74x84 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x84.md) |
| ttl_74x85 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x85.md) |
| ttl_74x86 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x86.md) |
| ttl_74x87 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x87.md) |
| ttl_74x88 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x88.md) |
| ttl_74x89 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x89.md) |
| ttl_74x90 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x90.md) |
| ttl_74x91 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x91.md) |
| ttl_74x92 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x92.md) |
| ttl_74x93 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x93.md) |
| ttl_74x94 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x94.md) |
| ttl_74x95 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x95.md) |
| ttl_74x96 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x96.md) |
| ttl_74x97 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x97.md) |
| ttl_74x98 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x98.md) |
| ttl_74x99 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x99.md) |
| ttl_74x100 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x100.md) |
| ttl_74x101 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x101.md) |
| ttl_74x102 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x102.md) |
| ttl_74x103 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x103.md) |
| ttl_74x104 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x104.md) |
| ttl_74x105 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x105.md) |
| ttl_74x106 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x106.md) |
| ttl_74x107 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x107.md) |
| ttl_74x108 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x108.md) |
| ttl_74x109 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x109.md) |
| ttl_74x110 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x110.md) |
| ttl_74x111 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x111.md) |
| ttl_74x112 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x112.md) |
| ttl_74x113 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x113.md) |
| ttl_74x114 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x114.md) |
| ttl_74x115 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x115.md) |
| ttl_74116 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74116.md) |
| ttl_74h116 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h116.md) |
| ttl_74x117 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x117.md) |
| ttl_74x118 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x118.md) |
| ttl_74119 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74119.md) |
| ttl_74h119 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h119.md) |
| ttl_74120 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74120.md) |
| ttl_74h120 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74h120.md) |
| ttl_74x125 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x125.md) |
| ttl_74x126 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x126.md) |
| ttl_74x128 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x128.md) |
| ttl_74131 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74131.md) |
| ttl_74x132 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x132.md) |
| ttl_74x133 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x133.md) |
| ttl_74x134 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x134.md) |
| ttl_74x135 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x135.md) |
| ttl_74x136 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x136.md) |
| ttl_74x137 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x137.md) |
| ttl_74x138 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x138.md) |
| ttl_74x139 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x139.md) |
| ttl_74x140 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x140.md) |
| ttl_74x141 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x141.md) |
| ttl_74x142 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x142.md) |
| ttl_74x143 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x143.md) |
| ttl_74x144 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x144.md) |
| ttl_74x145 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x145.md) |
| ttl_74x146 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x146.md) |
| ttl_74x147 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x147.md) |
| ttl_74x148 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x148.md) |
| ttl_74x149 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x149.md) |
| ttl_74x150 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x150.md) |
| ttl_74x151 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x151.md) |
| ttl_74x152 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x152.md) |
| ttl_74x153 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x153.md) |
| ttl_74x154 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x154.md) |
| ttl_74x155 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x155.md) |
| ttl_74x156 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x156.md) |
| ttl_74x157 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x157.md) |
| ttl_74x158 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x158.md) |
| ttl_74x159 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x159.md) |
| ttl_74x160 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x160.md) |
| ttl_74x161 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x161.md) |
| ttl_74x162 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x162.md) |
| ttl_74x163 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x163.md) |
| ttl_74x164 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x164.md) |
| ttl_74x165 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x165.md) |
| ttl_74x166 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x166.md) |
| ttl_74x167 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x167.md) |
| ttl_74x168 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x168.md) |
| ttl_74x169 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x169.md) |
| ttl_74x170 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x170.md) |
| ttl_74x171 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x171.md) |
| ttl_74x172 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x172.md) |
| ttl_74x173 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x173.md) |
| ttl_74x174 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x174.md) |
| ttl_74x175 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x175.md) |
| ttl_74x176 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x176.md) |
| ttl_74x177 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x177.md) |
| ttl_74x178 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x178.md) |
| ttl_74x179 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x179.md) |
| ttl_74x180 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x180.md) |
| ttl_74x181 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x181.md) |
| ttl_74x182 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x182.md) |
| ttl_74x183 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x183.md) |
| ttl_74x184 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x184.md) |
| ttl_74x185 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x185.md) |
| ttl_74x186 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x186.md) |
| ttl_74x187 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x187.md) |
| ttl_74x188 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x188.md) |
| ttl_74x189 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x189.md) |
| ttl_74x190 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x190.md) |
| ttl_74x191 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x191.md) |
| ttl_74x192 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x192.md) |
| ttl_74x193 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x193.md) |
| ttl_74x194 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x194.md) |
| ttl_74x195 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x195.md) |
| ttl_74x196 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x196.md) |
| ttl_74x197 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x197.md) |
| ttl_74x198 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x198.md) |
| ttl_74x199 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x199.md) |
| ttl_74x200 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x200.md) |
| ttl_74x201 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x201.md) |
| ttl_74x202 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x202.md) |
| ttl_74x206 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x206.md) |
| ttl_74x207 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x207.md) |
| ttl_74x208 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x208.md) |
| ttl_74x209 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x209.md) |
| ttl_74x210 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x210.md) |
| ttl_74x211 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x211.md) |
| ttl_74x212 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x212.md) |
| ttl_74x213 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x213.md) |
| ttl_74x214 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x214.md) |
| ttl_74x215 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x215.md) |
| ttl_74x216 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x216.md) |
| ttl_74x217 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x217.md) |
| ttl_74x218 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x218.md) |
| ttl_74x219 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x219.md) |
| ttl_74x222 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x222.md) |
| ttl_74x224 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x224.md) |
| ttl_74x225 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x225.md) |
| ttl_74x226 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x226.md) |
| ttl_74x227 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x227.md) |
| ttl_74x228 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x228.md) |
| ttl_74x229 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x229.md) |
| ttl_74x230 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x230.md) |
| ttl_74x231 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x231.md) |
| ttl_74x232 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x232.md) |
| ttl_74x233 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x233.md) |
| ttl_74x234 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x234.md) |
| ttl_74x235 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x235.md) |
| ttl_74x236 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x236.md) |
| ttl_74x237 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x237.md) |
| ttl_74x238 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x238.md) |
| ttl_74x239 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x239.md) |
| ttl_74x240 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x240.md) |
| ttl_74x241 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x241.md) |
| ttl_74x242 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x242.md) |
| ttl_74x243 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x243.md) |
| ttl_74x244 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x244.md) |
| ttl_74x245 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x245.md) |
| ttl_74x246 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x246.md) |
| ttl_74x247 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x247.md) |
| ttl_74x248 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x248.md) |
| ttl_74x249 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x249.md) |
| ttl_74x250 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x250.md) |
| ttl_74x251 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x251.md) |
| ttl_74x253 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x253.md) |
| ttl_74x255 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x255.md) |
| ttl_74x256 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x256.md) |
| ttl_74x257 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x257.md) |
| ttl_74x258 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x258.md) |
| ttl_74x259 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x259.md) |
| ttl_74x260 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x260.md) |
| ttl_74x261 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x261.md) |
| ttl_74x262 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x262.md) |
| ttl_74x264 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x264.md) |
| ttl_74x265 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x265.md) |
| ttl_74x266 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x266.md) |
| ttl_74x268 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x268.md) |
| ttl_74x269 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x269.md) |
| ttl_74x270 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x270.md) |
| ttl_74x271 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x271.md) |
| ttl_74x273 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x273.md) |
| ttl_74x274 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x274.md) |
| ttl_74x275 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x275.md) |
| ttl_74x276 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x276.md) |
| ttl_74x278 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x278.md) |
| ttl_74x279 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x279.md) |
| ttl_74x280 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x280.md) |
| ttl_74x281 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x281.md) |
| ttl_74x282 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x282.md) |
| ttl_74x283 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x283.md) |
| ttl_74x284 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x284.md) |
| ttl_74x285 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x285.md) |
| ttl_74x286 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x286.md) |
| ttl_74x287 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x287.md) |
| ttl_74x288 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x288.md) |
| ttl_74x289 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x289.md) |
| ttl_74x290 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x290.md) |
| ttl_74x292 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x292.md) |
| ttl_74x293 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x293.md) |
| ttl_74x294 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x294.md) |
| ttl_74x295 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x295.md) |
| ttl_74x297 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x297.md) |
| ttl_74x298 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x298.md) |
| ttl_74x299 | PASS | PASS | PASS | [specification](../spec/chips/ttl_74x299.md) |
