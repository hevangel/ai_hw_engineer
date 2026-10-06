# Apple IIe MMU formal plan

Properties live in `formal/apple_iie_mmu_props.sv` and `formal/apple_iie_mmu_cover_setup.sv`, included inside the RTL under `` `ifdef FORMAL ``/`` `ifdef FORMAL_COVER ``. Immediate assertions in clocked blocks only (no SVA `assert property`; no labels inside loops; `$past` only in clocked blocks).

## State assumptions

- Reset assumed for the first cycle; no other environmental assumptions (all inputs free).
- `anyconst` on the watched address and on a watched switch value where pairwise checks need symmetry.

## Property classes

1. **Array mutual exclusion**: never (`ramen_n` low) and (`en80_n` low) simultaneously.
2. **No RAM in the I/O page**: any $C000-$CFFF address yields both array selects high.
3. **Mapping agreement**: for an anyconst address, the selected array (main/aux/neither) and ROM-enable pattern match the spec priority list restated independently in the properties file (80STORE/PAGE2/HIRES override, ALTZP for $0000-$01FF and $D000-$FFFF, RAMRD/RAMWRT otherwise, ROM reads when read-RAM is off, write-protected LC writes suppressed).
4. **Switch readback**: reads of $C011-$C018 drive MD7 with the registered flag values and `md7_oe`; no other address drives it; KBD' low exactly on $C000-$C01F reads.
5. **Prewrite state machine**: even $C08x access clears write-enable and the odd-read flag; odd read sets the flag; write-enable rises only on the flagged odd access; reset state is bank 2, read ROM, write enabled.
6. **Interleave**: inside $D000-$DFFF the column RA4 equals `a[12] ^ bank1`; outside, `a[12]`; RA equals the row pattern while `pras_n` is high and the column pattern while low.
7. **C800 window**: opens only on internal-$C3 access, closes on $CFFF and reset; CXXXOUT/ROMEN1 agree with the window.
8. **MPON**: three $01xx accesses then $FFFC assert MPON for exactly that cycle, apply the reset state, and hold both RAM selects off.

## Non-vacuity

Cover mode must reach every property class above; a cover that cannot fire means the property (or the RTL) is wrong, not that the proof is vacuous.
