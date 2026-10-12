# Formal Plan — Apple IIe timing PAL

The design is a 14-state counter with pure decode — fully reachable within
bmc depth, so no anyconst tricks are needed. One `.sby`, tasks bmc
(abc bmc3, depth 32) / prove (abc pdr, unbounded) / cover (smtbmc z3).

## Property groups (apple_iie_pal_props.sv)

1. Counter transition: `tick_q+1 mod 14` from the shadowed pre-edge value.
2. Output decode equality with independently written comparisons: φ0
   (`tick < 7`), φ1 complement, Q3 via an explicit subtract-based mod-7
   (`f_t7`), PRAS' (`tick < 4`).
3. Q3 edge anchors: falls exactly at ticks 4 and 11, rises at 7 and 0
   (the Table 7-5 / Figure 7-1 280/210 ns split).
4. PRAS'/Q3 coincidence at tick 4 (the row→column transition convention
   shared with the MMU/IOU designs).
5. PCAS': window membership (high 0-5 and 13, gated value 6-12), the
   RAMEN' sample committing entering tick 5 (A7), gated cycles never
   assert CAS.
6. LDPS' windows (13 always; 6 only when `s80vid_n = 0`).
7. VID7M ≡ 7M delayed one tick, guarded on two enabled edges (A5).
8. Hold pattern under `!run` (spec 4.4, A6).

## Covers (apple_iie_pal_cover_setup.sv, ~20)

Phase corners (ticks 0/6/7/13), Q3 falls/rises, PRAS'-Q3 coincidence,
PCAS' fall on a RAM cycle, gated cycle holding CAS through the window,
both LDPS' cadences (and the 40-column tick-6 absence), VID7M tracking 7M
both directions, ENTMG hold entered, tick 6 in both cadence modes.
