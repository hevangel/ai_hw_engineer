# Am29434 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29434 ECL
Four-Port, Dual-Access Register File", **preliminary**, Issue 08554A
(September 1986), PDF 216–229 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf).

The ECL member of the Am29400 family: 64 words × 18 bits, two read ports
and two write ports with per-byte write enables, transparent output
latches and the same on-chip read/write address multiplexer as the
bipolar Am29334. The 1988 book documents the identical block diagram,
pin functions and functional description; the documented deltas are the
ECL I/O layer (VEE/VCCO supplies, ECL output levels), the 20 ns access
time (versus 24 ns) and its pairing with the Am29432 ECL ALU.

## Implementation contract

Per the series rules for ECL variants, this member shares the
[bipolar Am29334 RTL](../am29334/src/amd_am29334.sv) and its full
verification suite; no RTL is duplicated. The shared suite is re-run
under this member's issue as its own qualification evidence.

## Assumption ledger

- ASSUMPTION: the ECL datasheet is **preliminary**; its functional
  description matches the final bipolar Am29334 datasheet text on every
  documented point, so shared RTL is justified. Any future final ECL
  datasheet that changes the functional contract reopens this member.
- The ECL electrical layer (levels, VEE, termination, 20 ns timing) is
  outside the digital contract, as with all members of this series.
