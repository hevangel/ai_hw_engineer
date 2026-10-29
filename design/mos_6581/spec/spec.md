# SID (6581/8580) digital-core specification

## Scope and evidence

`mos_6581` implements the SID's digital behavior for both models: the 29
registers, three 24-bit phase accumulators with frequency, pulse width,
test, sync and ring modulation; the 23-bit noise shift register with its
two-phase clock and combined-waveform write-back; the envelope generators
(15-bit rate LFSR with the ADSR delay bug, state-change pipelines,
exponential decay thresholds, sustain comparison of both nibbles); OSC3,
ENV3 and POT reads; and the decaying data-bus latch for write-only
registers. Behavior follows the pinned reSIDfp engine selected in the
[source review](../../../plans/mos_sid_source_review.md); the C64
Programmer's Reference Guide (eighth printing, 1983, appendix O) is the
dated register description.

| `MOS8580` | Model | Bus latch lifetime (clocks) | Test-bit shift-register reset / fade | Floating DAC fade |
|---:|---|---:|---|---|
| 0 | 6581 | $1D00 | 50,000 / 15,000 | 54,000 / 1,400 |
| 1 | 8580 | $A2000 | 986,000 / 314,300 | 800,000 / 50,000 |

The 6581 clears the accumulator MSB when sawtooth is selected and the
(pulled-down) output MSB is low; the 8580 delays OSC3 for triangle/sawtooth
by one clock.

## Interfaces

| Port | Meaning |
|---|---|
| `ce_i` | One SID system clock (phase two) |
| `cs_i`, `rw_i`, `addr_i[4:0]`, `data_i`, `data_o` | CPU access completing at the clock; a read returns `data_o` before the edge |
| `pot_x_i`, `pot_y_i` | Sampled POT conversion results (external) |
| `pd_sel_o[v]`, `pd_index_o[v]`, `pd_value_i[v]` | Per voice: pull-down table select (0 none, 1 TS, 2 PT, 3 PS, 4 PTS, 5 NP), 12-bit index, looked-up value, combinational |
| `osc3_pd_index_o`, `osc3_pd_value_i` | 8580 OSC3 pull-down lookup for voice 3 |
| `wave_o[v]`, `env_o[v]` | 12-bit waveform and 8-bit envelope outputs for the analog stage |
| `fc_o`, `res_filt_o`, `mode_vol_o` | Filter and volume registers for the analog stage |

Order within one clock, matching `SID::write/read` then
`SID::clockDigital(1)`: the CPU access completes; the bus latch ages; the
three oscillators clock; the three envelopes clock; the voice outputs are
formed in voice order (ring modulation and the 6581 MSB clear see the
previous voice); hard sync applies when an eligible voice's MSB rose.

## Assumption ledger

- ASSUMPTION: `rst_n` is platform initialization equal to reSIDfp
  construction plus `reset()`: accumulators at the even-bit power-up
  pattern $555555, envelope counters at $AA, shift registers clocked once
  from all ones. It is not a claim about the RES pin timing.
- ASSUMPTION: combined-waveform pull-down is analog; the table port carries
  reSIDfp's fitted "average" tables in verification. They are fits to
  particular sampled chips and not RTL behavior.
- ASSUMPTION: decay timers (bus latch, floating DAC, shift-register reset)
  are digital counters standing in for capacitor discharge, with
  reSIDfp's constants.
- ASSUMPTION: hard-sync evaluation reproduces the reference's scheduled
  synchronization (see the source review), including its stale MSB-rising
  flag for a voice held in test mode.
- The DACs, filter, external filter and mixer are analog and not modeled.
