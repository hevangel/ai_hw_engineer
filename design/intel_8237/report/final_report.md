# Intel 8237A final design report

## Result

Implemented the four-channel Intel 8237A synchronous functional core and completed `scripts/run_all.sh` successfully on 2026-10-01. The chip index and [overview](../README.md) include historical context and the uncertainty in the A-revision introduction date.

The core implements the NMOS register map, global low/high byte phase, base/current address and counts, masks, non-maskable block software requests, fixed/rotating arbitration, ownership grant/release, demand/single/block/cascade, read/write/verify, polarity, automatic reload, external EOP, normal/extended/compressed transfer phases and memory copy/fill through Temporary. Source-count and EOP-phase decisions are documented in the [specification](../spec/spec.md), with manufacturer sources rather than an RTL-derived oracle.

## Verification evidence

| Check | Result |
|---|---|
| Verilator `--lint-only -Wall` RTL | PASS, zero warnings; no RTL suppressions |
| Testbench lint | PASS; only simulation-specific blocking/initialization/unused-bit categories suppressed |
| SymbiYosys BMC | PASS, depth 32, ABC bmc3 |
| Unbounded safety proof | PASS, ABC PDR |
| Non-vacuity cover | PASS, all 11 goals reached within 18 steps (configured depth 36) |
| Verilator standalone simulation, seed 1 | PASS, 350609 checks, 66887 bus half-transfers |
| Xezim standalone simulation, seed 1 | PASS, identical check/transfer totals |
| Verilator supplemental seed 20261001 | PASS, 351553 checks, 66987 bus half-transfers |
| Xezim UVM 1800.2-2017 | PASS, 144 expected DMA events and 216 register read checks, zero errors/fatals |
| Xezim code coverage | 99.29% statements, 95.69% branches, 100.00% toggles |
| Yosys generic synthesis | PASS, 1913 generic cells, 322 flip-flop cells, zero `check -assert` problems |

The standalone suite checks payloads and exact addresses/counts, wrap/carry/borrow, sticky status read-to-clear, masked software requests on all channels, fixed and rotating contention, delayed grants and HLDA release interlock, demand pause/resume, cascade suppression, READY stalls, verify progress with READY low, timing-option strobes, auto/nonauto EOP, memory copy/fill, unequal source counts, Temporary, and EOP qualification in both copy phases. The maximum-count test checks all **65536** sequential verify transfers and the exact final address/count.

Formal assertions prove control safety, normal and copy-half accounting, Temporary capture, auto reload/masking, base-register preservation and global byte-phase advancement. CPU programming is symbolic in safety tasks. Cover alone uses eight real programming sequences with a finite READY stall; no cover-only constraints enter safety proofs. This is a property suite, not full equivalence or unbounded liveness against a permanently stalled peripheral.

UVM reports 25 component-name warnings under the installed Xezim/UVM combination, including library-created analysis ports; there are zero UVM errors/fatals and all scoreboards drain. The report preserves these warnings rather than claiming a warning-free UVM run.

## Issues found and resolved

- Directed tests corrected early observation of verify completion and a stimulus race while changing request polarity.
- Cover revealed that standard READY stalls remained in S3 instead of reaching the explicit SW state. RTL now transitions S3 to SW when not ready, keeping strobes/address stable until progress. The original cover goal remains and reaches SW after the fix.
- A wrapper run was interrupted by editing its script while it was executing. The final saved `work/run_all.log` comes from a fresh run of stable scripts and ends with `8237A COMPLETE FLOW PASSED`.

These were found by this design's own verification during implementation, not escaped defects.

## Toolchain and reproduction

Image: `ai-hw-engineer:latest`, image ID `sha256:c2cfeb3a6b3ba4f2d98f8eb3cc528db2a7c9661ad909b04e387cc0cfe1b8c0d6`.
Tools: Verilator 5.052; Yosys 0.69 (`9f75ca1f9`); SBY 0.69; Z3 5.1.0; Xezim 0.11.0 (`6558a1e`). UVM is the repository's 1800.2-2017 reference library.

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace ai-hw-engineer:latest \
    sh design/intel_8237/scripts/run_all.sh
```

Logs/netlists/traces live in the design's ignored `work/` directory: `run_all.log`, `sim/`, `formal/`, `coverage/`, and `synth/`. The [coverage report](coverage_report.md) describes residual paths.

## Limits

This is a functional single-clock reconstruction. Half-clock electrical timing, TTL/NMOS behavior, physical package replacement, page registers, full PC motherboard wiring, historical firmware execution and physical-silicon differential tests are outside this sign-off. Spec assumptions A1-A4 remain explicit. The compatible CMOS datasheet clarifies source counts but its enhanced readback registers and different external-EOP semantics are not silently substituted for the Intel NMOS interface. Generic synthesis is not a placed/routed device implementation or a frequency/area estimate.
