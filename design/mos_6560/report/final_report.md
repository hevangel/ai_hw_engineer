# VIC reconstruction report

Status: **CPU register and sampled raster components implemented; complete
VIC open**. Measured on 2026-10-23 in `ai-hw-engineer:latest` (Verilator
5.052, xezim 0.11.0): `scripts/run_all.sh` exits 0 with every register and
raster gate below passing in one fresh run. The aggregate script tests these
components only and must expand with later integration.

## Register verification

- Verilator 5.052 strict `--lint-only -Wall`: passes. Mirror address bits
  are deliberately unused and documented locally; no global warning
  suppression is used for the RTL.
- Verilator and xezim 0.11.0 run the same self-checking SV bench:
  **3,557,430 checks each**, over **197,635 sampled accesses**. All 16,384
  physical addresses run all four phase/read-write combinations. Every
  register, all sixteen mirrors and all 256 byte values run write/read
  checks with full configuration retention checks. All 512 raster input
  values are read through registers 3/4. Dynamic light-pen/POT bytes remain
  externally supplied values, even after attempted writes.
- SymbiYosys: ABC BMC depth 12 and unbounded ABC PDR pass. Yices cover
  reaches **all five targets**, latest at step 4: mirrored raster read,
  light-pen and POT reads, rejected neighboring address, and two distinct
  retained register values. Storage/drive/readback assertions include
  arbitrary input changes and subsequent resets.
- Yosys generic synthesis and `check -assert`: passes, **406 generic cells**
  including **87 configuration flip-flops**. This is a generic
  logic result, not an FPGA/ASIC timing or physical-area measurement.

The bench is an explicit test of the sourced manufacturer register
contract. It is not an independent historical-software or full-chip oracle.
Ignored build logs, traces and synthesis output are under `work/` and can
be reproduced with `sh scripts/run_all.sh` from the design directory.

## Raster verification

The separate PAL/NTSC timing component implements internal scan counters,
the independently phased CPU raster-readback view, and frame-boundary NTSC
interlace selection. Readback is connected to real register blocks in the
test wrapper. The interface counts system clocks; it generates neither
composite sync nor physical oscillator phases.

- Strict Verilator RTL lint passes for both parameter profiles.
- ABC BMC depth 20 and unbounded ABC PDR pass for each profile. The
  properties check counter ranges, reset and clock-enable holds, line/frame
  transitions and interlace state/length, plus exact NTSC readback threshold
  and reset cases. All **eight cover targets** are reachable at depth 80
  (latest PAL step 74, NTSC step 68). These covers witness early line/hold/
  reset behavior; complete frame/interlace transitions are exercised in
  simulation rather than claimed as formal cover witnesses.
- Unchanged independent references match **7,992,977 checked clocks** and
  **15,985,954 profile comparisons**. The complete PAL model supplies genuine
  register 3/4 reads; six unchanged extracted MAME timing functions supply
  NTSC scan/readback/interlace behavior. Tests include all **65 request
  phases for each interlace exit field**, both 263/262-line fields,
  progressive frames, missed-boundary pulses, live reads during timing
  holds and mid-frame initialization.
- The same SV replay bench passes in **both Verilator and xezim**, each
  consuming **252,646 records** and comparing both profiles (**505,292
  comparisons**). The record count comes from the native oracle run;
  truncated, malformed or extra records fail. It avoids simulator-dependent
  EOF timing after the last newline, which made an earlier xezim run fail
  after all records had matched.
- Yosys synthesis and `check -assert` pass: **107 generic cells** for PAL
  and **178** for NTSC. These are isolated raster component counts, not
  complete-chip area or timing estimates.

See [reference provenance and adapter limits](raster_reference.md) for
hashes, original licenses, genuine-bus sampling, inert adapter services
and contiguous replay segments. The references remain unchanged and do
not establish physical chip measurements. All component gates are invoked
by `scripts/run_all.sh`; logs remain ignored under `work/`.

## Remaining qualification

The standalone register bench still accepts fixture raster values; the
integration bench uses the implemented timing component. Composite sync,
master-clock divider, PHI1 memory fetches, pixel output, sound, RC conversion
and light-pen capture are not implemented. Interlace/readback behavior is
qualified against an independent digital model, with physical validation open.
No working VIC-20 or requested console/computer system is claimed. Resolve
the manufacturer/reference clock discrepancy, physical mask options,
power-on initialization and sampled-boundary assumptions, then validate
against independent traces and actual original software before sign-off.
The [fetch source review](../../../plans/mos_vic_fetch_review.md) preserves
disagreements between independent implementations for the next stage.

The [plan](../plans/implementation_plan.md), [specification](../spec/spec.md)
and [series ledger](../../../plans/mos_historical_series.md) retain these
requirements and all remaining chips and requested systems.
