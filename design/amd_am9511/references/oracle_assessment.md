# Independent oracle assessment

Fred Weigel's [Am9511 emulator](https://github.com/ratboy666/am9511/tree/ab8ed57f1a3eab09917f42f72f0ab70a74330501),
revision `ab8ed57f1a3eab09917f42f72f0ab70a74330501`, MIT license, is external
to this RTL. The source explicitly disclaims cycle and algorithm accuracy.
It uses host float/libm and is not an exact silicon oracle.

Source assessment performed before writing RTL:

- Reset zeroes the stack, contrary to AMD's original datasheet. Do not use its
  reset semantics as the chip contract.
- Scratch destruction is mostly absent. Compare manufacturer-documented
  survivors; do not compare unspecified scratch locations to emulator values.
- TAN computes the function only for positive arguments at least 2^-12; negative
  arguments are inadvertently returned unchanged. Use the manufacturer rule
  on magnitude and an independent mathematical oracle for those cases.
- LN/LOG/PWR reject negative bases but miss zero; the manufacturer explicitly
  requires positive logarithm arguments and power bases.
- Integer add/sub overflow helpers are called after writing an aliased result
  into the input operand. Their signed-overflow observation can therefore be
  wrong. Pin the manufacturer signed rules separately.
- `ova.c`'s double multiply calls `add64` with aliased operands. Its internal
  `add32` carry path overwrites a half before rereading it. Even multiply by
  zero can return a nonzero result for negative inputs. Reject the complete
  double-multiply routines as an oracle; use the independent primary-manual
  mathematical calculation instead. The single routines remain compared.
- `sub16` spuriously asserts borrow when its minuend is `0x8000`. The double
  subtract routine propagates this mistake across its half-word operations.
  Exclude precisely those source-defined input cases from the secondary C
  comparison; compare every RTL case against the primary-manual calculation.
- Lower multiply tests the unsigned magnitude's discarded upper half before
  signing the product. AMD's detailed description specifies the discarded
  product half, which is nonzero for negative products. This is an explicit
  manufacturer adapter, and its disagreement count is reported.
- Double multiply's second minimum-negative test references two bytes of the
  wrong operand. This is another reason those routines are rejected.
- `div16`/`div32` return zero on a zero divisor. AMD specifies the numerator
  unchanged as the result, with the same divide-by-zero error code.
- Its command entry starts status at busy alone, clearing prior flags even
  for commands whose description does not list those flags as affected.
  The original command affected-field lists define the preserved-status
  reconstruction convention; seeded host and original-program tests validate it.
- Native float conversion and non-error host arithmetic remain useful
  independent comparisons, subject to checking rounding and exponent boundaries.
- `fp_am` range-checks the intermediate exponent before adding one to obtain
  the native exponent. It incorrectly rejects valid native exponent -64.
  Reject that boundary from the C comparison, including wrapped overflow that
  lands there; continue checking it with the independent Boost oracle.
- FIXS rejects fractional inputs above 32767 even when their integer portion
  still fits fifteen bits. AMD's conversion description tests the integer
  portion. Exclude those values from the external comparison; retain the
  manufacturer-derived multiprecision checks.

Don Barber's [hardware-tested CoCo BASIC patch](https://github.com/barberd/coco9511pak/tree/0f272e44db724ed7f0e60730499457be230e4e4f),
revision `0f272e44db724ed7f0e60730499457be230e4e4f`, GPL-3.0-or-later, is additional
real-device software evidence, dated 2023 rather than historical software.
It waits on busy, writes low-to-high and reads high-to-low, and handles all
original error fields. It can supplement, but cannot replace, the mandatory
original historical software regression.
