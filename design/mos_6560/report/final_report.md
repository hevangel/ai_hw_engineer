# VIC reconstruction report

Status: **complete digital chip implemented for 6560 (NTSC) and 6561
(PAL); original VIC-20 firmware boots; analog outputs and physical
validation open**. Measured on 2026-10-23 in `ai-hw-engineer:latest`
(Verilator 5.052, xezim 0.11.0): `scripts/run_all.sh` exits 0 with every
gate below passing in one fresh run.

## Register verification

- Verilator 5.052 strict `--lint-only -Wall`: passes. Mirror address bits
  are deliberately unused and documented locally; no global warning
  suppression is used for the RTL.
- Verilator and xezim 0.11.0 run the same self-checking SV bench:
  **3,557,430 checks each**, over **197,635 sampled accesses**. All 16,384
  physical addresses run all four phase/read-write combinations. Every
  register, all sixteen mirrors and all 256 byte values run write/read
  checks with full configuration retention checks. All 512 raster input
  values are read through registers 3/4.
- SymbiYosys: ABC BMC depth 12 and unbounded ABC PDR pass. Yices cover
  reaches **all five targets**, latest at step 4.
- Yosys generic synthesis and `check -assert`: **406 generic cells**
  including **87 configuration flip-flops**.

## Raster verification

The separate PAL/NTSC timing component implements internal scan counters,
the independently phased CPU raster-readback view, its next-clock view
used by light-pen capture, and frame-boundary NTSC interlace selection.

- Strict lint passes for both parameter profiles.
- ABC BMC depth 20 and unbounded ABC PDR pass for each profile, including
  the property that the next-clock readback equals the readback after the
  edge. All **eight cover targets** are reachable (latest PAL step 74,
  NTSC step 68).
- Unchanged independent references match **7,992,977 checked clocks** and
  **15,985,954 profile comparisons**, including all **65 request phases
  for each interlace exit field**.
- The same SV replay bench passes in **both Verilator and xezim**, each
  consuming **252,646 records** (**505,292 comparisons**).
- Yosys synthesis and `check -assert` pass: **299 generic cells** for PAL
  and **458** for NTSC (the readback logic is evaluated for both the
  current and the next clock).

See [reference provenance and adapter limits](raster_reference.md).

## Complete digital VIC

`mos_6560` integrates registers, raster, display sequencer, light-pen
capture and the digital sound generator for both variants
([specification](../spec/spec.md)). The oracle is nineteen unchanged MAME
functions selected in the [fetch source review](../../../plans/mos_vic_fetch_review.md),
which also preserves every disagreement with floooh/chips.

- Strict lint passes for the complete chip in both profiles.
- The C++ comparison checks, on every clock of both profiles, the fetch
  strobe and kind, the 14-bit fetch address, all four pixel colors, every
  register read and every sound sample: **13,802,220 clocks, 27,604,440
  profile comparisons** over standard screens, 160 random register
  programs, fully random bus traffic, light-pen sweeps across each frame
  boundary, holds, resets and interlace. Coverage counters (matrix and
  character fetches, light-pen captures, sounding samples, color writes
  inside the display, final-line extra-bit clears, interlace, reads) are
  nonzero for both profiles; see [the reference report](vic20_software.md).
- **Twelve seeded RTL defects** (load pipeline, color-write timing,
  character mask, start delay, matrix carry, PAL column cap, light-pen
  extra bit and relock, noise tap and edge, prescale, next readback) are
  each detected by the comparison. Two earlier survivors were resolved:
  the NTSC 31-column cap proved unobservable (a 65-clock line cannot fetch
  31 columns), and the light-pen extra-bit rule gained a directed sweep.
- The first **200,000** oracle-checked records replay in **both Verilator
  and xezim** (**400,000 profile comparisons**). A xezim 0.11.0
  discrepancy on a packed `localparam` table indexed in a loop was isolated
  by record-by-record state comparison against Verilator and worked
  around with a function; see [docs/xezim/overview.md](../../../docs/xezim/overview.md).
- Display-sequencer formal: ABC BMC depth 20 and unbounded ABC PDR pass
  for both profiles (fetch exclusivity, address formula, load pipeline,
  pending-write consumption, holds, reset, exhausted-shifter border); all
  **six covers** are reached (latest step 11). A seeded pending-write
  defect fails the proof.
- Yosys synthesis and `check -assert` pass for both profiles: **2,569
  generic cells** for PAL (display 1,271, register block 406, sound 350,
  raster 301, light pen 234) and **2,660** for NTSC.

## Original VIC-20 firmware

The original 901486-01 BASIC, 901486-07 (PAL) / 901486-06 (NTSC) KERNAL
and 901460-03 character ROMs (SHA-1 equal to MAME's `ROM_LOAD` entries)
boot on the native 6502, two 6522 VIAs and this VIC to the exact BASIC
start-up screen, with the VIC compared against MAME on every clock of the
boot. Details, fixture assumptions and screenshots are in
[vic20_software.md](vic20_software.md).

## Remaining qualification

Composite sync/colour, the DAC curve, RC POT conversion, the pin-37 mask
options and the idle-cycle PHI1 bus are not implemented. The reference is
one emulator. The boot exercises KERNAL display/IRQ paths only; keyboard
input, further original programs (cartridges, games, sound) and hardware
captures remain before VIC sign-off and before system builds depend on it.
No working VIC-20 system or requested console/computer is claimed.

The [plan](../plans/implementation_plan.md) and
[series ledger](../../../plans/mos_historical_series.md) retain these
requirements and all remaining chips and requested systems.
