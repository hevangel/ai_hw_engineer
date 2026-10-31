# MOS 6581/8580 SID source review

Selects the reference for the [SID design](../design/mos_6581/README.md)
and records disagreements. Written 2026-10-23 from unchanged sources; a
reading of external code, not a hardware measurement.

| Reference | Revision | Scope |
|---|---|---|
| reSIDfp in MAME `3rdparty/residfp` (libsidplayfp project, GPL-2.0-or-later) | MAME `41a494b6ef80adc924ccb2bdba1ee69580276e0c` | 6581 and 8580: per-cycle oscillators, noise shifter with write-back, envelope pipelines, bus latch decay, combined-waveform pull-down fits, DACs, filters |
| floooh/chips `m6581.h` (zlib; derived from tedplay) | `9e88298ce56319953ac7a43213a1120359f7a3a6` | Sample-rate oscillators and a simplified filter |

reSIDfp is MAME's own SID engine (`src/devices/sound/mos6581.cpp` wraps it).
The project fetches the GPL sources into ignored `design/mos_6581/work/`
and links them only into test executables; nothing GPL is committed or
used by the RTL.

## Selection

reSIDfp is the oracle for the digital core. Its comments cite die analysis
and ENV3/OSC3 sampling for each pipeline detail: the two-stage shift-register
clock on accumulator bit 19, noise write-back from combined waveforms, the
ADSR LFSR rate counter with the delay bug, state-change pipelines,
exponential-decay thresholds, the test-bit shift-register reset/fade and
floating-DAC fade timers, hard sync with the "synced on the same cycle as
MSB rising" exception, and the decaying data-bus latch. The project's RTL
reproduces these per cycle and is compared on every clock with
`clockDigital()`.

The [C64 Programmer's Reference Guide](https://archive.org/details/c64-programmer-ref)
(eighth printing, 1983, appendix O) is the dated manufacturer description
of the 6581 registers, voices, envelope and filter.

## Preserved disagreements and qualifications

| Topic | reSIDfp (implemented or interfaced) | floooh/chips (not implemented) |
|---|---|---|
| Clocking | One update per system clock | Per output sample (sound_hz) |
| Noise | 23-bit shifter clocked through a two-phase pipeline on accumulator bit 19, write-back from combined waveforms | 23-bit shifter shifted directly, no write-back |
| Combined waveforms | Digital AND of base waveforms, then a fitted analog pull-down table per model (provided to the RTL by an external table port) | Digital AND only |
| Envelope | Rate LFSR with delay bug, state pipelines, exponential thresholds | Rate counter without the pipeline details |
| Filter / DAC | Non-linear 6581 op-amp/integrator models and 8580 model; kinked DACs | Linear state-variable filter |

Hard sync: reSIDfp schedules synchronization by predicting the next MSB
rise. The adapter refreshes that prediction every clock, which is
equivalent to evaluating sync each clock; the RTL then reproduces the
reference exactly, including its use of a stale MSB-rising flag for a
voice held in test mode when another voice triggers synchronization.
That stale-flag behavior is a property of the reference, recorded here
rather than claimed for silicon.

## Open requirements

- The analog stage (DAC nonlinearity, 6581/8580 filters, external filter,
  mixer) is not implemented; a sampled model needs its own error-bounded
  comparison and an explicit qualification.
- The combined-waveform pull-down tables are reSIDfp's fits to individual
  sampled chips ("average" strength); other chip samples differ.
- POT conversion (512-cycle RC measurement) is represented by external POT
  bytes as in reSIDfp.
- Original C64 music/software with independently checked output and
  hardware captures are required before sign-off.
