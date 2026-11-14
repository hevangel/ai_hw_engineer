# Am29C323 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29C323 CMOS
32-Bit Parallel Multiplier" **preliminary** (PDF 266–289 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)).

The CMOS member of the Am29300 multiplier: 32 × 32 array, 67-bit
accumulator with PASS/ACCUMULATE/SHIFT AND ACCUMULATE, dual input
registers, temporary and instruction registers, format adjust,
rounding, byte parity and master/slave checking — the same documented
function as the bipolar [Am29323](../am29323/spec/spec.md), whose
datasheet supplies the Table 1–3 encodings and data-format figures the
preliminary CMOS text reproduces.

Per the series rules this member shares the bipolar
[Am29323 RTL](../am29323/src/amd_am29323.sv) and its full verification
suite; no RTL is duplicated. The suite is re-run under this member's
issue as its own qualification evidence.

## Assumption ledger

- ASSUMPTION: the CMOS datasheet is preliminary; its functional
  description matches the 1985 bipolar text on every documented point
  (the CMOS book additionally states the SHIFT AND ACCUMULATE semantics
  explicitly). A final CMOS datasheet that changes the functional
  contract reopens this member.
- CMOS electrical characteristics and the 80/55 ns speed grades are
  outside the digital contract.
