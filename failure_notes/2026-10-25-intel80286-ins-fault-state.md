# 80286 INS protection-fault register state — 2026-10-25

## External evidence and failure

Intel's [LOADALL technical memo](https://docs.pcjs.org/manuals/intel/80286/80286_LOADALL.pdf),
page 14, requires the handler to repair DI after an INS protection fault and
to add two to CX for a repeated destination fault. Its
[15 October 1984 restartability correction](https://docs.pcjs.org/manuals/intel/80286/80286_B2_B3_REP-1984-10-15.pdf)
states that a final-element destination fault leaves CX=0000 on B2/B3/C2,
with corrected steppings leaving FFFF so that the repair rule works.

The recovered core instead preserved DI/CX on a denied INS destination.
The first new directed tests passed because their expected values shared
that idealized restart assumption. After revising those expectations from
Intel's original documents, the old core fails with
`INS fault packet or completed-element state is imprecise`.

The old-core failing executable, input identities and failure log are retained
in `design/intel_80286/work/protected_ins_native_red_20261025/`. The old core
SHA-256 is `c77cfbcedb8e0868a9826ad3df033e5b1f586338082018d3be905241fd54a702`.
Earlier passing `protected_ins_20261025_01`, `_02` and their initial mutation
results only validate the old project contract; they are superseded as
architectural evidence for this fault behavior.

## Cause and fix

The full-span ES precheck treated all failed operands as leaving general
registers unchanged. The general formal invariant repeated that assumption.
Component access checks and the prior protected MOV fault fixture did not
exercise native string restart side effects. The broad initial stepping
errata summary was insufficient to pin the later DI/CX rules.

For protected INS destination denial, the core now advances DI by the element
delta and subtracts two from CX when REP is active. It selects the corrected
post-C2 count behavior. INS at DI=FFFF now also reaches the whole-span checker
and this fault-state update. Other registers, flags, saved prefix PC, completed
transfers and the existing same-level exception path retain their specified
behavior. Formal checks explicitly distinguish this native register update
from ordinary failed operand references.

The diagnostic handler reverses DI, repairs CX, widens ES and retries. Tests
cover byte overrun, word straddle, 64K word wrap, and final/nonfinal REP faults
in both wait modes. They check actual port consumption, memory writes,
completed-element counts, exception frames, retirement PCs and successors.

## Verification and limits

The corrected source replay passes all ten INS cases and the five prior
protected recovery/reset cases. Its source/tool/binary manifest and log are
under `design/intel_80286/work/protected_ins_native_20261025_01/`.
All five source mutations are detected, strict lint and synthesis pass, and
depth-12 BMC passes. Cover mode times out after 11 witnesses. See
[the verification report](../design/intel_80286/report/2026-10-25-protected-ins.md)
and [continuation status](../plans/286/STATUS.md) for exact identities and limits.

A20's suppression of port consumption on destination denial remains an
unverified native-timing assumption. No physical 286 trace or historical OS/2
workload validates it yet. Audit MOVS, OUTS, STOS, SCAS and CMPS against Intel's
repair rules as well. Earlier full-core proofs are stale after this RTL and
property change; the full proof/cover/release gate remains open.

## Prevention

Keep the original Intel memo links beside the specification, test and RTL
rule. Require a regression that fails on the old core, plus mutation rejection
of preserving pre-fault indices. Record stepping-specific behavior explicitly;
do not substitute later x86 restart behavior. The existing independent-oracle
and assumption-ledger rules in AGENTS.md apply to every subsequent string fix.

## MOVS/STOS/OUTS follow-up

The same broad preservation invariant also hid incorrect fault-time state for
MOVS source/destination, STOS and OUTS memory-source faults. An independently
derived MOVS test fails against the INS-only checkpoint. The complete failing
source snapshot and replay log are retained under
`design/intel_80286/work/protected_strings_red_20261025_01/`.

The follow-up distinguishes first- and second-reference MOVS failures and
extends the checker path to protected word wrap. Forty additional replay cases
cover these four groups, including backward operation, byte/word sizes and
final/nonfinal REP faults. The [follow-up report](../design/intel_80286/report/2026-10-25-protected-strings.md)
records the current evidence. CMPS/SCAS and IOPL faults remain open; the full
80286 and its historical-software release gate remain incomplete.
