# Verification report: Intel 80387, milestones M1 and M2 (architectural model)

Date: 2026-11-27. Canonical issue: [hevangel/ai_engineer#115](https://github.com/hevangel/ai_engineer/issues/115).

## Summary

| Gate | Result |
| --- | --- |
| Lint (Verilator 5.052 `-Wall`, `VARIANT=2`) | pass |
| Host-x87 differential, seed 0x803871987, 20,000 per form | **920,028 / 920,028** match |
| Host-x87 differential, seed 0x1987, 20,000 per form | **920,028 / 920,028** match |
| Host-x87 differential, seed 0x387dead, 50,000 per form | **2,300,028 / 2,300,028** match |
| Transcendentals: FSIN, FCOS, FSINCOS, FPTAN, FPATAN, F2XM1, FYL2X, FYL2XP1 (three seeds) | **180,024 / 180,024** within 8 ULP of the host, max observed 6 ULP; exceptional classes, flags, C2, TOP and tags exact |
| Directed control, images, stack fault, FSTSW AX | pass |
| Original Intel ARRSUM software (8087 supplement, figure S-24) | pass |
| Controller formal (`VARIANT=2`) | FORMAL_RESULT |
| Synthesis elaboration | SYNTH_RESULT |

This is an **architectural** 80387. It is not a complete one:
- the native 386 coprocessor bus does not exist;
- the RESET signature is not modelled;
- transcendental results are within 8 ULP of the host, not bit-identical to the 387's microcode.

The full instruction set, transcendentals included, is implemented.

See `plans/implementation_plan.md`. This milestone is not acceptance of issue #115.

## Implementation

The design is the shared x87 controller `design/intel_8087/src/intel_8087.sv`, with its ALU, transcendental unit and math helpers, built with `VARIANT = 2` and `AW = 32`. Every 80387 rule is guarded by `VARIANT == 2` and cites [387PRM] Appendix C or the measured rule list in the spec (section 4.1). The 8087 regression, which builds with `VARIANT = 0`, still passes with all of its checks.

## Oracle

The bench (`tb/tb_80387.cpp`) generates a code stub for each case and runs it on the build host's x87:

1. `fninit`
2. `fldcw`
3. `fld` ST(1)
4. `fld` ST(0)
5. the instruction under test, as the same opcode bytes the RTL receives
6. `fnsave`

The RTL then starts from the same state. The host FPU is an external artifact, independent of this RTL. The 80387 defined the IEEE 754 x87 behaviour that later IA-32 FPUs preserved. Behaviour that the 387 manual leaves implementation-specific is excluded (spec A1).

**Compared:**
- all non-empty ST(i) values;
- the full 16-bit tag word;
- status bits IE..PE, SF, C0–C3 and TOP;
- the stored bytes of every store form.

**Coverage:**
- **46 instruction forms:**
  - arithmetic, register and memory forms: FADD/FSUB/FSUBR/FMUL/FDIV/FDIVR and the integer FIADD/FIDIV;
  - compares: FCOM/FCOMP/FCOMPP, FUCOM/FUCOMP/FUCOMPP, FICOM;
  - FTST, FXAM, FCHS, FABS;
  - FSQRT, FRNDINT, FSCALE, FPREM, FPREM1, FXTRACT;
  - register moves: FXCH, FLD ST(i), FSTP ST(i);
  - loads: FLD m32/m64, FILD m64;
  - stores: FST/FSTP m32/m64/m80, FIST/FISTP m16/m32/m64, FBSTP.
- **Operands:** 11 value classes in every pairing.
- **Control:** all four rounding modes, and precision control 64/53/24.
- **Constants:** the five FLD constants under all four rounding modes.

## Findings while building M1

The first differential run matched 96.7%. Every remaining class was traced and fixed against the oracle. Each rule is cited in the RTL and the spec:

- **C1:** set when a masked overflow rounds to infinity; cleared after a masked invalid operation.
- **D-flag precedence:** no D with ZE, with IE, or with an unordered compare.
- **NaN results:** NaN results are kept, not replaced by the indefinite. Equal-significand NaNs return the positive one. A memory SNaN still counts as signalling.
- **FPREM1:** an infinite divisor takes the bypass path; an unchanged pseudo-denormal dividend is returned in normal form.
- **FRNDINT:** keeps D for a denormal; rounds up to +2^63 without IE.

Two of these were defects of the shared 8087 controller itself: zero-vs-denormal ordering and FRNDINT at 2^63. A third came from the 387 manual: the 8087's constants are chop values. All three are fixed for every variant and recorded in [failure_notes/2026-11-27-x87-zero-denormal-compare.md](../../../../failure_notes/2026-11-27-x87-zero-denormal-compare.md).

## Limits

- **Transcendentals (M2, spec A5/A7):** the algorithms are reconstructions, not Intel microcode.
  - FSIN, FCOS, FSINCOS and FPTAN reduce the argument exactly modulo π/2 with the documented 66-bit π, then evaluate series.
  - FPATAN covers every octant and quadrant.
  - Agreement with the host is within 8 ULP, not bit-exact. The round-up bit (C1) and PE/UE are not compared for these instructions.
  - FYL2X and FYL2XP1 are tested only in their main domains (x > 0, and \|x\| < 1 − √2/2). Their behaviour for zero, negative and infinite operands is the inherited 8087 behaviour and is unverified.
- **Unmasked exceptions:** covered only by directed tests and the shared 8087 suite. The host bench runs with all exceptions masked.
- **Reserved image bits:** the reserved fields of the 32-bit images (A6) are unvalidated.
- **Interface and timing:** RESET signature, native bus, timing and electrical behaviour are outside M1.
- **Oracle:** it is a later IA-32 FPU, not a physical 80387. Rules for which the 387 might differ from its successors are listed in spec section 4.1. A physical-387 capture would be the next oracle step.
