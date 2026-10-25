# Space Invaders virtual-platform specification

## Machine and sources

Reconstruct the original Taito **Space Invaders** (1978; licensed to Midway
in the US) arcade board: the repository's verified Intel 8080 core at the
original 1.9968 MHz rate, 8 KiB game ROM, 1 KiB work RAM, 7 KiB frame-buffer
VRAM, the hardware shift register, the coin/start/control input ports, the
discrete-sound port latches, the watchdog, and the two 60 Hz RST interrupts.
The original ROM set runs unmodified in RTL; there is no loader, no BIOS and
no host interception.

First introduced: **1978** (Taito, Japan; Midway licensed release the same
year). Only the year-level claim is made here.

Primary sources:

- [Computer Archeology — Space Invaders Hardware](https://www.computerarcheology.com/Arcade/SpaceInvaders/Hardware.html):
  memory map, shift register, port definitions, interrupt vector decode,
  screen geometry. Consulted as the hardware authority.
- [Annotated Space Invaders disassembly](reference/invaders.asm) (David
  Levy's ASMX listing hosted by Computer Archeology). Code-level ground
  truth: the ISR entry points at 0008h/0010h, the `IN 1`/`IN 2` bit masks
  the game actually tests, the `OUT 3`/`OUT 5` sound latches and the
  `OUT 6` watchdog feeds in the main loop.
- [MAME `invaders` layout](reference/invaders.lay) (CC0-1.0): the color-gel
  overlay bands used by the web screen.
- Original ROM: Taito, © 1978 Taito/Midway — copyrighted, never committed.
  `scripts/fetch_roms.py` downloads the four 2 KiB images
  (INVADERS-H/G/F/E) from the immutable
  [PCjs archive](https://www.pcjs.org/machines/arcade/invaders/rom/) at a
  pinned git revision into the ignored `work/` folder, verifies the
  container git-blob hashes, and records the ROM CRC-32 values
  `734f5ad8 / 6bfaca4a / 0ccead96 / 14e538b0`, which match the canonical
  MAME `invaders` driver checksums — an independent cross-check of the
  archive's authenticity.
- CPU clock 1.9968 MHz (19.968 MHz crystal ÷ 10) and 60 Hz refresh per the
  hardware page and MAME driver; 33 280 CPU cycles per frame exactly.

## Hardware boundary

`space_invaders` (`src/space_invaders.sv`) instantiates the repository
`intel_8080` and models the board. One rising clock edge is one
implementation step; every bus transfer completes in one step
(`bus_ready_i` tied high), the functional bus contract of the 8080 design.
The nominal 2 MHz rate appears only in interrupt/frame bookkeeping, not in
per-cycle pin timing.

### Memory

| Range | Contents |
|---|---|
| 0000h–1FFFh | ROM: invaders.h @0000, invaders.g @0800, invaders.f @1000, invaders.e @1800 (read-only; CPU writes ignored) |
| 2000h–23FFh | work RAM, 1 KiB |
| 2400h–3FFFh | frame-buffer VRAM, 7 KiB = 224 rows × 32 bytes |
| 4000h–7FFFh | mirror of 2000h–3FFFh (hardware page: "$4000+: RAM mirror") |

ROM contents load from a `$readmemh` image supplied by plusarg (built in
`work/` from the fetched binaries); the copyrighted bytes never enter Git.
Power-up RAM/VRAM is zero. Reads at 8000h+ return FFh. RAM, VRAM and ROM
live in `src/si_memory.sv`, an external-interface storage model treated as
a blackbox by the synthesis check, following the system/ibm_pc and Altair
conventions.

### Screen

224×256, 1 bit per pixel, 60 Hz. VRAM row 0 (2400h) is the lower-left
corner; the cabinet monitor is rotated 90° counter-clockwise. The host
renders VRAM and applies the original color-gel bands (red y 32–62; green
y 184–240; partial-width green y 240–260; white elsewhere) from
[reference/invaders.lay](reference/invaders.lay). CRT phosphor, scanout
timing and video/CPU bus arbitration are outside the model: the CPU reads
and writes VRAM as ordinary RAM, as the real board allows.

### Interrupts

The INT flip-flop toggles at displayed lines 96 and 224 of the 256-line
frame. Vector decode `0xC7 | (64V<<4) | (!64V<<3)`:

- line 96 (frame cycle 12 480): inject opcode **CFh** (RST 8 → ISR at 0008h,
  "beam near the middle"; the disassembly names it `ScanLine96`)
- line 224 (frame cycle 29 120): inject opcode **D7h** (RST 10 → ISR at
  0010h, start of VBLANK, `ScanLine224`)

The request stays asserted until the CPU acknowledges (INTA), matching the
hardware's flip-flop clear. Delivery still requires INTE per the 8080
contract; a request pending across DI stays pending. After power-up reset
the first interrupt is RST 8 (beam starts at the top of the frame).

### Shift register

16-bit register `xxxxxxxx yyyyyyyy`:

- `OUT 4`: previous high byte moves to low, new byte becomes high
  (write 00h, then AAh, then FFh → 0000, AA00, FFAA).
- `OUT 2` bits 2–0: 3-bit offset.
- `IN 3`: `(register >> (8 − offset)) & 0FFh` — offset 0 returns the high
  byte, offset 7 returns `xyyyyyyy`.

### Input ports (read)

Bit meanings pinned from the disassembly's masks (single-player upright):

| Port | Bits | Source |
|---|---|---|
| 0 | bit0 DIP4 (power-up self-test), bits1–3 read as 1, bits4–6 harness fire/left/right, bit7 port-7 demux quirk | hardware page; **never read by game code** |
| 1 | bit0 CREDIT (coin), bit1 2P start, bit2 1P start, bit3 reads as 1, bit4 1P shot, bit5 1P left, bit6 1P right, bit7 0 | `IN 01; RRC` credit path; mask 76h in the hidden-sequence check |
| 2 | bits1–0 DIP ships (3/4/5/6), bit2 TILT, bit3 DIP6 bonus-ship, bits4–6 2P shot/left/right, bit7 DIP7 demo coin info | `CheckHandleTilt` mask 04h; `ReadInputs` P2 path |
| 3 | shift-register result | |

The host drives the raw port bytes; the board forces the documented
constant bits (port 1 bit3, port 0 bits1–3) to 1. Port 0's bit-7 demux
quirk is not modelled (game code never reads port 0).

### Output ports (write)

| Port | Function |
|---|---|
| 2 | bits2–0 shift offset |
| 3 | sound: bit0 UFO loop, bit1 shot, bit2 flash/player die, bit3 invader die, bit4 extended play, bit5 amp enable |
| 4 | shift data |
| 5 | bits3–0 fleet-movement notes 1–4, bit4 UFO hit, bit5 cocktail flip |
| 6 | watchdog feed (read or write both feed) |

Sound port writes latch to the host as events; the browser maps bits to
short WebAudio tones (functional, not the discrete analog circuit). The
cocktail-flip VRAM address remap is not modelled — this reconstruction is
the upright cabinet (game code only sets the bit in 2-player cocktail
mode). The watchdog counts frames since the last port-6 access; 256 unfed
frames (~4.3 s — the ROM's `TwoSecDelay` splash routine runs ~120 frames
without any feed, so the window must exceed the longest un-fed stretch)
reset the CPU, as the hardware does. Emulation stalls
(host pause) also freeze the frame counter, so pausing never trips the
watchdog.

## Verification and scope

`scripts/run_all.sh` must pass:

1. Strict lint of the board RTL.
2. Board testbench: boot the original ROM through reset, the RAM/ROM check
   and into the attract loop; verify both interrupt vectors execute their
   ISRs (0008h/0010h reached); verify the shift-register sequence from the
   hardware page (00h→AAh→FFh offsets 0..7); verify an input bit reaches
   the credit logic (coin inserts a credit in work RAM).
3. Real-software regression (`scripts/test_software.py`): the original ROM
   boots to attract mode; VRAM then contains the attract-mode screen; a
   coin + 1P start begins a game; firing scores appear in VRAM (score is
   drawn in VRAM as ASCII text); the watchdog is fed throughout.
4. Independent-oracle comparison (`scripts/oracle_board.c`): a C model of
   this board driven by the external superzazu 8080 emulator (the same
   immutable third-party oracle the intel_8080 design uses) runs the same
   ROM; the regression compares full VRAM plus CPU state at checkpoints.
   The oracle is never derived from this RTL.
5. Backend API test and a Yosys synthesis check (storage blackboxed).

Out of scope: original T-state/pin timing, video-CPU bus contention,
discrete analog sound synthesis, cocktail-cabinet screen flip, coin
payout/counter hardware, and the later Taito/Midway board revisions
(SI Part II, color-era boards with extra sound CPUs).

| Assumption or evidence gap | Independent evidence | Status |
|---|---|---|
| Frame = 33 280 cycles; RST8 at cycle 12 480, RST10 at 29 120 | 60 Hz × 1.9968 MHz; lines 96/224 × 130 cycles/line | Validated by boot + oracle agreement |
| First interrupt after reset is RST 8 | Beam-reset phase is not documented to cycle precision; steady state alternates regardless | Model choice; documented; oracle uses the same rule |
| Port 1 bit3 / port 0 bits1–3 read as 1 | Hardware page | Validated by input regression |
| Watchdog window = 256 frames (~4.3 s) | Schematic RC value not cycle-documented; the attract loop's `TwoSecDelay` runs ~120 frames un-fed, so the window must exceed it; the game feeds many times per frame in play | Model choice; documented; tuned after long-run attract showed periodic resets |
| VRAM bit-to-pixel order within a byte | Fixed empirically at bring-up so attract text reads correctly | Documented after visual check |
| RAM mirror at 4000h–7FFFh | Hardware page "$4000+: RAM mirror" | Implemented; game does not depend on it |
