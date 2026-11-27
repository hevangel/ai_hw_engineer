# Specification: Intel 80387 numeric processor extension (387DX; architecture shared with 387SX)

## 1. Authority

- **[387PRM]** Intel *80387 Programmer's Reference Manual*, order 231917-001 (1987). It includes Appendix C (differences from the 80287/8087), Appendix D (differences from the 8087), Figures 2-5 to 2-8 (pointer images) and the 80387 data sheet (231920-002, January 1987) as an appendix. "Section" references below are to this manual.
- **[287]** The 80287 specification in [../../../intel_80287/spec/spec.md](../../../intel_80287/spec/spec.md), and through it the 8087 specification.

## 2. Implementation boundary (milestone M1)

The design is the shared x87 controller `intel_8087` with `VARIANT = 2` and `AW = 32`. The interface is the transaction interface of [287] section 2.1. For the 387 the host also supplies `protected_i` and `opsize32_i`, because the 386 decides the pointer-image format and operand size for each instruction ([387PRM] C.4, FSETPM row: "the 80386 handles all addressing and exception-pointer information").

The native 386DX/SX coprocessor bus is milestone M3. It consists of the 387 ports at I/O 800000F8h–800000FEh, PEREQ, BUSY#, ERROR#, NPS1#/NPS2, CMD0# and STEN, with a 32-bit (DX) or 16-bit (SX) data bus.

## 3. Behaviour that differs from the 80287/8087

Every row cites [387PRM] Appendix C, unless another section is given.

| # | 80387 behaviour |
| --- | --- |
| N1 | **NaNs.** Signalling and quiet NaNs are distinguished, and only quiet NaNs are generated. An SNaN operand raises IE and is quieted. A QNaN operand raises IE only for FCOM, FIST and FBSTP. FLD of a single- or double-real SNaN raises IE. |
| N2 | **Unsupported formats.** Pseudo-zero, pseudo-NaN, pseudo-infinity and unnormal operands raise IE in arithmetic. Their tag is "special" (10). |
| N3 | **Denormals.** FDIV, FSQRT, FPREM, FIST and FBSTP accept denormal operands by normalizing them, and may underflow. FLD single/double normalizes the denormal into extended format. FLD extended does not report D. Transcendentals and FXTRACT do report D. |
| N4 | **Overflow (masked).** Overflow is always signalled. Under chop rounding the result is the largest finite number of the destination precision. **Unmasked:** the significand is rounded and PE is reported. |
| N5 | **Underflow (masked):** signalled only when the result is tiny *and* inexact. **Unmasked:** a stack destination receives the rounded significand with the exponent biased by 24,576. |
| N6 | **Exception precedence.** The denormal exception has the same precedence whether it is masked or unmasked. |
| N7 | **Initialization.** RESET and FINIT set C3–C0 to zero, and so does an incomplete FPREM. FINIT/FNINIT gives CW = 037Fh (section 4.7: round to nearest, 64-bit precision, all exceptions masked). M1 does not model the RESET side effect (IE and ES set to assert ERROR#); the core resets to the FINIT state. See A3. |
| N8 | **Infinity control.** Only affine closure exists. Bit 12 remains programmable and is stored, but has no effect. |
| N9 | **Stack fault.** A stack overflow or underflow sets IE, SF (status bit 6) and C1 (1 for overflow, 0 for underflow). |
| N10 | **Tag word.** FLDENV/FRSTOR use only the empty/non-empty distinction of each tag. FSTENV/FSAVE recompute the non-empty tags from the register contents. |
| N11 | **FSCALE.** The scale operand is unrestricted and truncated toward zero. If 0 < \|ST(1)\| < 1, ST(0) is unchanged. A rounded result or a masked underflow raises PE. |
| N12 | **FPREM.** C0, C3 and C1 always hold the three low quotient bits. A reduction is partial when the exponent difference is ≥ 64. |
| N13 | **New instructions.** FPREM1 (D9 F5): IEEE remainder with the quotient rounded to nearest-even; exact, no PE. FUCOM ST(i) (DD E0+i), FUCOMP (DD E8+i) and FUCOMPP (DA E9): unordered compare, with IE only for SNaN or an unsupported operand. FSIN (D9 FE), FCOS (D9 FF) and FSINCOS (D9 FB). |
| N14 | **Transcendental ranges.** FPTAN accepts \|x\| < 2^63 and sets C2 when out of range. FPATAN has unrestricted operands. F2XM1 accepts −1 ≤ x ≤ +1. After a masked stack overflow in FPTAN, ST and ST(1) both hold QNaN. |
| N15 | **FXTRACT.** A zero operand raises ZE and leaves ST(1) = −∞ with ST(0) = the zero. +∞ raises no exception. |
| N16 | **Constants.** FLD constants observe the rounding control (FLD1 and FLDZ are exact). |
| N17 | **FSETPM** (DB E4), **FENI** (DB E0) and **FDISI** (DB E1) are treated as FNOP. |
| N18 | **FXAM.** An empty register never gives C3–C0 = 1101 or 1111. The classes are: unsupported 000, NaN 001, normal 010, infinity 011, zero 100, empty 101, denormal 110. C1 is the sign. |
| N19 | **FSTSW AX** (DF E0) returns the status word to the CPU, as on the 80287. |
| N20 | **Pointer and environment images** (Figures 2-5 to 2-8). The 16-bit forms are 14 bytes: protected mode is the 80287 protected layout; real mode is IP[15:0]; IP[19:16], 0, opcode[10:0]; OP[15:0]; OP[19:16], 0. The 32-bit forms are 28 bytes. In protected mode each of CW/SW/TW is padded to 32 bits, followed by IP offset (32), {00000b, opcode[10:0], CS selector}, operand offset (32) and {reserved, operand selector}. In real mode each of CW/SW/TW is padded to 32 bits, followed by {reserved, IP[15:0]}, {0000b, IP[31:16], 0b, opcode[10:0]}, {reserved, OP[15:0]} and {0000b, OP[31:16], 0…}. FSAVE/FRSTOR append the 80-byte register stack: 94 bytes for 16-bit forms, 108 bytes for 32-bit forms. |
| N21 | **Error reporting.** As on the 80287, exceptions use ERROR#; IEM has no effect ([387PRM] App. D item 1). |

## 4. Assumption ledger

| Id | Assumption | Status |
| --- | --- | --- |
| A1 | For behaviour that the 387 manual defines as 387 behaviour, the build host's x87 FPU (a later IA-32 processor that kept the 387's IEEE 754 semantics) is used as a bit-exact oracle. Excluded from bit-exact comparison: transcendental results, the round-up bit after transcendentals, and FPREM/FPREM1 partial-reduction remainders. For those, the 387 iteration count is implementation-specific and the manual does not fix it. | Documented per test class in the report |
| A2 | On the 387, two NaN operands propagate the one with the larger significand (the positive one if they are equal), and an SNaN/QNaN pair returns the QNaN. Both rules are as the host does. | Host-checked (section 4.1) |
| A3 | RESET is modelled as FINIT. The manual's RESET-only side effect that marks 387 presence (IE and ES set, IM clear, so ERROR# is asserted) is not modelled in M1. | Open; M3 pin interface |
| A4 | Pseudo-denormals (exponent 0, J bit 1) are accepted as denormal operands with value 2^(−16382) × 1.f, as on the host. | Host-checked |
| A5 | FSIN/FCOS/FSINCOS and the full-range FPTAN/FPATAN/F2XM1 are not implemented in M1. They are reported as unsupported (`unsupported_o`) rather than computed. The reduced-domain 8087 FPTAN/FPATAN/F2XM1/FYL2X/FYL2XP1 algorithms are used for in-domain operands, and only those are compared, with a tolerance. | Open: M2 |
| A6 | The reserved upper halves of the 32-bit image words are stored as FFFFh (the host value), and the reserved low bits as zero. | Unvalidated against a physical 387 |

### 4.1 Behaviour measured on the host oracle

The manual does not state these rules. Each is implemented as the host behaves, and each is checked by the differential bench:

- A two-NaN operation with equal significands returns the positive NaN.
- A zero divide, an invalid operation, or an unordered/invalid compare does not also report D.
- A NaN or unsupported operand suppresses the D of a converted denormal memory operand.
- FRNDINT of a denormal keeps D.
- C1 = 1 when a masked overflow rounds to infinity, and C1 = 0 after a masked invalid operation (stores and BCD overflow included).
- An unchanged pseudo-denormal FPREM/FPREM1 dividend is returned in normal form.
- A real32/real64 SNaN memory operand counts as signalling when two NaN operands are compared for selection.

## 5. Not in M1

- **Transcendentals:** full-range transcendentals and FSIN/FCOS/FSINCOS (A5).
- **Native interface:** the native coprocessor bus of the DX and SX.
- **RESET signature:** the ERROR#-asserted state after RESET (A3).
- **Timing:** instruction timing.
