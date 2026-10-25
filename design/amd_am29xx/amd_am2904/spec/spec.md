# Am2904 digital specification

Source: AMD **1979 Am2900 Family Data Book**, printed 2-84–2-98
(PDF 92–106), especially Tables 1–7 on PDF94–98 and interrupt applications
on PDF99. [Original scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf).
The 1978 book only provides advance information; an exact first shipment year
has not been established. Availability of advance information by 1978 is the
historical bound used in the index.

## Native interface and state

Thirteen instruction pins, positive-edge CP, two four-bit status registers
(micro U and machine M), no reset and no defined power-on state. Status vectors
use `[3:0]={overflow,negative,carry,zero}`. Active-low CEU enables all U bits;
active-low CEM and each active-low E bit enable individual M bits. Y is a
bidirectional status bus with active-low OEY. CT has independent active-low
OECT. CX is the external carry input, CO the continuously driven carry output.
Four bidirectional shift pins are represented in `[3:0]={Qn,Q0,Sn,S0}` order.
Their values and output enables are separate ports, suitable for resolved
board wiring rather than internal FPGA tri-states.

Tables 1/2 determine U/M updates from I[5:0]. Code octal00 loads old M into U
and external Y into M; octal02 swaps old registers. Code04 loads Z/N from I
and exchanges old machine carry/overflow. Codes06/07 retain sticky U overflow.
Codes10–17 alter one U bit. Codes30/31,50/51,70/71 invert input carry when
loading U; M additionally inverts carry for codes10/11. Other cases load I.
All bit updates sample pre-edge values simultaneously.

Tables 3/4 define current-state Y/CT outputs, independent of CP. I[5:4]=00/01
uses U, 10 M, 11 live I. Code00 releases Y regardless of OEY. Conditional
tests use the exact overbars in Table4: block01 changes tests8/9 for saved
borrow; block11 tests8/9 and C/D both use complemented carry. Code16/17
(octal) tests IN XOR/XNOR MN for normalization.

Table6: I[12:11]=00 gives CO=0, 01 gives1, 10 givesCX, 11 selects U/M carry
by I5 and complements it when I3=1, I2=I1=0 (I0 is don't care).
Table7 contains all32 shift linkages, selected by I[10:6]. SE HIGH releases
all four shift outputs and disables shift carry loading. When SE is LOW,
down-shift drives Sn/Qn and up-shift drives S0/Q0. A listed shift-carry load
**overrides I[5:0], CEM and EC**, including their hold requests. Other M bits
still obey their normal enables. This exception is stated explicitly on
PDF97 and in Table7 notes2/3, despite the abbreviated general pin description.

## Verification contract and assumptions

All8192 instruction words are defined. Undefined power-on status is not
masked by an invented reset; tests initialize it through two native code00
operations. Manufacturer tables are transcribed into CSV before RTL and
compiled into an independent formal/simulation oracle. External Java emulator
was considered but does not supply an acceptable native pre-edge pin oracle.

ASSUMPTION: zero-delay digital pins represent settled values with CP setup/hold
respected; analog delays, loading, metastability and bus contention are not
modeled. Released outputs have an arbitrary value represented as zero; only
enabled bits are meaningful. Validate this contract through native edges,
output-enable checks and the manufacturer's two-load interrupt restoration
and one-level swap sequences. No unstated architectural behavior is needed.
