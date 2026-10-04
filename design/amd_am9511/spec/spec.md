# Am9511 specification

## Source priority and modeling boundary

AMD's 1979 Designer's Guide, PDF pages 235–244 (datasheet) and 275–296
(algorithm application brief), defines the original Am9511 contract. The
manufacturer stack diagrams and detailed command descriptions take precedence
over OCR text. Later Am9511A documentation must not silently change this target.
The specification preceded RTL. Explicit functional assumptions below remain
identified rather than presented as recovered silicon details.

Implement a synthesizable digital functional reconstruction of all 43 legal
base commands and their service-request variants. This is not a transistor,
analog, propagation-delay or original microcycle reconstruction. Latency and
clock-sampling conventions must be documented and verified before sign-off.
Illegal command bytes and stack scratch locations that AMD labels destroyed
have no specified data result; tests must compare only documented values.

## Concrete digital timing contract

The external CLK is the digital sampling clock for this reconstruction.
RESET and acknowledgments must be held across a rising edge. A bus request is
accepted once, at a rising edge, with one-clock interface latency; PAUSE stays
LOW until acceptance. Status reads remain available while computation is busy.
Physical asynchronous propagation delays and manufacturer execution-cycle
counts are outside this functional contract. The internal arithmetic divider
uses 128 clocks, one bit per clock. All legal command latencies are bounded
by 6,100 sampling clocks. END with EACK held LOW is represented by the
completion HIGH clock phase, less than a complete period.

Commands modify only the fields listed under `Status Affected`; NOP clears all
fields. Scratch values are deterministically cleared where the source labels
them destroyed, with no claim that the physical part clears them. Undefined
domain-error results and undocumented error-path stack contents are excluded
from comparisons; explicit divide-zero and conversion-overflow behavior stays
part of the contract.

## Pins and transfers

Native RESET is active HIGH. It aborts execution, clears status, idles the
device, and leaves the stack contents intact. There is no power-on reset.
Native CS/RD/WR/EACK/SVACK and PAUSE are active LOW. C/D is HIGH for command
writes/status reads and LOW for byte-stack writes/reads. RD and WR must be
mutually exclusive. Bus ports represent separate input, output and enable;
END is represented as an open-drain pull-low output.

The host holds control and write data until PAUSE returns HIGH. A held bus
cycle completes once. Busy commands and data accesses wait; status reads
remain available during execution. Output drives only while CS and RD are
LOW. Reading a data byte removes the most significant byte of TOS and rotates
that byte to the bottom of the sixteen-byte stack. Writes push one byte and
discard the old bottom byte. Operands are written least-significant byte first
and read most-significant byte first.

END pulls LOW at command completion and clears on EACK, RESET or any access.
With EACK held LOW the physical part still emits a short completion pulse.
SVREQ is HIGH after a completed command with bit 7 set; SVACK/RESET clear it,
as does completion of a subsequent command with bit 7 clear. Access alone
does not clear SVREQ.

## Data and status

The stack holds eight signed two's-complement 16-bit integers or four signed
32-bit integers/floats; mixed-format entries are possible. Float layout is
sign at bit 31, unbiased signed seven-bit exponent at bits 30:24, explicit
24-bit fractional mantissa at bits 23:0. Value = signed mantissa/2^24 times
2^exponent. Mantissa bit 23 must be one for nonzero inputs; zero is all zero.
This is not IEEE floating point. Exponents run from -64 to +63.

Status is {busy,sign,zero,error[3:0],carry}. Error encodings: 8 divide by zero,
4 non-positive logarithm/negative square root, 12 invalid inverse sine/cosine
or exponential argument, low two bits 2 underflow and 1 overflow. While busy,
only busy is defined. Sign and zero describe the resulting TOS in the command's
result format. NOP clears the entire status byte. Carry is a carry/borrow
indicator, not signed overflow. Affected/preserved flags follow the individual original command descriptions;
the preservation convention is identified in the assumption ledger.

Floating arithmetic exponent errors retain the normalized mantissa and wrap
the exponent by 128. Fixed add/subtract return the low-width result; subtraction
with the most negative TOS reports overflow even if ordinary arithmetic would
fit. Signed multiplication with either most negative operand reports overflow;
the original single lower/upper and double lower commands return that operand,
whereas the double upper result is unspecified. Lower multiplication reports
overflow when the discarded upper product half is nonzero, including negative
products. Fixed divide has no remainder. The double divide description declares
results unspecified and overflow if either operand is the most negative value.
Divide by zero returns the numerator and error 8.

## Command and stack table

[commands.csv](../references/commands.csv) transcribes all 43 command codes,
result formats, documented surviving entries, affected flags and source pages.
Positions A through H denote initial TOS downward. A `?` denotes documented
scratch destruction or an unspecified result, never a required zero.

PUPI pushes the native float constant pi. FIXS reduces a successful converted
four-byte TOS to two bytes; conversion overflow retains the original four-byte
TOS. FLTS expands a two-byte TOS to four bytes, consuming one extra stack word.
Other documented scratch destruction still applies on conversion overflow.

Transcendental arguments are radians. SIN/TAN return the argument for magnitudes
at most 2^-12. ASIN/ACOS accept [-1,+1]. EXP accepts [-32,+32]. LOG/LN require
positive inputs, including a rejection of zero. PWR is EXP[TOS * LN(NOS)],
requires a positive NOS, preserves initial C, pops four bytes, and destroys D.
Accuracy bounds are taken from the individual command descriptions, not from
the third-party emulator's host library result. Tests will check those bounds
against independently computed high-precision results over each stated range.

## Assumption ledger

These are validated reconstruction conventions, with remaining historical
uncertainty stated explicitly. Running original software establishes functional
compatibility of these choices; it does not establish undocumented silicon bits
or asynchronous electrical timing without physical measurements.

| Assumption | Independent evidence | Real-code and integration evidence |
|---|---|---|
| SDIV -32768/-1 wraps to 8000 without another error | Original SDIV PDF293 lists only divide-zero; pinned external `ova.c` agrees | Original DEMAND and POLL both run this case and check the two-byte quotient and status |
| Mantissa rounding is nearest-even | Primary brief omits tie mode; pinned host-float emulator agrees away from documented exclusions; Boost high-precision references check exact arithmetic and ties | Original DEMAND/POLL run both even-lower and odd-lower half-ULP FADD cases; derived functions use the same encoding convention |
| PUPI returns 02c90fda | Native constant in pinned independent emulator; manufacturer identifies pi without printing its bits | Both original routines execute PUPI and compare its exact native result |
| Fields outside `Status Affected` hold | Original command descriptions define affected lists; external emulator's unconditional clearing is rejected explicitly | All 43 command host cases start with nonzero carry/error seeds and check preserved fields; original routines consume returned status |
| Clock-sampled interface/reset/ack and half-clock tied-EACK pulse | Explicit digital adapter to original asynchronous pin interface | DEMAND exercises PAUSE stalls, POLL exercises busy reads; held-cycle, reset-retention, acknowledgment and tied-EACK pulse tests check the adapter |

Every assumption carries an `ASSUMPTION:` RTL comment. Illegal commands,
non-normalized nonzero floats, destroyed scratch values and unspecified domain
error results are outside the defined result contract, not newly guessed cases.

## Numerical implementation and bounds

The implementation uses signed fixed arithmetic, guarded native floating
arithmetic and bounded iterative math. SQRT uses a restoring root; trig and
inverse trig use Q56 CORDIC with 52 steps; LN uses 21 atanh-series terms; EXP
uses 24 Taylor terms after ln(2) reduction; PWR composes LN and EXP. A 128/64-bit
restoring divider and a 176-bit/115-bit phase reducer avoid combinational divide
and modulo in those iterative paths. Q112 full-angle reduction preserves input
significance across the complete native exponent range. Mathematical constants
are generated with Decimal precision 100; they are not recovered AMD microcode.

The high-precision tests use the original command-specific relative bounds:
SIN/COS/TAN 5e-7 within ±2pi, ASIN 4e-7, ACOS 2e-7, ATAN 3e-7, EXP 5e-7 and
PWR 7e-7. LOG/LN use absolute 2e-7 near their zeros and relative 2e-7 elsewhere.
SQRT uses a reconstruction acceptance bound 2e-7, supported by the original
accuracy plot rather than an explicit textual guarantee. Outside the guaranteed
trig interval, absolute 2e-7*(1+abs(result)) is a numerical reconstruction check
rather than a historical guarantee. These finite-sample tests do not prove an
error bound for every representable input.
