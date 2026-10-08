# Apple IIe IOU — Coverage Report

Tool: xezim 0.10.5 `--code-coverage --code-coverage-scope tb_top.dut`,
driven by the full directed + random testbench (`scripts/run_coverage.sh`,
raw JSON at `work/coverage/rtl.json`).

## Result

| Metric | Covered | Note |
| --- | --- | --- |
| Statement | 167/167 (100.00%) | |
| Branch    | 94/94 (100.00%)    | |
| Toggle    | 378/380 (99.47%)   | 2 counts are one structurally-constant bit, see below |

## Justified toggle exclusion

`col_byte[7]` — bit 7 of the column-phase RA byte — is tied to `1'b0` in the
RTL because logical address bit **A15 is GND** in the IOU's display address
generation (TRM Table 7-12: "A15 ← GND"; the IIe video circuit only ever
addresses 32 KiB from the video scanner). A constant bit cannot produce
rise or fall transitions, so its two toggle counts are structurally
unreachable and are excluded by construction rather than by a test gap.
Everything else in the design — including every counter bit of the 21-bit
scanner, both phases of all eight soft-switch latches, the keyboard
auto-repeat chain and the md7 output — reaches both toggle directions.

## How the corners were reached

- Statement/branch 100% required making the structurally-unreachable arms
  *not exist* rather than excluding them: the C05x video-latch decode is
  written as the 74LS259-style if-chain (its full 3-bit case carried an
  unreachable implicit default), and the MD7 value mux evaluates for every
  `$C01x` read so its `$C011-$C018` default arm is genuinely executed while
  `md7_oe` stays off (the MMU owns those reads).
- AN2 set/clear writes (`$C05D`/`$C05C`) were added to the annunciator test
  to toggle `an2`/`an2_q`.
