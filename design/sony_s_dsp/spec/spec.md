# Specification: Sony S-DSP

## 1. Overview

The S-DSP generates SNES audio from BRR samples in audio RAM. The model
follows the 32-step per-sample schedule that blargg derived from hardware
and that ares and snes9x's `SPC_DSP` use. Sources:
[fullsnes "SNES APU DSP"](https://problemkaputt.de/fullsnes.htm) and the
[SNESdev wiki S-DSP page](https://snes.nesdev.org/wiki/S-DSP_registers).

## 2. Features

- Eight voices: BRR decode (four samples per step, filters 0-3, loop and
  end flags, ENDX), 14-bit pitch with pitch modulation from the previous
  voice, 4-point gaussian interpolation with the hardware table, noise
  generator, ADSR and the five GAIN modes on the 31 shared rate counters.
- Stereo mix with per-voice and master volume, mute (FLG), and the echo
  unit: echo buffer in audio RAM (ESA, EDL), 8-tap FIR with the hardware
  clamping, feedback (EFB), echo write disable, and echo volume.
- Registers $00-$7F through the S-SMP window; KON/KOFF with the hardware
  sampling at alternate samples; reset and soft reset through FLG.

## 3. Interfaces

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rst_n` | in | 1 | Master clock, reset |
| `tick` | in | 1 | Phase advance, one per S-SMP cycle (1.024 MHz) |
| `reg_addr`, `reg_wr`, `reg_wdata`, `reg_rdata` | | 7,1,8,8 | Register window |
| `smp_addr`, `smp_wr`, `smp_wdata`, `smp_rdata` | | 16,1,8,8 | S-SMP's audio RAM port; write at `tick`, read data valid at `tick` |
| `ram_addr`, `ram_we`, `ram_wdata`, `ram_rdata` | | 16,1,8,8 | External 64 KB SRAM, one-clock registered read |
| `sample_valid`, `sample_l`, `sample_r` | out | 1,16,16 | 32 kHz stereo output |
| `phase_o`, `overrun_o` | out | 5,1 | Current phase; set if a phase's micro-ops were still running at the next tick |

## 4. Functional description

Each `tick` advances the phase counter (0-31). The steps of that phase, as
listed in blargg's schedule, are expanded by `scripts/gen_tables.py` into at
most eight micro-operations, which run one per master clock right after the
tick. Every audio RAM read takes one clock. Between phases the RAM port
carries the S-SMP's address, so the CPU sees one access per cycle.

## 5. Assumption ledger

| # | Assumption | Reason / evidence |
|---|------------|-------------------|
| A1 | Within a phase the order of the steps is what matters; the exact clock inside the 21 master clocks of a phase is not. | Hardware timing below the 1.024 MHz step is not observable by software. |
| A2 | The gaussian table is computed from the ares formula. | `scripts/fetch_oracle.py` checks it entry by entry against the 512-entry dump in snes9x `SPC_DSP.cpp`; they match. |
| A3 | The S-SMP writes audio RAM at the tick, before the DSP's micro-ops for the new phase. | Keeps the CPU and DSP accesses in the order the schedule implies. |
