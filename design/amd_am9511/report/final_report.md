# Am9511 verification report

Status: **verified within the documented functional reconstruction contract**.
All 43 original commands and service-request variants are implemented. The
complete `scripts/run_all.sh` flow passes in `ai-hw-engineer:latest`, with
Verilator 5.052, Yosys 0.69, SymbiYosys/ABC/Z3, C/C++ and Boost multiprecision.

## Independent simulations

| Suite | Cases | Checks | Independent evidence |
|---|---:|---:|---|
| Fixed arithmetic | 1,082,624 | 35,989,088 | Manufacturer-wide integer rules; 891,191 comparisons against pinned external C routines |
| Native float/conversion | 387,561 | 17,270,139 | Boost high-precision arithmetic; 370,242 pinned external emulator comparisons |
| Eleven derived functions | 36,443 | 77,316,667 | Boost high-precision functions over all exponent ranges, extrema, domains and random arguments |
| Serial divider/phase reducer | 8,192 | 2,981,890 | Arbitrary-precision integer quotient, remainder and phase reduction |
| Whole host interface | 2,752 | 1,785,748 | All 43 CSV commands and both service settings; independent stack-token interpretation |
| Original DEMAND/POLL software | 330 | 412,973 | Unmodified published object code on Am9080A + Am9511; pinned external CPU oracle and separate APU mathematics |
| Total | 1,517,902 | 135,756,505 | All suites required by run_all.sh |

Fixed tests exhaust every signed eight-bit pair in both widths for five binary
operations, all 16-bit negations and full-width directed/random cases. The
secondary external routines require 33,106 explicitly documented manufacturer
adapter differences and rejection of 191,388 cases from defective upstream
routines. Every case remains checked by independent wide manufacturer arithmetic.
Float tests exhaust FLTS inputs, span all 128 native exponents, ties, cancellation,
normalization, conversion widths and wrapped exponent errors. 17,319 values
outside the external emulator's correct contract retain high-precision checks.
See [oracle assessment](../references/oracle_assessment.md) for each exclusion.

Derived tests contain 28,912 valid results and 7,531 domain errors. Every
function's observed relative error is below 5.961e-8 in this sample. Original
function-specific tolerances and the clearly separate reconstruction checks
outside historical guaranteed ranges are specified in the [specification](../spec/spec.md).
No finite random test is presented as a mathematical proof over all inputs.
The direct numerical-unit suite checks signed/unsigned extrema, zero divisors,
changed inputs and ignored starts while busy, exact 128/176-step latency, single
completion and reset abort against independent arbitrary-precision operations.

Whole-chip tests perform 239,477 native host transfers. They check every legal
command's documented survivors and conversion-width changes, seeded carry/error
preservation, held reads/writes, byte order/rotation, busy data stalls and status
reads, reset stack retention, service acknowledgment and tied-EACK completion.
Destroyed and unspecified domain-error stack results are masked as AMD specifies.

## Actual historical software

AMD's May1981 original DEMAND and POLL object bytes run unchanged, including
the authoritative 003e branch target where the printed source label disagrees.
The regression executes **38,835 instructions**, **5,245 input-port reads** and
**2,970 output-port writes**. Every retirement compares exact post-PC, registers,
flags, SP and memory effects against the pinned independent Superzazu 8080 ISS;
every instruction fetch checks its exact PC and opcode. Input data is replayed
to that CPU oracle, while APU results use separate high-precision mathematics.

Original-program cases include ten arithmetic commands, extrema/divide-zero,
SDIV -32768/-1, native PUPI and both FADD halfway tie directions. A real project
caller and exact reset JMP overlay supply setup; neither original routine is
reassembled, patched or padded. Object bytes are integrity-checked before each
run. [Provenance](../references/original_host.md) identifies source pages/hashes.
The [assumption ledger](../spec/spec.md) records software evidence and the limits
of compatibility tests as evidence for undocumented physical-chip details.

## Formal, lint and synthesis

All six formal tasks pass: fixed BMC depth10, unbounded ABC PDR and cover depth38;
host transport BMC depth8, unbounded ABC PDR and cover depth16. All **57 covers**
are reached: eight fixed-unit scenarios, 43 distinct command completions and six
host scenarios. Normal AIG messages identify unconstrained primary inputs and
assumption outputs; no failed task is suppressed.

The fixed proof covers direct add/subtract/negate values, reset, protocol and
iteration bounds. The host proof uses explicit numerical abstractions with
arbitrary values/status and a two-cycle response. It proves actual stack
survivors against a separate CSV-generated checker, affected/preserved flags,
byte push/rotation, held reads, reset retention and acknowledgments. It does
**not** prove floating or transcendental accuracy, real numeric-engine progress
or original execution-cycle timing; those use full RTL simulation. See the
[formal plan](../plans/formal_plan.md) and dedicated abstraction source files.

All Verilator `--lint-only -Wall` checks and compiled simulation tops pass
without warning suppressions. Yosys elaboration, synthesis, generic four-input
LUT mapping and `check -assert` pass without warnings or inferred latches. The
hierarchical total is **138,934 LUTs and 3,063 flip-flops** (141,997 cells), with
the retained sixteen-byte stack among the registers. This generic mapping is
not an ASIC area, performance estimate or reconstruction of the original die.

## Scope and remaining physical uncertainty

Native 24-bit mantissa/seven-bit exponent floating point is implemented, not
IEEE encoding. Numeric paths use bounded synthesizable approximation algorithms;
private AMD Chebyshev microcode is not claimed to be recovered. Original analog
pin delays and exact microcycle counts are excluded. Sampled handshake/reset/ack,
nearest-even rounding, PUPI bits and preserved unaffected flags are explicit
validated reconstruction conventions. Illegal commands and non-normalized
nonzero float inputs have no specified contract; destroyed locations and
undefined error results do not gain invented hardware guarantees.

All development failures were detected by these design-owned verification
suites. No escaped defect or unresolved implementation TODO is known at sign-off.
