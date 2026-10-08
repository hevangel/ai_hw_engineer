# Formal Plan — Apple IIe IOU

Immediate asserts in clocked blocks inside `formal/apple_iie_mmu`-style
props included at the end of the RTL under `` `ifdef FORMAL ``; covers in a
second include under `` `ifdef FORMAL_COVER ``. No SVA. One `.sby` with
tasks: `bmc` (abc bmc3, depth 32), `prove` (abc pdr, unbounded),
`cover` (smtbmc z3).

## Reachability strategy

A full frame is 262·65 = 17030 cycles — no bmc/prove depth walks a frame.
Therefore the formal harness makes the scanner reset value an
`(* anyconst *)` (`cnt_init`, spec §11/A6 hook): properties are checked
around an arbitrary starting state, and the counter's own update rules are
proven separately as local state transitions. Covers likewise pick
`cnt_init` freely, so window covers are satisfiable without long traces.
Mode switches evolve freely (unconstrained writes are not needed: the
latches are ordinary state bits).

## Property groups (apple_iie_iou_props.sv)

1. **Counter structure** (local transitions):
   - `!hpe_n` → next `cnt[6:0]==7'd64` and `cnt[20:7]` unchanged.
   - `hpe_n && !tc` → next `cnt == cnt+1`.
   - `hpe_n && tc` → next `cnt[6:0]==0`, `cnt[7]==0`, `cnt[15:8]=={V5..VB}`
     load pattern (`cnt[15]=0, cnt[14:10]=5'b11111, cnt[9]=0, cnt[8]=1`).
   - `hpe_n` low exactly 1 cycle: `!hpe_n |-> ##1 hpe_n` (immediate form).
   - TC implies `cnt[15:0]==16'hFFFF`; the pulse is qualified by the
     increment path only (never fires during the reload state).
2. **Display address function** (the core): with `(* anyconst *)` watcher
   state, at every cycle, for the current registered mode latches:
   - `ra_o == row_byte` when `pras_n==1`, `ra_o == col_byte` when
     `pras_n==0` (pure function asserts against independently written
     functions `f_row`/`f_col` implementing spec §7.3/§7.4).
   - Restricted visible-window corollaries: when the window is open and the
     line is in 0..191, the composed 16-bit logical address equals
     `base + 0x80*(b mod 8) + 0x28*(b div 8) + c` (text/lores) or
     `base + 0x400*(L mod 8) + 0x80*((L div 8) mod 8) + 0x28*(L div 64) + c`
     (hires), with page bits per Table 7-13 — written as independent
     functions of `cnt`, the mode latches and the row/col phase.
   - Row stability of text/lores: across the 8 states of a band the
     address bits A15..A3 are constant (guarded by band-internal
     conditions on the counter).
3. **Windows/timing pins**: `wndw_n == !(!((v3&v4)|hbl))`; `hbl` truth
   table over H; `vbl_n == !(v3&v4)`; `sync_n`/`clrgat_n` gate equations;
   `h0 == cnt[0]`.
4. **Mode flag**: `gr_q == !((mix & preV2 & preV4) | itext)` (the pre-edge
   V2/V4 sampled with `$past`-equivalent registered shadow); SEGA/SEGB mux
   equals the spec table given `gr_q`; `vc == cnt[9]` (registered).
5. **Switch decode**: for any `la/a6/c0xx/q3/rw` combination: a write lands
   exactly one latch iff the spec §4 table says so (IOUDIS gating of AN0-2,
   select-111 always live); a read drives MD7 exactly for the §9 table
   (C00x → KEY, C010 → AKD, C019-C01F → flags, C07E/C07F per A5);
   `$C080-$C0FF` (la7=1) and `q3=1` produce no state change and no MD7 OE;
   C04x/C06x are no-ops.
6. **Keyboard**: KEY set only on keyle, cleared only on the CLRKEY decode,
   hold otherwise; KSTRB/AKD are 2-stage delayed inputs; SET_DELAY/N9/
   AUTOREPEAT transitions per spec §8; SPKR/CASSO toggle exactly on their
   range selects.

## Covers (apple_iie_iou_cover_setup.sv, ~25)

Each display mode × page combination observed with a valid visible-window
address; text rows 0/7/8/15/16/23 corners; hires lines 0/1/7/8/63/64/127/
191 corners; start-of-line HBL address (`+0x68`); blanked free-run; HPE
reload observed; TC pulse observed; VBL window entered/exited; SYNC
horizontal pulse and vertical serration region; CLRGAT burst window in
graphics; every MD7 readback source; KEY set/clear; auto-repeat local pieces
(delay armed, CTC14S tick — the full 3-tick activation is
simulation-verified only, being 3·2^20 cycles deep);
SPKR and CASSO toggles; IOUDIS gating blocking an AN write;
AN3/DHIRES shared-bit write under both IOUDIS polarities; reset clearing
PG2/HIRES/AN but the ITEXT/MIX retention difference.

## Non-vacuity

`cover` task must reach every cover; the bmc/prove tasks are also guarded
by the anyconst-init trick so assertions are exercised across the whole
counter space, not only the reset neighborhood. Proof obligations are all
local (state transition or pure function), so `prove` (pdr) is expected to
close unbounded.
