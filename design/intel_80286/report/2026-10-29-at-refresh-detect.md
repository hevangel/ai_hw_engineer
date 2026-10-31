# IBM AT refresh-detect flip-flop — 2026-10-29

The [IBM 5170 type 1 system-board schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11, printed page 1-81), shows U118's ALS74 D input connected
to its inverted Q output, its clock connected to `+REFRESH`, active-low CLR
tied high, and Q labeled `REF DET` going to sheet 17. The active-low preset
connects to `PULL UP`; sheet 3 (PDF page 2) shows that net pulled to +5 V via
R19 (1 kΩ). Thus the board keeps preset inactive; it does not use that pin to
initialize the output.
The source correction and updated test are recorded in
[issue comment 6492014603](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6492014603).
The saved browser capture `work/at_refresh_source_20261029_01/u118.png` has
SHA-256 `ed725745e7f5ebe488088e162e05b4b5358080d64f182004ca43b128c1789fd0`.
The adjacent arbitration capture has SHA-256
`ba1f0a61f18352f405d17c6041288192609337536df43050eabc5d04330d4de7`.
The sheet 3 pull-up capture `sheet3_pullup.png` has SHA-256
`990028e70194d49ba38ef28fea173a0f6f1a79730810f878d5fd9cea0cdd8e10`, and
`r19.png` has SHA-256
`72b2ccf33e2b5250c5c9972f73675ad6274ac3a56adcb87b58efa8cc923626b5`.
The sheet 21 overview `sheet21_overview.png` has SHA-256
`a01e4ba807396cff4c14cf8ffc486f3993e7a8ad8c01b0d51b1a86e28f57ee3e`.

The standalone [digital flip-flop](../tb/intel_80286_at_refresh_detect.sv)
toggles its output on rising `+REFRESH` edges and asynchronously presets high.
It neither generates refresh cycles nor models device timing. It has no
invented power-on value; future board integration must tie preset high. See the
[fixture contract](../spec/ibm_at_dma_fixture.md) for the open integration.

## Checks

In the repository Docker image, the following command passed with Verilator
5.052 and assertions enabled, using a fresh evidence directory:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_refresh_detect_20261029_03 \
  sh design/intel_80286/scripts/run_at_refresh_detect.sh
```

The test checks 16 rising and falling edges, held-high behavior, asynchronous
preset while the clock is high, clock edges while preset remains asserted,
and resumption after preset release. A second instance has preset tied high,
and the test checks edge behavior relative to its observed initial value. The
two-state simulation cannot determine the physical startup value. The retained container is
`codex-286-at-refresh-detect-20261029-03`; build and simulation logs are in
the evidence directory. The test is now included in `run_sim.sh`.

Yosys `read_verilog -sv`, hierarchy checking, `proc`, `opt`, `check` and `stat`
passed in `codex-286-at-refresh-detect-yosys-20261029-01`, reporting no
structural problems and inferring one asynchronous-reset flip-flop plus one
inverter. This is a structural check of this standalone circuit, not a CPU
or board synthesis result.

## Remaining work

Trace the request/grant logic from the schematic, wire
the request through the native CPU's HOLD/HLDA path, connect the refresh row
counter and page register to a real memory refresh cycle, and trace the port B
read mux. Only after those pieces are checked can the original BIOS test at
`F000:038A–03A2` provide evidence of refresh. The current BIOS fixture still
stops at `F000:038A`; neither this test nor the component check extends POST.
The checkpoint is recorded in [issue comment 6491915305](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491915305).
