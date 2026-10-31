# IBM AT refresh request and clear chain — 2026-10-29

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11), shows U68 capturing the rising 8254 OUT1 edge and
sampling the result on rising `-DMA CLK`. U95 Q4 drives both active-low U68
clears. U95 is clocked by SYS CLK and cleared by -RESET; its D inputs are
the U99 NOR of `-REFRESH` and Q3, Q1, the U92 AND of Q2 and IOCHRDY, and
inverted Q3. This is a request/clear subcircuit, not the complete arbiter.

The browser captures in `work/at_refresh_source_20261029_01/` are
`sheet21_detail.png` (SHA-256
`a9ab46577eae460d3eb80857bab671cc25c03dbf23c14e3e86fbec52426e5ba5`)
and `u95_timing.png` (SHA-256
`060a0105e362264a419815a12532c4dac49be855659fe33f8e7e5ff168c1e8e0`).
The [fixture contract](../spec/ibm_at_dma_fixture.md) describes the pins and
the timing boundary.

## Verification

The standalone Verilator 5.052 `-Wall --assert` test passed in retained
container `codex-286-at-refresh-request-20261029-03`, with build and test logs
under `work/at_refresh_request_20261029_03/`. From the repository root in the
repository image:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_refresh_request_20261029_03 \
  sh design/intel_80286/scripts/run_at_refresh_request.sh
```

It checks independent timer and DMA edges, no request on falling edges or
while clear is asserted, the U95 stage progression, a four-clock IOCHRDY
stall, asynchronous request clear, return to idle, a second request and
reset during an active request. The test is included in `run_sim.sh`.
Yosys hierarchy/proc/opt/check/stat also passed in
`codex-286-at-refresh-request-yosys-20261029-01` with zero structural
problems, inferring six asynchronous-reset flops. These are component checks;
neither proves the board timing or the full 80286.

## Remaining integration

The test drives `-REFRESH` and IOCHRDY directly. Connect U68 to the actual
8254, complete the U69/U90/U98 request/grant network with the native CPU's
HOLD/HLDA, attach the row counter and page register, and generate a real
refresh cycle. Then connect U118 and the port-B read mux and run the original
BIOS refresh test. Current BIOS execution still stops at `F000:038A`; this
component does not establish refresh or full POST.
The checkpoint is recorded in [issue comment 6510250610](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6510250610).
