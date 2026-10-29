# Am2903 native digital specification

Contract: AMD 1978 Am2900 Family Data Book PDF38–59, Tables1–5/PDF39–43,
FigureB/PDF42 and applications/PDF47–59. Tables and complement bars were
visually inspected before RTL. Four-bit slice, 16-word RAM, two read latches,
four-bit Q and one sign-compare flip-flop. No reset pin or initialization.

RAM read latches follow addressed RAM while CP HIGH and hold while LOW.
WE_n LOW and CP LOW transparently writes resolved Y bus at the current B
address. Q and sign-compare update on CP rising edge, inhibited by IEN_n HIGH.
WE is an independent input: IEN does not directly block externally commanded
RAM writes. Native WRITE_n output can be connected externally to WE_n.

EA HIGH selects DA, LOW selects held RAM A. I0 HIGH selects Q as S;
otherwise OEB_n LOW selects held RAM B and HIGH selects DB external input.
Y and DB are bidirectional buffers with separate value/enable outputs.
Resolved Y is internal shifter output when OEY_n LOW, external y_i otherwise;
contention is a board-level error. Z is open collector: z_pull_low means
pull down, and z_i is the externally resolved bus (including own driver).
All four shift pins have separate input/value/enable signals.

LSS_n LOW selects least-significant role and drives WRITE_n. With LSS_n HIGH,
WRITE/MSS input LOW selects most-significant role and HIGH intermediate role.
An isolated MSS and LSS simultaneously is not representable on the real
part; multi-chip regression uses four slices with genuine role pins.

Table2 controls sixteen normal ALU functions; Table3 sixteen destinations.
I4..I0 zero selects Table4's nine special operations. Seven remaining special
codes are reserved; their computed data/status are unspecified and not tested
as defined behavior. IEN HIGH forces WRITE HIGH and holds Q/sign compare.
Table5 defines status/zero, including non-arithmetic normalization flags,
resolved-Y zero detection and open-collector communication in multiply/divide.
FigureB updates sign compare to XNOR(R3,F3) on special A/C only; otherwise hold.

## Assumption ledger

- ASSUMPTION: external CP controls and pins obey manufacturer setup/hold.
  LOW input capture preserves pre-edge Q/SC data when read latches reopen
  in a zero-delay engine. Original firmware validates the sampling order.
- ASSUMPTION: illegal reserved special codes leave Q/sign compare unchanged
  and produce arbitrary zero shifter data. No historical behavior is promised.
- ASSUMPTION: IEN inhibits state/WRITE while combinational data paths continue
  responding to instruction. This follows the decoder/ALU separation and is
  checked during externally inhibited firmware preparation cycles; only
  documented hold/WRITE behavior is used for conditional execution sign-off.

Scope is native digital behavior. No modeled bipolar delays, contention,
voltage or uninitialized power-up values are claimed.

## Correction of original Table5 printing

The 1978 special-E Gi/Z=LOW cell incorrectly prints complemented R despite
Table4 specifying addition. The [AMD 1979 Designer's Guide](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf),
PDF69/printed2-7, corrects that cell to R AND S. RTL and golden CSV use this
explicit manufacturer correction; it is not an inferred semantic repair.

The model includes five LOW-transparent input-capture bits before Q/sign
flip-flops to preserve pre-edge data when read latches reopen in zero-delay
simulation. These are a digital timing adapter, not claimed physical Am2903
storage. Native LOW-phase operand changes remain visible, then sampling at
the rising edge uses the pre-edge result. Synthesis area includes the adapter.
