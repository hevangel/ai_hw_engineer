# 2026-11-27 — x87 core: chop constants, zero/denormal ordering, FRNDINT at 2^63

**Design:** `design/intel_8087` (shared x87 controller, now also built as the 80287 and the 80387).
**Found by:** two sources outside the 8087's own suite:
- Intel's 80387 Programmer's Reference Manual, 231917-001, Appendix C;
- the new 80387 host-x87 differential bench (`design/intel_80387/intel_80387dx/tb/tb_80387.cpp`).

## What broke

1. **Load constants.** FLDL2T, FLDL2E, FLDPI, FLDLG2 and FLDLN2 returned round-to-nearest significands, for example π ending in `…C235`. [387PRM] App. C.4 ("FLD constant") states that on the 8087/80287 the rounding control is not in effect, and that the results equal the 80387's round-to-zero/−∞ results, with FLDL2T also equal under round-to-nearest. So the 8087/80287 load the **chop** values (`…8AFE`, `…F0BB`, `…C234`, `…F798`, `…79AB`). Four of the five constants were one LSB high.
2. **Zero against a denormal.** FCOM/FTST ordered +0 *above* a positive denormal. The compare normalizes both significands, and a denormal's exponent then drops below the field minimum of 1. A zero kept exponent 1 and so looked larger in magnitude. The 387 bench found this as FCOM/FTST/FUCOM status mismatches against the host.
3. **FRNDINT at 2^63.** A positive value just below 2^63 that rounds up raised IE and returned the indefinite. FRNDINT used the signed 64-bit integer conversion, which overflows at +2^63. FRNDINT has no integer range limit. The 387 bench found it (`FRNDINT 403DFFFF…`).

## Why verification missed them

- **Constants.** The 8087 bench never checked the five constants. Their encodings were derived by rounding the mathematical constants, which was the same reading in both the RTL and the author's head. No external source fixed the 8087 behaviour until the 387 manual's compatibility appendix was read.
- **Compare.** The arithmetic oracle covered FADD/FMUL/FSUB/FDIV only. Compares were tested with a handful of normal values. No case paired a zero with a denormal.
- **FRNDINT.** Only directed values (±0.5 … ±2.5) were used, all far from the top of the integer range.

## Fix and re-verification

- `fp_constant()` in `intel_8087.sv` holds the chop value and a nearest-rounds-up bit for each constant. The 8087 and 80287 return the chop value; the 80387 applies its rounding control. Citation: [387PRM] App. C.4.
- `compare_value()` gives a zero the smallest magnitude after normalization. This applies to every variant.
- The ALU's FRNDINT path returns +2^63 with PE and C1 when the positive int64 conversion overflows.
- **Regression checks added** to `design/intel_8087/tb/test_8087.cpp`, which also runs as the 80287 regression:
  - every constant against the chop value;
  - 0 vs ±denormal;
  - FRNDINT of `403D FFFF…`.

  Against the original RTL, the constant, `0 < +denormal` and FRNDINT checks each fail. The `0 > −denormal` check happens to pass on both, because the error cancels for two negative operands.
- **Results:**
  - 8087: 246,729 checks pass.
  - 80287: 246,934 checks pass.
  - 80387 host differential: 920,028/920,028 cases match.

## Prevention

- Every instruction with a numeric result goes through a differential oracle over value classes, not only a few directed values: zero, denormal, pseudo-denormal, NaN, infinity and unsupported formats, combined pairwise. The 80387 bench does this for 46 instruction forms.
- A manufacturer compatibility appendix that lists behaviour of an earlier part is an external oracle for that part. Read it when a later member is built.
