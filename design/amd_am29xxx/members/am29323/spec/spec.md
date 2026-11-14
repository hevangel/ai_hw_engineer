# Am29323 digital specification

Primary contract: AMD 1985 *Am29300 Family Handbook*, "Am29323 32-Bit
Parallel Multiplier" advanced information (PDF 46–52 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1985_AM29300_Family_Handbook.pdf),
page images inspected; Tables 1–3 and the X/Y input and P output
data-format figures). Supplemental contract: AMD 1988 *Am29C300/29300
Data Book*, "Am29C323 CMOS 32-Bit Parallel Multiplier" preliminary
(PDF 266–289), which supplies the only explicit SHIFT AND ACCUMULATE
definition and the 67-bit overflow layout. SHA256s in
`../references/README.md`.

32 × 32 → 64-bit multiplier array feeding a 67-bit accumulator (lower
64 bits = output window, upper 3 bits = accumulation overflow); dual
32-bit input registers per bus (XA/XB, YA/YB) with feedthrough; a
32-bit temporary output register; an instruction register holding the
seven command bits; byte even-parity checking on X/Y and generation on
P; master/slave checking through HARDERR. All registers clock on CLK
rising edges; enables active low; feedthrough controls active high.

## Command word (through the I register; FTI bypasses it)

| Field | Encoding |
| --- | --- |
| ACC1 ACC0 | 00 PASS, 01 ACCUMULATE, 10 INVALID, 11 SHIFT AND ACCUMULATE |
| RND | round the selected most-significant word |
| TSEL | 0 = low word, 1 = high word (T register input, Table 2) |
| FA | 1 = full 64-bit product, 0 = left-shifted 63-bit product |
| PSEL1 PSEL0 | 00 TEMP register, 01 low word, 10 high word, 11 DISABLE |

## Word slices (from the data-format figures)

With Q the 67-bit slice source (accumulator register, or the raw array
product when FTP = 1): Pi = Q[31:0]; Pi−1 = {Q[30:0], 1'b0} (LSB zero,
per the figure's 2^−63 note); Pi+32 = Q[63:32]; Pi+31 = Q[62:31]. FA=0
presents the product left-shifted by one bit (the boundary between the
words moves up one bit). RND adds the bit just below the selected
high-word slice (Q[31] for FA=1, Q[30] for FA=0) to that slice; the
round-add carry is dropped.

SHIFT AND ACCUMULATE: the accumulator is shifted right 32 bits (the
most-significant 32 bits move to the least-significant 32 bits) with
sign extension from the overflow bit, and the array product is
accumulated (1988 book page 4-9).

Operational modes: TCX/TCY select two's complement or unsigned per
operand; the output is two's complement when either input is TC, else
unsigned. Mixed modes are exact products of the per-operand
interpretations.

## Assumption ledger

- ASSUMPTION: ACC = 10 is documented INVALID; the model holds the
  accumulator (no state change).
- ASSUMPTION: RND semantics ("rounding the most significant product")
  are implemented as adding the bit just below the selected high-word
  slice, applied to both the P-port and T-register high-word
  selections; the datasheet does not state the exact addend.
- ASSUMPTION: FTP bypasses the product register into the output
  multiplexer and the temporary-register capture path (raw array
  product visible at the P mux while FTP = 1); the datasheet says
  "feedthrough control for product register" without specifying the
  mux position.
- ASSUMPTION: the I register holds the seven command bits ACC1, ACC0,
  RND, TSEL, FA, PSEL1, PSEL0; TCX/TCY act directly (mode pins, not
  through I), per the block diagram grouping.
- ASSUMPTION: PARERR masters drive their own input-parity error;
  slaves compare the pin against their computed value. HARDERR reports
  driven-vs-observed mismatch on P, PP and PARERR in both modes (master
  contention, slave comparison). The datasheet describes each output
  having an associated comparator without a pin-level error table.
- The Am29C323 (CMOS, preliminary) documents the same function and
  shares this RTL (member #176); only speed grades and the electrical
  layer differ. Electrical timing is outside the contract.
