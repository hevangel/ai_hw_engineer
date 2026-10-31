# VIC-II reconstruction report

Status: **dot-level digital chip implemented for 6569, 6567R8, 6567R56A,
8565 and 8562; original C64 software and physical validation open**.
Measured on 2026-10-23 in `ai-hw-engineer:latest` (Verilator 5.052,
xezim 0.11.0): `scripts/run_all.sh` exits 0 with every gate below passing
in one fresh run.

## Reference

The oracle is MAME's `mos6566.cpp`/`.h` at revision
`41a494b6ef80adc924ccb2bdba1ee69580276e0c`, compiled **unchanged**
(`scripts/fetch_vicii_reference.py` pins SHA-256
`5f09fcd058a07e53526cd8068e6a17778addd8b4bfbe4c45d528cc23da267a29` and
`eaf828e424dc714ad4366235844e6912526f743f33fceee48817e712da85c454`)
against project-authored framework stubs (`tb/mame_stubs/emu.h`): memory
reads go to harness arrays, the bitmap records each pixel, callbacks
record BA/AEC/IRQ, and scheduler/save/timer services are inert. Access
specifiers are widened by macro only for observation. One adapter call is
one `execute_run()` iteration. Disagreements with floooh/chips are in the
[source review](../../../plans/mos_vicii_source_review.md).

## Verification

- Strict Verilator `-Wall` lint passes for all five variants.
- `tb/vicii_test.cpp` compares, for every system clock, the phase-one and
  phase-two fetch addresses and their order, BA, AEC and IRQ after the
  cycle logic, every CPU register read, and the complete pixel stream
  (row, column, color) in drawing order. Stimulus: KERNAL-like screens with
  all eight sprites, all eight graphics modes with scroll/border settings,
  24 random register programs over both character-ROM windows, light-pen
  pulses, per-line register changes (forced bad lines, open borders,
  sprite expansion/multicolor/enable changes, collision reads), continuous
  sprite collisions with IRQ acknowledgement and collision-register reads
  at varied phases, and $D017 writes in cycles 14-16 (sprite crunching).

| Variant | Cycles | Pixels | Fetches (phase two) | Reads (collision) | Writes |
|---|---:|---:|---:|---:|---:|
| 6569 | 934,139 | 7,473,028 | 998,180 (64,041) | 37,749 (8,697) | 51,842 |
| 6567R8 | 842,956 | 6,743,575 | 906,255 (63,299) | 25,508 (6,828) | 33,173 |
| 6567R56A | 786,738 | 6,293,831 | 845,730 (58,992) | 25,303 (6,875) | 33,055 |
| 8565 | 934,139 | 7,473,020 | 998,180 (64,041) | 37,749 (8,697) | 51,842 |
| 8562 | 842,956 | 6,743,568 | 906,255 (63,299) | 25,508 (6,828) | 33,173 |

- **Sixteen seeded RTL defects** (output lag, bad-line scroll compare,
  sprite X expansion, collision hold, left border, sprite MCBASE end,
  ECM color, color-register visibility dot, AEC delay, refresh counter,
  light-pen offset, MYE crunch merge, character-ROM fetch glitch, MCM
  flop dot, sprite priority, NTSC X stall) are each detected. Two earlier
  survivors were resolved: the MYE `0x2a`->`0x2b` mutation is equivalent
  (bit 0 comes from the `0x15` term) and was replaced; the collision-hold
  mutation required the directed collision/IRQ test now in the suite.
- The first **40,000** oracle-checked dot records (6569) replay in **both
  Verilator and xezim**. xezim 0.11.0 returned `X` for function ports with
  non-zero-based ranges in this design; the ports were made zero-based
  (see [docs/xezim/overview.md](../../../docs/xezim/overview.md)).
- SymbiYosys for 6569 and 6567R8: ABC BMC depth 24 and unbounded ABC PDR
  pass (dot/cycle counters, bus-slot range, output pipeline, collision
  hold, AEC-only-with-BA, write-pipeline lifetime, fetch-edge exclusivity,
  reset); all **five covers** are reached (latest step 11). A seeded
  write-pipeline defect fails the bounded check. Deep display events (bad
  lines, sprite DMA) are covered by the oracle comparison, not formal.
- Yosys synthesis and `check -assert` pass for every variant: **28,135**
  (6569), **28,397** (6567R8), **27,634** (6567R56A), **28,014** (8565) and
  **28,501** (8562) generic cells. These are generic logic counts, not
  FPGA/ASIC area or timing.

## Remaining qualification

The fetch and CPU interfaces are sampled per system clock rather than the
multiplexed RAS/CAS bus; composite video, palette and DRAM timing are not
modeled; VIC-IIe extensions are excluded. The reference is one emulator.
Original C64 software (in the C64 system build) with independently
checked screens, then hardware captures, are required before sign-off.
