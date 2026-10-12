# Implementation Plan — Apple IIe timing PAL

## Module

Single file `src/apple_iie_pal.sv`, one module `apple_iie_pal`. SV-2017,
synchronous active-low `rst_n`. The clock is the 14M oscillator (`clk14`);
one edge = one tick (spec 4).

## Structure

- `tick_q[3:0]` 14-state counter; `run = rst_n && entmg_n`.
- Combinational decode functions of `tick_nxt` (the state being entered):
  `d_phi0`, `d_q3`, `d_prasn`, `d_pcasn` (+ sticky `cas_gated` sample),
  `d_ldpsn`.
- One `always_ff` commits the decode into the registered macrocells
  `r_*` and holds the idle pattern while `!run` (spec 4.4, A6).
- `m358/h0/vid7/segb/gr` are connected inputs unused by the equations
  (A5/A6); `ramen_n` gates PCAS' (spec 4.2); `s80vid_n` selects the LDPS'
  cadence (spec 4.3).

## Conventions

- `` `ifdef FORMAL `` includes `apple_iie_pal_props.sv` and the covers under
  `` `ifdef FORMAL_COVER `` at the end of the module.
- No SVA, no tri-state, no `initial` in RTL; lint clean with no waivers.
