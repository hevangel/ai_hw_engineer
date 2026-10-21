# VIC 6560/6561 reconstruction specification

## Scope and evidence

The complete target is a phase-separated VIC bus, NTSC/PAL raster and sync,
matrix/character/color fetches, pixels, three tones/noise/volume, POT and
light-pen capture. The initial module implements only the common CPU
register file. No raster, analog converter, pixel or audio generator is
implied by its external readback inputs. See the [source review](../../../plans/mos_vic_source_review.md)
for the pinned manufacturer and independent sources and timing discrepancies.

## Register block contract

`mos_6560_regs` samples writes on rising `clk` when `phi2_i` is high.
The integration clock represents the completion of a CPU phase-two access;
it is not a claimed physical VIC master-clock generator. `addr_i` is the
actual fourteen-bit chip address. A13..A8 must equal binary 010000:
addresses 1000..10FF select registers, A7..A4 are mirrors and A3..A0 select
one of sixteen bytes. VIC-20 address 9000 maps to chip address 1000 after
board wiring; this module does not perform that board mapping.

`rw_i=1` reads. `data_oe_o` is asserted only during selected phase-two reads
with `rst_n=1`. A disabled output is represented by separate enable and
zero data, not by driving a shared bus. Writes never drive the CPU bus.
Configuration output `config_o[8*r +: 8]` exposes stored register r to
future peripheral blocks; slots 4,6,7,8,9 and bit 7 of slot 3 are zero.

| Registers | Read | Write |
|---|---|---|
| 0,1,2,5,A..F | Stored byte | Replace stored byte |
| 3 | Raster bit 0 in bit 7; stored bits 6..0 | Store bits 6..0 |
| 4 | Raster bits 8..1 | Ignored |
| 6,7 | External captured light-pen X/Y bytes | Ignored |
| 8,9 | External POT X/Y result bytes | Ignored |

Raster, light-pen and POT input values are supplied by the test fixture
until the actual corresponding blocks exist. Read-only writes must never
override these inputs or change other configuration bytes. Both NTSC/PAL
use this register contract; no variant timing equivalence is claimed.

## Assumption ledger

- ASSUMPTION: synchronous `rst_n=0` initializes all stored configuration
  to zero and suppresses CPU drive. This is a deterministic platform
  initialization, matching the independent PAL model's initial registers;
  it is not a claim that a physical CPU reset clears VIC registers. Pin 37
  has mutually exclusive mask options. Actual power-on/reset behavior and
  validation with original VIC-20 software remain open before sign-off.
- ASSUMPTION: a clean digital phase-two completion boundary suffices for
  this isolated register block. Setup/hold, PHI1 display fetch ownership and
  asynchronous pin changes require later integration and software tests.

The manufacturer sheet's PAL oscillator and the independent model's clock
disagree; retain that open issue. NTSC readback also includes an independent
model's raster offset/partial-line behavior. Do not infer raster generation
from this block's nine-bit raster input or substitute C64 timing constants.
