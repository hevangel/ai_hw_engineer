# SID reconstruction report

Status: **digital core implemented for 6581 and 8580; analog DAC/filter
stage, original software and physical validation open**. Measured on
2026-10-23 in `ai-hw-engineer:latest` (Verilator 5.052, xezim 0.11.0):
`scripts/run_all.sh` exits 0 with every gate below passing in one fresh
run.

## Reference

The oracle is reSIDfp as pinned in MAME's `3rdparty/residfp` at revision
`41a494b6ef80adc924ccb2bdba1ee69580276e0c`;
`scripts/fetch_sid_reference.py` verifies SHA-256 digests of 51 unchanged
files. reSIDfp is GPL-2.0-or-later: it is downloaded into ignored `work/`
and linked only into test executables. `tb/sid_oracle.cpp` widens access
by macro for observation, refreshes reSIDfp's hard-sync schedule each
clock (`voiceSync(false)`) and runs `clockDigital(1)`; combined-waveform
pull-down lookups from the RTL are answered from reSIDfp's own
"average" table for the model. Disagreements with floooh/chips are in the
[source review](../../../plans/mos_sid_source_review.md).

## Verification

- Strict Verilator `-Wall` lint passes for both models.
- `tb/sid_test.cpp` compares all three 12-bit waveform outputs and 8-bit
  envelope counters on every clock, the noise shift registers on every
  clock (`SID_SR_CHECK`), and every register read (POT, OSC3, ENV3, bus
  latch). Stimulus: all sixteen waveform combinations with ring/sync/gate
  on every voice, 40 random programs with dense register traffic, the
  test bit held through the shift-register reset and fade, waveform 0
  through the floating-DAC fade, 64 sync/ring programs, every
  attack/decay/release rate with attack and release completion, high-
  frequency all-sync programs until the same-cycle sync exception occurs
  (a coverage requirement), and 4,000
  gate toggles at every envelope-pipeline phase.

| Model | Clocks | Reads | Writes | Envelope changes | Attacks to $FF | Releases to $00 |
|---|---:|---:|---:|---:|---:|---:|
| 6581 | 13,886,356 | 24,714 | 41,913 | 30,012 | 12 | 9 |
| 8580 | 16,087,320 | 24,714 | 41,913 | 30,848 | 12 | 9 |

- **Fifteen seeded RTL defects** (ADSR rate table, exponential threshold,
  sustain compare, attack pipeline, gate delay, noise write-back mapping,
  shift feedback tap, sync rule, ring modulation, 6581 MSB clear, pulse
  compare, bus discharge, triangle, floating fade, shift-register fade)
  are each detected, with the per-clock shift-register comparison enabled.
  Two earlier survivors exposed coverage gaps and were resolved: the
  same-cycle sync exception needed the directed coincidence test, and the
  shift-register fade needed noise to run before the test bit so the
  register holds sparse bits when it fades.
- During development the comparison found an RTL write-back mask constant
  that cleared the wrong shift-register bits; it was visible only with
  combined noise waveforms and was fixed before this measurement.
- The first **30,000** oracle-checked clocks (6581) replay in **both
  Verilator and xezim**. xezim 0.11.0 reports settle-limit exhaustion on
  the core's single large `always_comb` but still matches on every record;
  see [docs/xezim/overview.md](../../../docs/xezim/overview.md).
- SymbiYosys for both models: ABC BMC depth 16 and unbounded ABC PDR pass
  (state encodings, pipeline bounds, exponential-period set, non-zero
  rate LFSR, test-mode accumulator hold, sustain nibble equality, pulse
  mask, bus-latch bound, holds, reset); all **five covers** are reached
  (hard sync at step 44).
- Yosys synthesis and `check -assert` pass: **10,092** (6581) and
  **10,156** (8580) generic cells.

## Remaining qualification

The DACs, filters, external filter and mixer are analog and not
implemented; the pull-down tables are reSIDfp's fits to sampled chips;
POT conversion is external. The reference is one emulator. Original C64
music software with independently checked output, and hardware captures,
are required before sign-off.
