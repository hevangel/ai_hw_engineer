# Apple IIe PAL (PAL16R8 timing generator) — Functional Specification

## 1. What this design is

A synchronous **functional reconstruction** of the Apple IIe's motherboard
timing PAL — a PAL16R8 programmable-array-logic device programmed by Apple,
introduced with the Apple IIe in **January 1983** (same launch as the MMU
341-0266 and IOU 341-0267). The PAL is the 14M-domain device that turns the
14.31818 MHz master oscillator into every other timing signal on the board:
the CPU clocks (φ0/φ1), the Q3 strobe, the DRAM row/column strobes
(PRAS'/PCAS'), and the video shift-register controls (LDPS', VID7M).

Unlike the MMU and IOU designs — which were reconstructed at the CPU-cycle
level — this design is reconstructed at the **14M-tick level**: one `clk`
edge = one 14M period (~69.84 ns), because the PAL's outputs live in that
domain and their relationships (7-tick Q3 period, 14-tick CPU cycle) are the
whole point of the chip.

Primary sources:

- *Apple IIe Technical Reference Manual* (2nd ed., © Apple 1985; OCR text
  cached at the repo-root `references/`):
  - **Table 7-8 (PAL pinouts/signal descriptions)** — the complete pinout
    reproduced in §3 below.
  - **Table 7-5 (65C02 timing signals)** — "Q3: intermediate timing signal,
    2.045 MHz with asymmetrical duty cycle"; "VID7M: intermediate timing
    signal and 40-column dot clock"; φ0/φ1 at 1.0227 MHz.
  - **Figure 7-1 (65C02 timing)** — the CPU-phase segment decomposition
    280 ns + 210 ns = 490 ns, which pins the Q3 high/low split at
    4/3 ticks of 14M.
  - **Chapter 2 / Chapter 7 text** — "LDPS' strobes the output of the
    character generator ROM into the shift register once each microsecond"
    (40-column); "in 80-column mode, LDPS' loads data ... twice during each
    microsecond, once during φ0 and once during φ1".
  - **Table 7-10 / "Dynamic-RAM Timing"** — Q3 described as "alternate
    RAM/column-address strobe"; CPU data strobed by φ0 falling, display data
    by φ1 falling.
- Jim Sather, *Understanding the Apple IIe* — the statement (p. 5-6 area)
  that "the SEGB, gated GR', VID7, and 80COL' inputs to the PAL are used
  only in generation of LDPS' and VID7M". **The PAL's fuse-level
  sum-of-products equations are not available in a citable public source**
  (Sather's book is under copyright; the CC0 frozen-signal project covers
  only the MMU/IOU), so LDPS'/VID7M are reconstructed at *cadence level
  only* — see assumptions A4/A5.

Cross-verification summary:

| Item | Source | Value used |
| --- | --- | --- |
| Pinout | TRM Table 7-8 | §3, complete |
| φ0/φ1 frequency | TRM Table 7-5 | 1.0227 MHz = 14 ticks of 14M |
| Q3 frequency/duty | TRM Table 7-5 + Figure 7-1 | 2.045 MHz = 7-tick period, 4 high / 3 low (280/210 ns) |
| Q3 role | TRM Table 7-10 | "alternate RAM/column-address strobe" |
| PRAS'/PCAS' roles | TRM Table 7-8 | RAM row/column-address strobes |
| RAMEN' role | TRM Table 7-8 | "RAM enable (CAS enable)" — gates the CAS output |
| LDPS' cadence | TRM ch. 2/ch. 7 | 1 pulse/cycle (40-col); 2 pulses/cycle, one per clock phase (80-col) |
| VID7M role | TRM Tables 7-5/7-8 | 40-column dot clock (7 MHz rate) |

## 2. System context

On the IIe board the PAL sits between the 14M oscillator and everything
else. The motherboard derives 7M (÷2) and 3.58M (÷4) from 14M before the
PAL (both are PAL *inputs*); the PAL generates the CPU clocks and strobes as
registered outputs clocked on 14M. The MMU (341-0266) consumes φ0, Q3 and
PRAS' to multiplex the CPU DRAM address; the IOU (341-0267) consumes φ0/Q3/
PRAS' to drive the video-phase address, and its soft-switch decoder is
gated by Q3 (Q3 high = no switch select). RAMEN' comes from the MMU's CASEN'
circuit path: when the cycle is not a RAM cycle (ROM read, I/O page,
suppressed write), CAS must not fall — that is the "CAS enable" gating the
PCAS' output. The video chain (74LS166 shift register) is loaded by LDPS'
and shifted at the VID7M rate.

Designs on this repository that interoperate with this one:
`design/apple_iie_mmu`, `design/apple_iie_iou`.

## 3. Pin-level interface (TRM Table 7-8)

| Pin | Name | Dir | Function |
| --- | --- | --- | --- |
| 1 | 14M | in (clock) | 14.31818 MHz master oscillator |
| 2 | 7M | in | 7.15909 MHz timing signal (÷2 of 14M, made on the board) |
| 3 | 3.58M | in | 3.579545 MHz timing signal (÷4 of 14M, color reference) |
| 4 | H0 | in | IOU horizontal counter bit 0 |
| 5 | VID7 | in | video data bus bit 7 |
| 6 | SEGB | in | IOU video timing signal |
| 7 | GR | in | IOU graphics-mode enable |
| 8 | RAMEN' | in | RAM enable (CAS enable), from the MMU decode |
| 9 | 80VID' | in | 80-column video enable (IOU 80COL switch) |
| 10 | GND | — | ground |
| 11 | ENTMG | in | enable master timing (power-on/reset gating, A6) |
| 12 | LDPS' | out | video shift-register load enable |
| 13 | VID7M | out | video dot clock (7 MHz rate; "7 or 14 MHz" with board logic, A5) |
| 14 | φ1 | out | phase 1 system clock (display phase) |
| 15 | φ0 | out | phase 0 system clock (CPU phase) |
| 16 | Q3 | out | intermediate timing and strobe signal |
| 17 | PCAS' | out | RAM column-address strobe |
| 18 | N.C. | — | not used |
| 19 | PRAS' | out | RAM row-address strobe |
| 20 | +5V | — | power |

Reconstruction ports follow this list with one deliberate deviation: the
pins whose only PAL use is inside the unreconstructed LDPS'/VID7M gating —
3.58M (pin 3), H0 (pin 4), VID7 (pin 5), SEGB (pin 6), GR (pin 7) — are
**not ports** of the reconstruction (same convention as the MMU design's
removed Q3 pin): the equations consume only `m7` (pin 2), `ramen_n`
(pin 8), `s80vid_n` (pin 9) and `entmg_n` (pin 11), and a port that
influences no output would misrepresent the reconstruction's actual
contract (spec 4.3, A5/A6). Outputs: `ldps_n, vid7m, phi1, phi0, q3,
pcas_n, pras_n`. There are no tri-state pins in the reconstruction (A6);
`md7`-style OE conventions do not apply here.

## 4. Tick-level behavior

One CPU cycle = **14 ticks** of 14M (~980 ns ≈ 1.0227 MHz). Tick 0 is the
φ0 rising edge. An internal counter `tick[3:0]` counts 0..13, free-running
while master timing is enabled.

### 4.1 CPU clocks (Table 7-5, Figure 7-1)

- `φ0 = (tick < 7)` — high ticks 0-6 (CPU phase, 490 ns), low ticks 7-13
  (video phase, 490 ns).
- `φ1 = !φ0` (pin 14).
- `Q3 = (tick mod 7) < 4` — period 7 ticks (489 ns ≈ 2.045 MHz), high
  4 ticks (280 ns), low 3 ticks (210 ns), exactly the Figure 7-1 segment
  decomposition. Q3 falls at tick 4 (mid-CPU-phase) and tick 11
  (mid-video-phase).

### 4.2 DRAM strobes (Tables 7-8/7-10)

The row address is set up while PRAS' is high and latched by the PRAS'
falling edge; the column address follows and is latched by PCAS' (CPU
cycles) or by Q3's fall (the "alternate column strobe" role, Table 7-10) —
this is the same convention the MMU and IOU designs already use.

- `PRAS'`: high ticks 0-3 (row-address setup, 280 ns), falls at tick 4 —
  coincident with Q3's fall, matching the "row until Q3 falls" convention
  in the MMU/IOU reconstructions — low ticks 4-13 (698 ns ≥ DRAM tRAS),
  rises at tick 0 of the next cycle (4-tick precharge, 280 ns).
- `PCAS'`: falls at tick 6 (column address stable ≥ 2 ticks ≈ 140 ns after
  the PRAS' fall, ≥ DRAM tASC), low through tick 13 and rises at tick 0
  (CAS-low 8 ticks ≈ 559 ns; CAS-high 6 ticks ≈ 419 ns ≥ DRAM precharge).
- **RAMEN' gating**: when `ramen_n = 1` at tick 5 (the gating sample
  point, A7) the cycle is not a RAM cycle and PCAS' does **not** fall that
  cycle — it stays high for the whole cycle. PRAS' is not gated (RAS runs
  every cycle for refresh; see A3 on the suppression question).

### 4.3 Video controls (TRM ch. 2/ch. 7; A4/A5)

- `LDPS'` (74LS166 load): a 1-tick low pulse. Cadence per the TRM:
  - 40-column (`s80vid_n = 1`): one pulse per cycle, at tick 13 (end of the
    video phase; A4 for the position).
  - 80-column (`s80vid_n = 0`): two pulses per cycle, at ticks 6 and 13 —
    "once during φ0 and once during φ1" (A4 for the positions).
- `VID7M` (dot clock): follows the 7M input delayed by one tick while
  master timing is enabled — the 7 MHz-rate dot clock of Tables 7-5/7-8.
  The PAL's mode-dependent gating of VID7M (and any LDPS' dependence on
  SEGB/GR/VID7 beyond the 80VID' cadence switch) is **not** reconstructed:
  the fuse equations are unavailable (A5). Board-level blanking of the
  video signal is applied downstream (WNDW') and does not need VID7M to be
  gated.

### 4.4 Master-timing enable (A6)

`ENTMG` (pin 11, "enable master timing") is the power-on/reset gate: while
`entmg_n = 0` the counter is held at tick 0 and all registered outputs are
held at their idle values (φ0 = 0, φ1 = 1, Q3 = 0, PRAS' = 1, PCAS' = 1,
LDPS' = 1, VID7M = 0). On the real part pin 11 is the PAL16R8 output-enable
and the outputs go high-Z instead (the board's pull-ups idle them); the
reconstruction uses the synchronous-hold convention (A6).

## 5. Reset behavior

`rst_n` (synchronous, active-low, the repo convention) and `entmg_n` both
force the idle state of §4.4. The distinction is modeling-only: `rst_n`
stands for the simulation's chip reset, `entmg_n` for the board's master-
timing gate (A6).

## 6. Assumption ledger

- **A1 (NTSC only)**: the PAL-IIe (European) variant uses different
  equations; not modeled.
- **A2 (tick alignment)**: tick 0 is defined as the φ0 rising edge. The TRM
  notes φ0 is "a few nanoseconds early" relative to the 65C02 manual's φ2;
  sub-tick skews are not modeled.
- **A3 (PRAS' ungated)**: the reconstruction runs PRAS' every cycle
  (refresh continues through non-RAM CPU cycles; the display scan keeps
  refreshing DRAM per the TRM "Dynamic-RAM Refreshment" section). Whether
  the real PAL also gates PRAS' in some non-RAM cases is not stated by the
  TRM; only the PCAS' gating is pinned by the "CAS enable" description.
- **A4 (LDPS' pulse positions)**: the TRM pins the *cadence* (1×/cycle in
  40-column; 2×/cycle, one per clock phase, in 80-column). The tick
  positions (6 and 13, i.e., the last tick of each clock phase) are a
  reconstruction choice consistent with "the display byte is fetched during
  the phase and latched at its end"; the real pulse positions within the
  phase are Sather p. 5-6 material and are not independently confirmed.
- **A5 (VID7M gating / fuse equations)**: the PAL's mode-dependent gating
  of VID7M and LDPS' (via the SEGB/GR/VID7 inputs — Sather) is not
  reconstructed; the fuse-level equations are not available in a citable
  public source. VID7M is modeled as the 1-tick-delayed 7M dot clock
  (7 MHz rate per Tables 7-5/7-8); the "or 14 MHz" mode of Table 7-8 comes
  from board logic combining VID7M with 14M (TRM Figure 7-1b, "SP1 serial
  output (VID7M and 14M)") and is out of PAL scope. H0/VID7/SEGB/GR are
  connected but unused by the reconstruction's equations (their only PAL
  use is inside the unreconstructed gating).
- **A6 (ENTMG semantics)**: modeled as a synchronous hold at the idle
  pattern; the real pin 11 is the PAL16R8 output enable (outputs high-Z
  while inactive). 3.58M is connected but unused by the reconstruction's
  equations (assumed to feed only the unreconstructed gating/color path).
- **A7 (RAMEN' sample point)**: RAMEN' is sampled at tick 5, one tick
  before the PCAS' fall, abstracting the real combinational gate
  (RAMEN' gates the CAS product term) to the cycle boundary. A change of
  RAMEN' between tick 5 and the fall is therefore not honored.
- **A8 (absolute tick phase vs the board)**: the alignment of tick 0 to the
  master oscillator's phase at power-on is arbitrary; only the *relative*
  phase relationships (φ0/Q3/PRAS'/PCAS'/LDPS') are reconstructed.

## 7. Out of scope

The IIe's oscillator and ÷2/÷4 dividers that produce 14M/7M/3.58M (board
logic before the PAL), the 65C02 clock input shaping, and the video signal
generation after the shift register. The PAL-IIe (European) variant. The
MMU's CASEN' → RAMEN' board path is out of scope; the reconstruction
exposes `ramen_n` as a plain input.
