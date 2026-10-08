# Apple IIe IOU (341-0266 family: Input/Output Unit, 341-0267) — Functional Specification

## 1. What this design is

A synchronous, single-clock **functional reconstruction** of the Apple IIe's
custom **Input/Output Unit (IOU)**, Synertek part number **341-0267**, a
full-custom DIP-40 IC introduced with the Apple IIe in **January 1983**
(same launch as the MMU, 341-0266; see `../README.md` for sourcing). The IOU
contains the video scanner (the counters that walk the display), the display
address generator (the fold that maps scan position to RAM address), the
video-mode soft switches, the keyboard strobe/any-key-down switches, the
annunciator, speaker and cassette-output latches, and the character-set
mode-select gates.

Like the other designs in this repository, this is a **cycle-level behavioral
reconstruction, not a transistor/gate replica**: one `clk` edge corresponds to
one 65C02 clock cycle (one PHI_0 period, ~1.023 MHz), which is also exactly
one horizontal scanner state (one display byte time). Sub-cycle 14M/Q3/PRAS
phase relationships are abstracted; see the assumption ledger (A2).

Primary sources:

- *Apple IIe Technical Reference Manual* (2nd ed., Addisson-Wesley for Apple
  Computer) — OCR text cached at `references/` (repo-local note: the OCR
  layers live in the repo root `references/`): Chapter 2 (soft switches,
  keyboard), Chapter 7 (custom ICs: pinouts Table 7-7, RAM address
  multiplexing Table 7-9, video counters, display address mapping
  Table 7-12/7-13, Figures 7-10/2-8 display maps).
- frozen-signal, *Apple_IIe_MMU_IOU* (CC0-1.0),
  <https://github.com/frozen-signal/Apple_IIe_MMU_IOU> — schematic-derived
  VHDL reimplementation, hardware-validated on real IIe boards. Its unit
  testbenches (`IOU_TB_SCANNER_MUX_TEXT/HIRES`) contain full-frame expected
  address sequences (citing Sather, *Understanding the Apple IIe*, pp. 5-9,
  5-15..5-18) which this spec adopts as behavioral ground truth.
- Jim Sather, *Understanding the Apple IIe* (via the above).

Cross-verification summary (how the numbers below were pinned):

| Item | TRM | frozen-signal | Agreed value |
| --- | --- | --- | --- |
| IOU pin list | Table 7-7 (OCR, reconstructed) | `IOU.vhdl` port list | identical (see §3) |
| Soft-switch address decode | Ch. 2/6 tables | `IOU_ADDR_DECODER` (74LS138 on LA4/LA5/A6, /C0XX, /LA7, Q3) | identical |
| RA0-RA7 bit assignment | Table 7-9 | `MMU_RA`/`VIDEO_ADDR_MUX` | identical |
| Horizontal counter | 65 states, HPE' | `VIDEO_SCANNER` + doc | identical |
| Vertical counter | 262 states, 9 stages | `VIDEO_SCANNER` + doc | identical |
| Display fold (Σ) | Table 7-11 + worked examples | `VIDEO_GENERATOR` (Sather p.5-9) | identical |
| Text address map | Figure 7-10 ("three rows in each block … not adjacent on the display") | `IOU_TB_SCANNER_MUX_TEXT` | identical |
| Hires address map | Figure 2-8 | `IOU_TB_SCANNER_MUX_HIRES` | identical |
| Mode/page bits | Table 7-13 | `VIDEO_ADDR_MUX` (ZA-ZE) | identical |
| C00x/C05x switches | Table 2-10 | `SOFT_SWITCHES_C00X/C05X` | identical (IOUDIS/DHIRES: TRM only, see A5) |
| Keyboard switches | Table 2-2, Ch. 7 | `IOU_KEYBOARD`/`IOU_MD7` | identical |

## 2. System context

On the Apple IIe board, the IOU works alongside the MMU (reconstructed in
`design/apple_iie_mmu`):

- During **PHI_0 = 1** (CPU phase) the **MMU** drives the multiplexed RAM
  address bus RA0-RA7. During the row half of the CPU cycle (PRAS' high, in
  this reconstruction's convention) the bus carries the CPU address as
  `{A8, A7, A5, A4, A3, A2, A1, A0}` (TRM Table 7-9). The IOU **latches** the
  low CPU address bits from that bus — it has no other address inputs except
  the dedicated A6 pin. This is how a 40-pin chip decodes `$C000-$C07F`.
- During **PHI_0 = 0** (video phase) the **IOU** drives RA0-RA7 with the
  display byte address for the current scanner state, using the same
  row/column phase convention and the same per-pin bit assignment as the MMU
  (so the DRAM sees a consistent address in both phases).
- Board glue (74LS138/154/251, NE558, keyboard encoder AY-3600, character
  generator ROM, shift registers) handles everything the IOU has no pins for:
  paddle/button/cassette-in reading (`$C060-$C06F`), the paddle-timer trigger
  (`$C070-$C07F` board decode), keyboard data bits 0-6, and the actual pixel
  serialization.

## 3. Pin-level interface (TRM Table 7-7 / `IOU.vhdl`)

DIP-40 pin map of the real part (reconstruction port names in brackets):

| Pin | Name | Dir | Function |
| --- | --- | --- | --- |
| 1 | GND | — | ground |
| 2 | GR | out | graphics mode enable (1 = graphics region) |
| 3 | SEGA | out | character line select bit 0 (text) / H0 (graphics) |
| 4 | SEGB | out | character line select bit 1 (text) / !HIRES-active (graphics) |
| 5 | VC | out | character line select bit 2 (text) / lo-res nibble select |
| 6 | 80VID' | out | 80-column video enable (inverse of the 80COL switch) |
| 7 | CASSO | out | cassette output (toggles on `$C02x` access) |
| 8 | SPKR | out | speaker output (toggles on `$C03x` access) |
| 9 | MD7 | out (3-state) | IOU flag readback on data bus bit 7 |
| 10-13 | AN0-AN3 | out | annunciator outputs (AN3 doubles as DHIRES, A5) |
| 14 | R/W' | in | 65C02 read/write (1 = read) |
| 15 | RESET' | in/out | reset (see A3) |
| 16 | n.c. | — | not connected |
| 17-24 | RA0-RA7 | in/out | multiplexed RAM address (shared with MMU) |
| 25 | PRAS' | in | row-address strobe (phase select) |
| 26 | PH0 | in | master clock phase (1 = CPU phase) |
| 27 | Q3 | in | timing qualifier (switch selects need Q3 = 0) |
| 28 | VCC | — | power |
| 29 | A6 | in | CPU address bit 6 |
| 30 | C0XX' | in | I/O address enable (`$C000-$C0FF` cycle) |
| 31 | AKD | in/out | any-key-down (raw in from AY-3600, retimed out) |
| 32 | KSTRB | out | keyboard strobe (retimed AY-3600 strobe) |
| 33-34 | VID7, VID6 | in | video data bus bits 7/6 (character code high bits) |
| 35-36 | RA10', RA9' | out | character-ROM mode select bits |
| 37 | CLRGAT' | out | color-burst gate |
| 38 | WNDW' | out | display window (0 = visible) |
| 39 | SYNC' | out | composite sync |
| 40 | H0 | out | horizontal counter bit 0 |

Reconstruction port mapping (deliberate deviations, A8): the bidirectional
RA0-RA7 bus is split into `ra_sense[6:0]` (what the IOU latches during the
CPU row phase) and `ra_o[7:0]` (what the IOU drives during the video phase);
MD7 keeps the repo's `md7_oe`/`md7` pair instead of a tri-state net; the
raw/retimed AKD pair becomes `iakd`/`akd`. The real latch is transparent
around the PH0 rising edge, so the decode sees the bus directly during the
row phase and the registered value during the column half of the same
cycle — the reconstruction models exactly that (row-phase bypass mux).

## 4. Soft-switch address decode

The IOU sees a CPU `$C0xx` cycle as: `c0xx_n = 0`, the latched low address
`LA0-LA5, LA7` (from the RA bus row phase: `LA0-LA5 = A0-A5`, `LA7 = A7`),
and the dedicated `a6` pin. A 74LS138 (A=LA4, B=LA5, C=A6, G1=!LA7,
G2A'=C0XX', G2B'=Q3) yields the range selects:

| Select | Condition | Ranges | IOU response |
| --- | --- | --- | --- |
| C00X' | A6=0, LA5=0, LA4=0 | `$C000-$C00F` | write: switch latch (§5.1); read: MD7 = keyboard strobe flag |
| C01X' | A6=0, LA5=0, LA4=1 | `$C010-$C01F` | write: keyboard strobe clear (`$C010` data/any); read: `$C010` MD7 = AKD, `$C019-$C01F` MD7 = flags |
| C02X' | A6=0, LA5=1, LA4=0 | `$C020-$C02F` | any access toggles CASSO |
| C03X' | A6=0, LA5=1, LA4=1 | `$C030-$C03F` | any access toggles SPKR |
| C04X' | A6=1, LA5=0, LA4=0 | `$C040-$C04F` | none (game-port STROBE is board decode, A7) |
| C05X' | A6=1, LA5=0, LA4=1 | `$C050-$C05F` | write: video switches/annunciators (§5.2) |
| C06X' | A6=1, LA5=1, LA4=0 | `$C060-$C06F` | **none** ('138 Y6 unconnected: paddles are board-level) |
| C07X' | A6=1, LA5=1, LA4=1 | `$C070-$C07F` | write `$C07E`/`$C07F`: IOUDIS latch; read `$C07E`/`$C07F`: MD7 (A5) |

All responses additionally require `LA7 = 0` (so `$C080-$C0FF`, the language
card and slot switches, never reach the IOU) and `Q3 = 0` (the '138 enable).
Switch **writes** additionally require `PHI0 = 1` (CPU phase). Reads and
CASSO/SPKR toggles fire on **any** access in range, read or write, mirroring
the 74LS154 decode.

## 5. Soft switches

### 5.1 `$C000-$C00F` — shared 9334 latch (IOU copy)

The IOU holds its own copy of the 8-bit 9334-style latch that the MMU also
implements ("both react the exact same way", frozen-signal `SOFT_SWITCHES_C00X`).
Select = `LA[3:1]`, D = `LA0`, write-enabled on a PHI_0-phase write.
Reset (RESET' low) clears **all eight bits to 0**. Only three bits produce
IOU-observable behavior; the other five (RAMRD/RAMWRT/INTCXROM/ALTZP/SLOTC3)
are consumed by the MMU and are unobservable at IOU pins (their absence is
therefore not modeled):

| Bits | Switch | Write off/on | Read | IOU use |
| --- | --- | --- | --- | --- |
| Q0 | 80STORE (`EN80VID`) | `$C000`/`$C001` | `$C018` (MMU) | video page mapping (§7.4) |
| Q6 | 80COL | `$C00C`/`$C00D` | `$C01F` (MD7) | drives `80VID'` pin |
| Q7 | ALTCHAR (`PAYMAR`) | `$C00E`/`$C00F` | `$C01E` (MD7) | character-set select gates (§7.6) |

Writes to selects 1-5 (`$C002-$C00B`) pulse the real latch but change no IOU
output; the reconstruction ignores them (documented no-op).

### 5.2 `$C050-$C05F` — video mode latch (74LS259 style)

Select = `LA[3:1]`, D = `LA0`, latched on writes:

| Select | Off write | On write | Flag | Reset behavior |
| --- | --- | --- | --- | --- |
| 000 | `$C050` | `$C051` | TEXT (`ITEXT`) | **not cleared by RESET'** |
| 001 | `$C052` | `$C053` | MIXED (`MIX`) | **not cleared by RESET'** |
| 010 | `$C054` | `$C055` | PAGE2 (`PG2`) | cleared by RESET' |
| 011 | `$C056` | `$C057` | HIRES | cleared by RESET' |
| 100-110 | `$C058/$C05A/$C05C` | `$C059/$C05B/$C05D` | AN0/AN1/AN2 | cleared by RESET' |
| 111 | `$C05E` | `$C05F` | AN3 / DHIRES (shared bit) | cleared by RESET' |

IOUDIS (Enhanced IIe, A5): when the IOUDIS latch is **on**, writes to
`$C058-$C05D` are ignored ("disable IOU access for `$C058` to `$C05F`"),
while select 111 stays live as the **DHIRES** switch. When IOUDIS is off,
select 111 acts as AN3. The stored bit is the same latch cell either way.
The ITEXT/MIX power-on values are indeterminate on real silicon (Sather);
the reconstruction clears them to 0 at reset (A4).

### 5.3 `$C07E/$C07F` — IOUDIS latch (A5)

Write `$C07E` = IOUDIS **on**, write `$C07F` = IOUDIS **off** (note: opposite
D polarity from the C05x pattern). Read `$C07E` returns MD7 = **1 when IOUDIS
is off** (TRM: "Read IOUDIS switch (1 = off)"). Read `$C07F` returns
MD7 = DHIRES state (1 = on), readable while IOUDIS is on. Reset clears
IOUDIS to off (A4/A5).

### 5.4 Keyboard switches

- **Strobe flag (KEY)**: set when the retimed keyboard strobe fires
  (§8); cleared by a **read of `$C010`** or a **write to any of
  `$C010-$C01F`** (CLRKEY: `RC01X ∧ LA==0` or `C01X write`). Readable as
  bit 7 (MD7) on **any** read of `$C000-$C00F`. The keyboard data bits 0-6
  themselves are enabled onto the bus by the MMU's KBD' / the board ROM, not
  by the IOU (A9).
- **Any-key-down (AKD)**: level from the AY-3600, retimed through two
  register stages and driven back out the AKD pin; readable as MD7 on a read
  of `$C010` (TRM Table 2-2: "Any-key-down flag and clear-strobe switch").

### 5.5 Speaker and cassette output

Any access (read or write) in `$C030-$C03F` toggles SPKR; any access in
`$C020-$C02F` toggles CASSO. Both clear to 0 on reset. One toggle per access
cycle.

## 6. Video scanner

A 21-bit binary counter (`cnt`), incremented on every `clk` rising edge:

- `cnt[6:0]` = horizontal field: `H0..H5` = `cnt[5:0]`, `HPE'` = `cnt[6]`.
- `cnt[15:7]` = vertical field: `VA,VB,VC` = `cnt[7],cnt[8],cnt[9]`,
  `V0..V5` = `cnt[10]..cnt[15]`.
- `cnt[20:16]`: `FLASH` = `cnt[20]`, `PAKST` = `cnt[17]`, rest unused here.

**Horizontal**: while `HPE' = 0` the next edge loads `cnt[6:0] = 64`
(H0-H5 = 0, HPE' = 1); otherwise the counter increments. The line is
therefore 65 states: H0-H5 count 0..63 with HPE' = 1, then one state with
HPE' = 0 and H0-H5 = 0 (the "extra count", TRM §Video Counters). The 40
visible byte positions are H = 24..63; H = 0..23 plus the HPE' state are
horizontally blanked.

**Vertical**: when `cnt[15:0] = 16'hFFFF` (TC), the next edge increments
through the carry and then forces the vertical load values (NTSC):
`V5..V0 = 011111` (`V0..V4 = 1`, `V5 = 0`), `VC = 0`, `VB = 1`; VA falls
through the carry to 0. The steady-state frame is therefore **262 lines**,
with the vertical field running 250..511 and the display line index
`L = field - 256` for field 256..511 (the frame's first six lines are field
250..255 = L 256..261). After power-on reset the counter starts from 0 and
the **first frame is 512 lines** until the first TC (A6).

**Windows** (combinational, cycle-aligned in this reconstruction, A2):

- `HBL = !((H3 & H4) | H5)` — 1 during H = 0..23 and the HPE' state.
- Visible vertical window: `(V3 & V4) = 0`, i.e. field 256..447 = L 0..191.
- `BL' = !((V3 & V4) | HBL)` — 1 whenever the display window is open.
  `WNDW'` pin = `!BL'` (0 = visible window).
- `VBL'` (internal, for MD7) = `!(V3 & V4)` — 1 outside vertical blank.
- `SYNC' = !((HBL & !H2 & H3) | (V1 & V2 & VBL' & !V0 & !VC & SERR'))`
  with `SERR' = !(H3 | H4 | H5)` — horizontal sync during H = 8..11;
  the vertical terms generate the NTSC serrated vertical sync in the
  field[7:6] = 11 blank region (gate equations per frozen-signal
  `IOU_INTERNALS`, NTSC branch).
- `CLRGAT' = !(H2 & H3 & HBL & !GR)` — color burst gate during H = 12..15
  of blanked lines, suppressed in text mode.

`H0` pin = `H0`. `PAKST` = `cnt[17]` (auto-repeat key strobe rate),
`TC14S` = 1 when `cnt[19:0] = 0xFFFFF` (quarter-second-class tick, A2),
delayed one cycle into `CTC14S` for the auto-repeat counter.

## 7. Display address generation (video phase)

### 7.1 Registers and mode signals

`GR` (graphics region flag) is registered each cycle:
`GR <= !((MIX & V2 & V4) | ITEXT)` where `V2`, `V4` are the **pre-edge**
scanner bits (`cnt[12]`, `cnt[14]`). `GR = 1` outside the text region:
all of the screen in full-graphics modes, the top 20 screen lines in mixed
mode (`V2 & V4` = 1 for L in 160..191 and 224..255), nothing in text mode.
The address logic and SEGA/SEGB mux use the registered GR (one-state skew at
mode boundaries is real hardware behavior; see A2 note on GR/GR+1/GR+2).

`HIRES'` (hires active) = `!(GR & HIRES)` — 0 only when a graphics region
coincides with the HIRES switch on.

`VID_PG2'` = `!PG2 | 80STORE` — the video page-2 select gated by 80STORE.

### 7.2 The Σ fold (Sather p.5-9)

```
        1
  H5'  H5'  H4  H3
+ V4   V3   V4   V3
-----------------
  E3   E2   E1  E0        (4-bit sum; carry out discarded)
```

i.e. `Σ = (1 + 12·!H5 + 2·H4 + H3 + 5·V3 + 10·V4) mod 16`, where `V3`, `V4`
are scanner bits `cnt[13]`, `cnt[14]`. For visible lines `V3V4` encodes
`(L div 64) mod 4`, so Σ contributes `5·(L div 64)` to address bits 6:3.
The carry-out is never generated inside the visible window (max 14) and is
deliberately discarded in blanked regions (TRM: "the carry bit generated with
the sum is not used").

### 7.3 RA bit assignment (TRM Table 7-9, video half)

The logical display address `A15..A0` is defined by the DRAM pin mapping
(identical to the MMU's CPU-side mapping). During the video phase the IOU
drives, per PRAS' phase:

- PRAS' = 1 (row half): `RA0..RA7 = A0, A1, A2, A3, A4, A5, A7, A8`
  = `{V1, V0, E2, E1, E0, H2, H1, H0}`
- PRAS' = 0 (column half): `RA0..RA7 = A9, A6, A10, A11, A12, A13, A14, A15`
  = `{V2, E3, ZA, ZB, ZC, ZD, ZE, 0}`

i.e. the logical address is `A0..A2 = H0..H2` (column within byte group),
`A3..A6 = E0..E3` (Σ), `A7..A9 = V0..V2` (scanner group bits),
`A10..A14 = ZA..ZE` (mode/page bits), `A15 = 0`.

### 7.4 Mode-dependent page bits (ZA-ZE, TRM Table 7-13)

| Signal | Hires active (HIRES' = 0) | Text/lo-res (HIRES' = 1) |
| --- | --- | --- |
| ZA → A10 | VA (`cnt[7]`) | `VID_PG2'` (80STORE·PAGE2') |
| ZB → A11 | VB (`cnt[8]`) | `!VID_PG2'` (80STORE'·PAGE2) |
| ZC → A12 | VC (`cnt[9]`) | 0 |
| ZD → A13 | `VID_PG2'` (aux select) | 0 |
| ZE → A14 | `!HIRES' & !VID_PG2'` (hires·PAGE2·80STORE') | 0 |

### 7.5 Resulting display maps (behavioral ground truth)

With `c` = visible column 0..39 (H = 24+c), main page 1, PAGE2/80STORE off:

- **Text and lo-res** (8 scanlines per screen line, screen line `b = L div 8`,
  24 lines): byte offset in the `$400` page =
  `0x80·(b mod 8) + 0x28·(b div 8) + c`.
  Equivalently: rows 0-7 live at `$400+$80k`, rows 8-15 at `$428+$80k`,
  rows 16-23 at `$450+$80k` — the three rows sharing a 128-byte block are
  **not adjacent on the display** (TRM Figure 7-10). Verified against
  frozen-signal `IOU_TB_SCANNER_MUX_TEXT` (rows 0..23 = `$0400, $0480, …,
  $0780, $0428, $04A8, …, $07D0`) and Sather p.5-15..5-18.
- **Hi-res** (40 bytes per scanline, 192 lines): byte offset in the `$2000`
  page = `0x400·(L mod 8) + 0x80·((L div 8) mod 8) + 0x28·(L div 64) + c`:
  consecutive scanlines are 0x400 apart within each group of 8, groups are
  0x80 apart, and every 64 lines adds 0x28. Verified against frozen-signal
  `IOU_TB_SCANNER_MUX_HIRES` (line 0 = `$2000`, line 1 = `$2400`, line 8 =
  `$2080`, line 64 = `$2028`, …) and Sather p.5-15..5-18.
- **Blanked regions** continue the same equations with the counters
  free-running (this scans the low address bits for DRAM refresh); the
  start-of-line (H = 0) address is `base + 0x68` for visible L (cgrp wraps
  to 13..15 during H = 0..23), matching both frozen-signal testbenches'
  `expected_first_hbl_addr` values (e.g. `$2068` for hires line 0).

### 7.6 Character-ROM mode selects (RA9'/RA10')

With `VID6`/`VID7` = character-code bits 6/7 from the video data bus:

- `RA9'  = VID6 & (GR | ALTCHAR | VID7)`
- `RA10' = (VID6 & !ALTCHAR & !FLASH & !GR) | VID7`

(frozen-signal `VIDEO_GENERATOR`, IOU_2 @D-4; FLASH = `cnt[20]`). These feed
the character generator ROM's two mode-select address bits.

### 7.7 Character line selects (SEGA/SEGB/VC pins)

- Text region (GR = 0): `SEGA = VA (L bit 0)`, `SEGB = VB (L bit 1)`,
  `VC = VC (L bit 2)` — the 0..7 line within the character cell.
- Graphics region (GR = 1): `SEGA = H0`, `SEGB = !HIRES'` (low = hi-res,
  high = lo-res per TRM pin description), `VC = VC (L bit 2)` — the lo-res
  nibble select (top/bottom 4 scanlines of the cell).

SEGA/SEGB are combinational muxes of the **current** scanner bits, selected
by the registered GR — so they track the scanline every cycle and follow a
TEXT/MIXED switch write one cycle later (the GR register's skew); VC follows
the scanner combinationally.

## 8. Keyboard subsystem

- `KSTRB` pin = `IKSTRB` delayed through two register stages (raw AY-3600
  key-press strobe in, retimed strobe out; A2 for the delay-width note).
- On each KSTRB rising edge a one-cycle pulse `STRBLE` is produced.
- `SET_DELAY` RS latch: cleared while no key is down (`AKD = 0`), set by
  `STRBLE`.
- 3-bit shift register clocked by `CTC14S`, shifting in `SET_DELAY` while
  the key is down; after three ticks `AUTOREPEAT_DELAY` rises and the
  `AUTOREPEAT_ACTIVE` RS latch sets (cleared by key-up or a new STRBLE).
- `KEYLE = STRBLE | (AKSTB & AUTOREPEAT_ACTIVE)` with
  `AKSTB = PAKST & !PAKST(d)` — the auto-repeat re-strobes at the PAKST rate
  (~cnt bit 17 period) after the ~3×CTC14S delay.
- The KEY flag (§5.4) sets on `KEYLE` and clears on CLRKEY.

## 9. MD7 readback summary

| Read address | MD7 | OE condition |
| --- | --- | --- |
| `$C000-$C00F` | KEY (strobe flag) | always (any C00x read) |
| `$C010` | AKD (retimed) | always |
| `$C011-$C018` | — | **not driven by IOU** (MMU flags) |
| `$C019` | VBL' (1 = not in vertical blank) | always |
| `$C01A` | TEXT | always |
| `$C01B` | MIXED | always |
| `$C01C` | PAGE2 | always |
| `$C01D` | HIRES | always |
| `$C01E` | ALTCHAR | always |
| `$C01F` | 80COL | always |
| `$C07E` | !IOUDIS ("1 = off") | always |
| `$C07F` | DHIRES (AN3 bit) | IOUDIS on |

Bit 7 is the only bit the IOU drives; bits 0-6 come from other sources
(keyboard ROM, floating bus).

## 10. Reset behavior

Synchronous, active-low `rst_n` (RESET' pin, A3). Clears: the scanner
counter to `21'h1F0000` (frozen-signal's deterministic stand-in for the
random LS161 power-up state, A6), PG2/HIRES/AN0-AN3, the full C00x latch
(80STORE/80COL/ALTCHAR = 0), IOUDIS, SPKR/CASSO, the keyboard flag and
auto-repeat state. Does **not** clear ITEXT/MIX on real silicon; the
reconstruction clears them (A4).

## 11. Assumption ledger

Every behavior not explicitly pinned by the primary sources, or deliberately
abstracted, is listed here. `ASSUMPTION:` markers in the RTL reference these.

- **A1 (NTSC only)**: the PAL variant (312-line frame, different vertical
  load values, PAL xor V2 sync terms) is not modeled; the reconstruction is
  the NTSC part (`NTSC = 1`).
- **A2 (sub-cycle abstraction)**: one `clk` = one PHI_0 period = one
  horizontal scanner state. The real 14M-domain structures are abstracted:
  the Q3-gated '138 is modeled as q3 = 0 required at the sampling edge; the
  GR/GR+1/GR+2 delay chain collapses to one registered flag (pins mutually
  consistent per cycle); KSTRB/AKD retiming = 2 clk stages (pulse width
  differs from the real ~2×14M window; set/clear flow identical); the MD7
  TIMING_ENABLE window ("last three 14M of PHI_0 + first of PHI_1") is not
  modeled — MD7 is valid for the whole read cycle; the 9334/LS259
  level-sensitive latches are edge-sampled at the clk edge; WNDW'/SYNC'/
  CLRGAT' are combinational scanner functions (the real chip registers them
  intra-cycle for glitch immunity); switch writes land at the clk edge and
  are visible from the next cycle.
- **A3 (RESET' pin)**: modeled as a plain active-low input. The real IOU's
  power-on circuit drives RESET' low until the first scanner TC
  (`IOU_RESET`); that board-level drive and POC detection are not modeled
  (`rst_n` stands in for POC).
- **A4 (power-on values)**: ITEXT/MIX are not reset-cleared on real silicon
  (Sather; the '259 CLR pin is tied high on the ][ ancestor) — reconstruction
  clears them to 0. IOUDIS/DHIRES power-on state is not documented in the
  sources found; reconstruction clears to IOUDIS off.
- **A5 (IOUDIS/DHIRES single-source)**: implemented from the IIe TRM (2nd
  ed.) alone — the CC0 reference implementation predates these Enhanced-IIe
  switches and does not model them. TRM-pinned behavior: write C07E on /
  C07F off; C058-C05D writes ignored while on; select 111 = shared
  AN3/DHIRES bit; reads C07E (!IOUDIS) and C07F (DHIRES, while on). DHIRES
  changes no IOU output pin (the double-resolution dot clocking is external
  to the IOU).
- **A6 (scanner reset value)**: `21'h1F0000` per frozen-signal (the real
  LS161s power up randomly; POC clears to 0 and the first frame is 512 lines
  until the first TC). Consequence: the first post-reset frame is 512 lines
  and FLASH/PAKST phases are deterministic stand-ins.
- **A7 (board-level I/O)**: `$C060-$C06F` (paddles/buttons/cassette-in via
  the 74LS251), the NE558 paddle-timer trigger (`$C070-$C07F`, 74LS154
  decode), the game-port STROBE' (`$C040-$C047`) and VBLINT produce **no
  IOU response** — the '138's Y6 is unconnected and the IOU has no pins for
  them; the board ICs handle them (TRM Ch. 7 "Built-in I/O").
- **A8 (RA bus split)**: the bidirectional RA0-RA7 pins are modeled as
  `ra_sense[6:0]` + `ra_o[7:0]`. `ra_o` is a don't-care during PHI_0 = 1;
  consumers sample it during the video phase. Bit 6 of the latched CPU
  address comes from `ra_sense[6]` (the MMU drives A7 there); there is no
  LA6 — A6 arrives on its own pin.
- **A9 (keyboard data path)**: keyboard data bits 0-6 (AY-3600 + 2316
  character-code ROM + KBD'/ENKBD' bus enables) are board/MMU functions. The
  IOU provides only bit 7 (strobe flag, any `$C000-$C00F` read) and AKD
  (`$C010` read). Reads of `$C008-$C00F` return the strobe flag on bit 7
  even though those addresses also host MMU/C00x switches — per the
  frozen-signal decode (RC00X covers the full block); the MMU does not drive
  MD7 there, so no driver conflict exists.
- **A10 (delay line)**: the DELAY_OSCILLATOR / DRAM hold-time delay cell is
  not modeled (the CC0 reference leaves it unwired as well; it only adds
  14M-domain hold time on RA/Q3 edges).

## 12. Out of scope

Pixel serialization (character generator ROM contents, shift registers, NTSC
color generation), the PAL variant, power-on reset generation, paddle analog
timing, and cassette read electronics. The design terminates at the pin
contract of §3; a future `system/apple_iie` build wires it to the MMU, the
6502 and board models.
