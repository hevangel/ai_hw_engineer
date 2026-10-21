# VIC reconstruction report

Status: **shared CPU register component implemented; complete VIC open**.
Measured on 2026-10-20 in `ai-hw-engineer:latest`. The new aggregate script
tests this component only. It must expand as further blocks are integrated.

## Verification

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

## Remaining qualification

Raster readback currently comes from a nine-bit fixture input. Actual
NTSC/PAL counters, sync/interlace, master-clock divider, PHI1 memory fetches,
pixel output, sound, RC conversion and light-pen capture are not implemented.
No working VIC-20 or requested console/computer system is claimed. Resolve
the manufacturer/reference clock discrepancy, physical mask options,
power-on initialization and sampled-boundary assumptions, then validate
against independent traces and actual original software before sign-off.

The [plan](../plans/implementation_plan.md), [specification](../spec/spec.md)
and [series ledger](../../../plans/mos_historical_series.md) retain these
requirements and all remaining chips and requested systems.
