# Specification: Ricoh 2A03 / 2A07 (NES CPU + APU)

## 1. Overview

The Ricoh RP2A03 (NTSC Famicom/NES) and RP2A07 (PAL NES) are single-die
parts combining a licensed NMOS 6502 core with its BCD adder disabled, the
five-channel Audio Processing Unit (APU), an OAM sprite DMA engine, the DMC
sample DMA reader and the controller-port I/O latches. This design reuses
the repository's verified native NMOS engine
[`mos_6502_native`](../../mos_6502_family/mos_6502/src/mos_6502_native.sv) with
`DECIMAL_ENABLE=0`; no second 6502 is written. Everything Ricoh added around
that core is new RTL in this folder.

The `REGION` parameter selects the die: `0` = RP2A03 (NTSC), `1` = RP2A07
(PAL). The variants differ only in the frame-counter step positions, the
noise period table and the DMC rate table (sources below); the RTL is
otherwise shared.

## 2. Features

- 6502 instruction set, all 256 opcode slots, native NMOS bus cycles
  (dummy reads, RMW double writes), decimal flag storable but ignored by
  ADC/SBC.
- APU: two pulse channels (duty, envelope, sweep with the pulse-1
  one's-complement negate quirk, length counter), triangle (linear counter,
  32-step sequencer clocked every CPU cycle), noise (15-bit LFSR, short
  mode, region period table), DMC (1-bit delta, 7-bit DAC, $4011 direct
  load, DMA sample fetch, loop and IRQ).
- Frame counter: 4-step / 5-step sequences, frame IRQ with the three-cycle
  flag window, delayed $4017 reset (3 or 4 CPU cycles by APU phase).
- `$4015` status/enable register; reading clears the frame IRQ flag.
- OAM DMA (`$4014`): halt + optional alignment + 256 get/put pairs
  (513 or 514 cycles), writes to `$2004` on the external bus.
- DMC DMA: halt, dummy, alignment, get; cycles stolen with RDY. Halted CPU
  read addresses are repeated on the bus, so board devices that act on a
  read (controller shift registers, PPU `$2007`) see the authentic extra
  reads.
- Controller I/O: OUT2–OUT0 latch on `$4016` writes; /OE1 and /OE2 strobes
  during `$4016`/`$4017` read cycles; D4–D0 from each port, D7–D5 from the
  CPU open-bus latch.

## 3. Interfaces

One `clk` rising edge is one CPU cycle (M2 period: 21.477272 MHz ÷ 12 =
1.789773 MHz NTSC; 26.601712 MHz ÷ 16 = 1.662607 MHz PAL). The board
derives this clock from the master oscillator.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | CPU cycle clock (M2 rising edge completes a cycle) |
| `rst_n` | in | 1 | Active-low /RST (synchronous to `clk`): the reset button, also low at power-on |
| `por_n` | in | 1 | Power-on reset, low only together with `rst_n`; clears APU channel registers and the frame mode |
| `irq_n` | in | 1 | External /IRQ (cartridge), wire-ORed with APU IRQs |
| `nmi_n` | in | 1 | /NMI (from the PPU) |
| `addr_o` | out | 16 | Address bus (A15–A0) |
| `data_i` | in | 8 | Data bus input from the board |
| `data_o` | out | 8 | Data driven during write cycles |
| `we_o` | out | 1 | R/W low (1 = write cycle) |
| `ext_rd_o` | out | 1 | Read cycle not served internally (board drives `data_i`) |
| `out_o` | out | 3 | OUT2–OUT0 (`$4016` write latch; OUT0 = controller strobe) |
| `oe1_n_o`, `oe2_n_o` | out | 1 | Controller port read enables (low during `$4016`/`$4017` read cycles) |
| `joy1_i`, `joy2_i` | in | 5 | D4–D0 presented by port 1 / port 2 (after the board's buffers) |
| `pulse1_o`, `pulse2_o`, `triangle_o`, `noise_o` | out | 4 | Channel DAC codes |
| `dmc_o` | out | 7 | DMC DAC code |
| `pc_o`, `a_o`, `x_o`, `y_o`, `s_o`, `p_o` | out | | Core observability (verification/front panel) |
| `fetch_o`, `jammed_o`, `fault_o` | out | 1 | Core status |
| `dma_o` | out | 1 | OAM or DMC DMA owns the bus this cycle |

The mixer is an analog resistor network on the console board; the chip's
outputs are the per-channel DAC codes. The host applies the documented
non-linear mixing formula ([NESdev APU Mixer](https://www.nesdev.org/wiki/APU_Mixer)).

## 4. Register map

| Address | Name | Access | Description |
|---|---|---|---|
| `$4000`/`$4004` | SQx_VOL | W | DDLC VVVV: duty, length halt / envelope loop, constant volume, volume/period |
| `$4001`/`$4005` | SQx_SWEEP | W | EPPP NSSS: enable, period, negate, shift |
| `$4002`/`$4006` | SQx_LO | W | Timer low 8 bits |
| `$4003`/`$4007` | SQx_HI | W | LLLL LTTT: length index, timer high; restarts envelope and sequencer |
| `$4008` | TRI_LINEAR | W | CRRR RRRR: control/length halt, linear reload |
| `$400A`/`$400B` | TRI_LO/HI | W | Timer; `$400B` loads length and sets linear reload flag |
| `$400C` | NOISE_VOL | W | --LC VVVV |
| `$400E` | NOISE_LO | W | M--- PPPP: short mode, period index |
| `$400F` | NOISE_HI | W | LLLL L---: length index, restarts envelope |
| `$4010` | DMC_FREQ | W | IL-- RRRR: IRQ enable, loop, rate index |
| `$4011` | DMC_RAW | W | -DDD DDDD direct DAC load |
| `$4012` | DMC_START | W | Sample address = `$C000 + A×64` |
| `$4013` | DMC_LEN | W | Sample length = `L×16 + 1` bytes |
| `$4014` | OAMDMA | W | Start OAM DMA from page `$XX00` |
| `$4015` | SND_CHN | W | ---D NT21 channel enables (clearing a bit zeroes its length; D restarts DMC if empty, clears DMC IRQ) |
| `$4015` | SND_CHN | R | IF-D NT21: DMC IRQ, frame IRQ, (open bus), DMC active, length>0 flags; read clears frame IRQ |
| `$4016` | JOY1 | W | OUT2–OUT0 latch |
| `$4016`/`$4017` | JOY1/JOY2 | R | D4–D0 from port, D7–D5 open bus |
| `$4017` | FRAME | W | MI-- ----: 5-step mode, IRQ inhibit |

`$4000`–`$4014` and `$4018`–`$401F` reads are not decoded internally; the
board's open-bus value is returned. The CPU test-mode registers
(`$4018`–`$401A`) are disabled on retail dies and not modelled.

## 5. Timing

- Pulse, noise and DMC timers are clocked once per APU cycle (every second
  CPU cycle). The triangle timer is clocked every CPU cycle.
- Frame-counter events (CPU cycles after the counter reset):

| Event | NTSC 4-step | NTSC 5-step | PAL 4-step | PAL 5-step |
|---|---|---|---|---|
| Quarter | 7457 | 7457 | 8313 | 8313 |
| Quarter + half | 14913 | 14913 | 16627 | 16627 |
| Quarter | 22371 | 22371 | 24939 | 24939 |
| IRQ flag readable | 29828–29830 | — | 33252–33254 | — |
| Quarter + half | 29829 | 37281 | 33253 | 41565 |
| Wrap (= cycle 0) | 29830 | 37282 | 33254 | 41566 |

- `$4017` write: the counter resets 3 CPU cycles after the write cycle when
  written during an APU cycle, 4 otherwise. A 5-step write clocks quarter and
  half frame at the reset. Setting IRQ inhibit clears the flag immediately.
- Noise period (CPU cycles) NTSC: 4 8 16 32 64 96 128 160 202 254 380 508
  762 1016 2034 4068; PAL: 4 8 14 30 60 88 118 148 188 236 354 472 708 944
  1890 3778.
- DMC rate (CPU cycles) NTSC: 428 380 340 320 286 254 226 214 190 160 142
  128 106 84 72 54; PAL: 398 354 316 298 276 236 210 198 176 148 132 118 98
  78 66 50.
- Length table: 10 254 20 2 40 4 80 6 160 8 60 10 14 12 26 14 12 16 24 18 48
  20 96 22 192 24 72 26 16 28 32 30.

## 6. Sources

- [NESdev wiki: 2A03](https://www.nesdev.org/wiki/2A03), [APU](https://www.nesdev.org/wiki/APU),
  [APU Frame Counter](https://www.nesdev.org/wiki/APU_Frame_Counter),
  [APU Pulse](https://www.nesdev.org/wiki/APU_Pulse), [APU Sweep](https://www.nesdev.org/wiki/APU_Sweep),
  [APU Envelope](https://www.nesdev.org/wiki/APU_Envelope),
  [APU Triangle](https://www.nesdev.org/wiki/APU_Triangle),
  [APU Noise](https://www.nesdev.org/wiki/APU_Noise), [APU DMC](https://www.nesdev.org/wiki/APU_DMC),
  [APU Length Counter](https://www.nesdev.org/wiki/APU_Length_Counter),
  [DMA](https://www.nesdev.org/wiki/DMA), [Standard controller](https://www.nesdev.org/wiki/Standard_controller),
  [Open bus](https://www.nesdev.org/wiki/Open_bus_behavior). These pages
  summarize die analysis (Visual 2A03) and hardware tests; they are the
  primary register/timing authority used here.
- Independent CPU oracle: [SingleStepTests 65x02](https://github.com/SingleStepTests/65x02)
  `nes6502/v1` vectors at revision `2f6980a2d95757486c7bee24355c360e40e2a224`
  (decimal-disabled 6502, full bus traces). Emulator-generated, not
  physical captures.
- Real software: Kevin Horton's `nestest.nes` with the Nintendulator
  reference log (`nestest.log`), and blargg's freely distributed APU/CPU
  test ROMs, run in the [NES system](../../system/nes/) and fetched at
  verification time into ignored `work/` folders.

## 7. Assumption ledger

| Assumption | Evidence | Status |
|---|---|---|
| ASSUMPTION: APU phase after reset: cycle 0 after /RST release is a "get" (DMA read) cycle; `$4017` writes on get cycles take effect after 3 cycles | Power-up phase is indeterminate on hardware (NESdev DMA page); test ROMs synchronize to it | Model choice; validated against blargg APU tests in the system regression |
| ASSUMPTION: DMC DMA during OAM DMA steals two cycles (get + realign) | NESdev DMA page describes 1–3 stolen cycles depending on alignment | Approximation; documented in report |
| Length-counter reload in the same cycle as a half-frame clock is applied (the hardware ignores it when the counter was non-zero) | NESdev Length Counter page | Not modelled; documented |
| The triangle outputs its sequencer value at ultrasonic periods | Hardware behavior (NESdev Triangle page) | Implemented as hardware |
| Reset (not power-on) leaves APU channel registers unchanged except `$4015`=0 and frame counter as if `$4017` was rewritten | NESdev APU reset notes; blargg `apu_reset` ROMs | Implemented with the separate `por_n` input: /RST alone clears enables, lengths, DMC and IRQ flags and restarts the sequencer in the last mode; power-on also clears channel registers and selects mode 0 |
| Frame IRQ flag is readable on counter cycles 29828–29830, i.e. 29831–29833 CPU cycles after a `$4017` write on an APU cycle | blargg `apu_test` 4-jitter and 6-irq_flag_timing | Implemented (fixed after the first ROM run showed it one cycle late) |
