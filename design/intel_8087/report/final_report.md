# Intel 8087 architectural core report

## Delivered scope

`intel_8087` is a synthesizable SystemVerilog floating-point coprocessor
implemented with explicit sign, exponent and significand datapaths. It has
an 80-bit register stack, original D8–DF decoding and a byte memory handshake.
Floating-point calculations use integer bit-vector operations in the RTL,
without SystemVerilog `real` arithmetic or host floating-point DPI functions.

| Class | Implemented operations |
|---|---|
| Data | FLD/FST/FSTP, FILD/FIST/FISTP, FBLD/FBSTP, FXCH |
| Arithmetic | FADD/FMUL/FSUB/FSUBR/FDIV/FDIVR, integer and pop forms |
| Additional arithmetic | FSQRT, FSCALE, FPREM, FRNDINT, FXTRACT, FCHS, FABS |
| Compare | FCOM/FCOMP/FCOMPP, FICOM/FICOMP, FTST, FXAM |
| Constants | FLD1, FLDZ, FLDPI, FLDL2T, FLDL2E, FLDLG2, FLDLN2 |
| Transcendentals | F2XM1, FYL2X, FPTAN, FPATAN, FYL2XP1, using reduced-domain series |
| Control | FINIT, FENI, FDISI, FCLEX, FLDCW/FSTCW/FSTSW, FLDENV/FSTENV, FSAVE/FRSTOR, FINCSTP/FDECSTP, FFREE, FNOP |

WAIT is a CPU instruction; `cpu_wait_i` communicates its interrupt-mask
override. Later x87 operations such as FNSTSW AX and FUCOMPP are rejected.
Original memory/register encodings are supported; undocumented aliases
are outside the contract. A complete per-encoding silicon corpus is not
available here, so implementation coverage is broader than test coverage.

## Verification evidence

The simulation runner passed **246,624 checks**, **339,550 clocks**,
**173,796 memory reads** and **556 writes** on 2026-10-15. It includes:

- 7,680 independent finite x87 arithmetic comparisons across all documented
  PC and RC settings, with bit-exact extended-real expectations.
- 180 independent square-root comparisons, integer halfway rounding and
  single-real halfway stores against host x87 instructions.
- Original Intel ARRSUM numeric software, with all three sums and stack
  balance checked; CPU loop operations are provided by the fixture.
- All seven numeric memory formats, signed zero, denormals, extreme
  exponents, stack overflow/underflow, save/restore, environment transfer,
  memory stalls, final-byte store retirement, reset-aborted stores and
  twenty-bit address wrap.
- Original FINIT state, interrupt gating/WAIT override, projective infinity,
  larger-payload NaNs, unnormal arithmetic, trap result wrapping, suppression
  of unmasked memory range stores and retirement of precision-trap results.
- Sampled reduced-domain transcendental results within the declared 4e-18
  relative tolerance against independent mathematical library functions.

Strict `verilator --lint-only -Wall` passes (Verilator 5.052). Intentional
unused fields are scoped in the source; a scoped diagnostic exemption covers
the tool's automatic-task next-state write counting, not additional drivers.

Controller BMC and induction pass with the documented reduced D9 alphabet.
Non-vacuity covers reach eight pushes through TOP wrap (step 18) and a
stalled/completed control-word store (completion at step 6). See the
[formal boundary](../plans/testplan.md). These are controller proofs with
explicit numeric cuts, not arithmetic or full-instruction-set proofs.

Yosys process lowering, optimization, structural checks and word-level JSON
netlist generation pass for the real, unabstracted RTL. The netlist is
technology independent and includes wide arithmetic cells.

## Compatibility and engineering limits

This is **not a pin-compatible or timing-equivalent 8087**, and the current
evidence is not a full original-silicon compatibility sign-off.

- The host must supply ESC bytes and calculated addresses. Native prefetch
  queue mirroring, instruction-stream snooping, CPU identification,
  first-word dummy-read capture and RQ/GT arbitration are not implemented.
  No change connects this core to an existing system automatically.
- Commands serialize; CU/NEU overlap and exact BUSY/instruction timing are
  outside the transaction contract. Reset abandons an in-flight transfer.
- Transcendentals use full-precision nearest-rounded internal series.
  Their sampled accuracy is not an exhaustive uniform error bound; original
  microcode results, directed transcendental rounding, final exceptional
  range handling and all extreme-domain inputs are not fully characterized.
  Out-of-domain operands are undefined by the original manual.
- The original noncanonical unnormal/pseudo encodings, exception precedence,
  and undefined condition-code bits have finite directed evidence, not an
  exhaustive physical-chip comparison. FXTRACT special operands beyond
  the tested normal and signed-zero cases are not signed off.
- RTL synthesis is checked at word level. Wide division/square-root paths
  have no place-and-route, mapped area or clock-frequency evidence.
- Historical software evidence is Intel's numeric program replay, not an
  unchanged application binary running on an integrated 8086/8087 board.

No unresolved TODO markers are used as substitutes for implementation;
the explicit limits above define the delivered verification boundary.
## XT integration follow-up

Numeric combinational paths now have execution enables for complete-system
simulation. The existing 246,624-check numerical regression passed unchanged
after this optimization. The XT platform also exercises CPU-issued ESC/WAIT,
memory arbitration and a DOS program computing 6*7 and SQRT(169).
