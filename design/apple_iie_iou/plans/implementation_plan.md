# Implementation Plan — Apple IIe IOU

## Module

Single file `src/apple_iie_iou.sv`, one module `apple_iie_iou`, no package
(there is only one module and the interface is pin-faithful). Plain SV-2017,
`logic`/`always_ff`/`always_comb`, synchronous active-low `rst_n`.

## Ports

Per spec §3 with the A8 RA-bus split:

```
clk, rst_n
phi0, q3, pras_n, rw, c0xx_n, a6      // CPU-side cycle inputs
vid6, vid7                            // video data bus bits
ikstrb, iakd                          // raw keyboard strobe / any-key-down
ra_sense[6:0]                         // RA bus during CPU row phase (A8)
ra_o[7:0]                             // IOU video RA byte (video phase)
h0, sega, segb, vc, gr                // video pins
wndw_n, sync_n, clrgat_n              // video timing pins
ra9_n, ra10_n, s80vid_n               // char-ROM select / 80-col enable
spkr, casso, an0..an3                 // misc outputs
kstrb, akd                            // retimed keyboard signals
md7_oe, md7                           // flag readback (repo convention)
```

## Internal structure (single module, subsections in order)

1. **Scanner counter** `cnt[20:0]`: per spec §6. Formal-only `(* anyconst *)`
   `cnt_init` feeds the reset value under `` `ifdef FORMAL `` so properties
   can start the scanner at any state (the frame is 17k cycles; bmc depth
   cannot walk there from reset).
2. **Window/flag functions** (always_comb): hbl, bl_n, vbl_n, psync, pclrgat,
   pakst, tc, tc14s, flash, sum4 (the Σ fold), hiresen_n, vid_pg2_n,
   za..ze, row_byte, col_byte.
3. **CPU address latch** `la0..la5, la7`: sampled from `ra_sense` when
   `phi0 && pras_n` (A8: LA7 from `ra_sense[6]`, no LA6).
4. **Range selects** (always_comb): the 74LS138 equation set from spec §4,
   gated by `!c0xx_n && !la7 && !q3`.
5. **Soft-switch state**: `en80vid, s80col, paymar` (C00x); `itext, mix, pg2,
   hires, an0..an3` (C05x, IOUDIS-gated for AN0-2); `ioudis` (C07E/F).
   One always_ff with the decode; reset clears all but itext/mix keep the
   documented reset difference (itext/mix also cleared, A4).
6. **Keyboard**: `kstrb_sh[1:0]`, `akd_sh[1:0]` (2-stage retiming), strble
   pulse, set_delay RS, n9[2:0] shift on ctc14s, auto_active RS, keyle, key
   flag, clrkey decode.
7. **Device toggles**: spkr_q, casso_q.
8. **Registered video flags**: `gr_q` (from pre-edge V2/V4 — read the
   pre-edge `cnt` bits inside the same always_ff), then SEGA/SEGB mux and
   hiresen/ZA-ZE all key off `gr_q` (A2 unification).
9. **Output assigns**: comb window pins (wndw_n/sync_n/clrgat_n from the
   comb functions — A2), ra_o mux, md7_oe/md7 mux, ra9_n/ra10_n gates,
   s80vid_n.

## Conventions honored

- `` `ifdef FORMAL `` includes `formal/apple_iie_iou_props.sv` (immediate
  asserts) and `formal/apple_iie_iou_cover_setup.sv` under
  `` `ifdef FORMAL_COVER `` at the end of the module.
- No SVA; no `initial` in RTL except the formal anyconst declarations;
  no tri-state nets (md7_oe convention, ra split).
- No lint waivers in RTL; the TB carries the usual BLKSEQ/PROCASSINIT/
  UNUSEDSIGNAL waivers only.

## Verification hooks

- `(* anyconst *) logic [20:0] cnt_init;` used as the reset value under
  `` `ifdef FORMAL `` — lets bmc/cover check the address function and window
  logic at arbitrary scanner states without walking 17k cycles.
- White-box signals (la, switch latches, key flag) are readable by the TB
  through hierarchical references (same style as the MMU bench).
