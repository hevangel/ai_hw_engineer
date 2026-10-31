# Commodore 64 specification

## Historical sources and provenance

- System year: MAME [c64.cpp at 41a494b6](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/mame/commodore/c64.cpp)
  (`COMP( 1982, c64 ...)` and `c64p`). Year only.
- Firmware: BASIC 901226-01, KERNAL 901227-03, character ROM 901225-01.
  `scripts/fetch_firmware.py` downloads them at run time (zimmers.net, then
  the VICE svn-mirror on GitHub at commit d928b850), checks the SHA-256 and
  MAME SHA-1 recorded in the script, and writes `work/*.bin` and `*.hex`.
  Nothing copyrighted is committed. See [reference/README.md](reference/README.md).
- Independent oracle: unchanged VICE x64sc (3.7.1 in the build container),
  run headless through its text monitor.

## Hardware and integration

| Part | RTL | Board role |
|---|---|---|
| MOS 6510 | `design/mos_6510` on the native `mos_6502` engine | CPU, processor port P0-P5 (LORAM, HIRAM, CHAREN, cassette) |
| MOS 6569 / 6567R8 | `design/mos_6567` (`VARIANT` 0 = PAL, 1 = NTSC) | video, BA/AEC bus arbitration, IRQ, DRAM refresh |
| MOS 6581 | `design/mos_6581` | sound at $D400 |
| MOS 6526 x2 | `design/mos_6526` | CIA1 $DC00 (keyboard, joysticks, IRQ), CIA2 $DD00 (VIC bank, IEC, NMI) |
| 906114-01 | `design/commodore_906114` | address decode, evaluated for the CPU access and both VIC fetch phases |
| Storage | `src/c64_memory.sv` | 64 KiB DRAM, 1 Kx4 color RAM, three ROMs (synthesis blackbox) |

**Clocks.** `clk` is the VIC dot clock (8 per CPU cycle). A 3-bit dot
counter generates phi2 (high for dots 3-6); the CPU clock is its inverse,
so a CPU cycle completes half a dot before the VIC's cycle edge. The CIAs
sample on phi2; the SID gets one clock enable per cycle at dot 4.

**Bus.** The PLA sees the CPU address with `aec_i = !vic_aec`, and the
VIC's phase-1 and phase-2 fetch addresses with VA15/VA14 = inverted CIA2
PA1/PA0. CPU reads mux DRAM, the ROMs, VIC/SID/color RAM/CIA registers by
PLA output; unmapped reads (I/O1, I/O2, Ultimax holes) return the VIC's last
bus byte. Color RAM reads put the VIC's last byte in the upper nibble. Writes
to $0000/$0001 also write the VIC's last bus byte into DRAM (the 6510 port
does not drive the data bus for them).

**Inputs.** Keyboard: an 8x8 one-level wired-AND matrix, key bit
`8*column + row` with column = CIA1 PA. Joystick 2 on CIA1 PA, joystick 1
on PB; light pen = PB4 of port 1. IEC lines go through 7406 inverters and
are left unterminated (no devices). The TOD inputs of both CIAs get a
50 Hz (PAL) or 60 Hz (NTSC) square wave counted in CPU cycles.

**Interrupts.** IRQ = CIA1 and VIC; NMI = CIA2 and RESTORE.

**Reset.** `rst_n` is synchronized and released at the dot 6-to-7
boundary; the VIC leaves reset `VIC_START_DELAY` system clocks later
(automatic: PAL 11, NTSC 10).

## Host interface

`host/simulator.cpp` is a persistent Verilator harness with a line
protocol (`STATE`, `FRAME`, `RUN`, `RUNF`, `KEYS`, `RESTORE`, `JOY1`,
`JOY2`, `RESET`, `PEEK`, `UNTILPC`, `CHECKPOINT`, `TRACE`, `CAPTURE`). It
assembles the VIC pixel stream into a 520x312 raster and mixes the SID's
digital voice outputs at about 44.1 kHz. `host/server.py` serves the web
panel (`host/web/`), a typing queue, the RESTORE and RUN/STOP+RESTORE
pulses, joystick 2, and FST waveform capture at `/waveform.fst`, with
Surfer embedded from `/opt/surfer/webapp` when installed.

## ASSUMPTION ledger

1. **CPU/VIC power-on phase.** Undefined on real hardware. The VIC starts
   11 (PAL) or 10 (NTSC) system clocks after the CPU, the phase unchanged
   VICE x64sc uses at power-on; with it the PAL boot is cycle-exact.
2. **DRAM power-on contents.** Undefined. Alternating 64-byte $00/$FF
   stripes are used; `+raminit=<hex>` fills a constant (the oracle runs use
   zero in both models).
3. **RESTORE** drives NMI by level. The board's 556 monostable is reduced
   to the key level; CIA2's IRQ output shares the line.
4. **SID combined waveforms** use the digital AND with the `mos_6581`
   pull-down table port held at "no pull-down"; POT inputs read $FF.
   No analog filter, DAC or output stage.
5. **No cartridge.** /EXROM and /GAME are pulled up; an Ultimax VIC ROMH
   fetch would read $FF.
6. **No IEC devices, datasette, paddles or light pen.** The KERNAL's
   device timeouts behave as with nothing connected.
7. **I/O reads are BA-gated** in the PLA (see the
   [PLA ledger](../../../design/commodore_906114/spec/spec.md)).
8. **Video output** is the VIC's digital color index per dot; the
   composite encoder is not modeled and the panel uses the Pepto palette.

## Acceptance criteria

- Original ROMs boot to the banner, `38911 BASIC BYTES FREE` and `READY.`
  on both boards.
- PAL: cycle-exact agreement with VICE at the first six KERNAL IRQ entries
  and the first READY-loop fetch, identical 64 KiB RAM image there, and two
  identical 8,192-instruction traces. NTSC: same registers and RAM image at
  READY (stack bytes below S excepted); cycle offsets reported.
- Typed BASIC, text-screen pixels, SID pitch, joystick, TOD and RESTORE
  regressions pass on both boards.
- Lint, backend API and synthesis checks pass.
