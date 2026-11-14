# Am29337 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29337 16-Bit
Bounds Checker" (Issue 08548B, June 1987, PDF 231–241 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)),
Tables 1/2 and Figure 1, page images inspected.

Two 16-bit limit registers (lower L, upper U) loaded from the D bus on
CP rising edges (ENL/ENU active low); two comparators qualify D against
the limits, signed when SIGNED is high and unsigned when low.

## Carry semantics (Table 1)

CIL/CIU carry the "equal so far" qualification from lower slices:

| CIL | CIU | COL | COU |
| --- | --- | --- | --- |
| 0 | 0 | L < D | D < U |
| 0 | 1 | L < D | D ≤ U |
| 1 | 0 | L ≤ D | D < U |
| 1 | 1 | L ≤ D | D ≤ U |

## Regions (Table 2)

OOB is out-of-bounds unless both COL and COU are high (L < D < U with
the carry qualification): COL=0/COU=0 is an impossible combination and
flags OOB, COL=0/COU=1 is D ≤ L, COL=1/COU=0 is U ≤ D.

Cascading (Figure 1): low slices run with SIGNED tied low (magnitude
compare) and their COL/COU feed the next slice's CIL/CIU; the
most-significant slice's SIGNED decides the signed interpretation and
its COL/COU/OOB are the overall outputs.

## Assumption ledger

- ASSUMPTION: the prose defines OOB as "COL' · COU", which contradicts
  Table 2's four region rows; Table 2 (visually confirmed) governs:
  OOB = ¬(COL · COU). Both agree on the in-bounds region.
- ASSUMPTION: ENL/ENU are active-low load enables (overbarred in the
  figure; the prose does not state the level).
- ASSUMPTION: signed 32-bit cascade relies on the low slices comparing
  magnitudes with "equal so far" carries; the MS slice's SIGNED input
  qualifies its own 16-bit compare. Verified only per-slice here; the
  board-level cascade wiring is Figure 1, not device behavior.
- Electrical timing is outside the contract.
