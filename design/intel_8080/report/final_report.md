# Intel 8080 initial implementation report

Verified October 8, 2026 in the local `ai-hw-engineer:latest` container with
Verilator 5.052, Yosys 0.69, SymbiYosys/ABC/Z3 and xezim 0.11.0
(`6558a1e`), using UVM 1800.2-2017. These are observed results from this
Intel design, not copied verification claims from the Am9080 predecessor.

```sh
sh design/intel_8080/scripts/run_all.sh
```

## Observed results

| Check | Result |
|---|---|
| RTL and differential-testbench Verilator `-Wall` lint | Pass, no lint warnings |
| Exhaustive independent-oracle ALU/flags | 16,842,752 comparisons; zero failures |
| Documented opcode regression | 244 opcodes x 32 flag combinations = 7,808 cases; 78,048 exact retirement/next-instruction/effect checks |
| Original TST8080.COM | Pass, 661 retirement checks including bootstrap; original hash and success output verified |
| Original 8080PRE.COM | Pass, 1,071 retirement checks including bootstrap; original hash and success output verified |
| UVM control/Intel flags | 19 scenarios, 168 state snapshots, 576 clock steps, 237 acknowledged transfers; zero UVM_ERROR/UVM_FATAL |
| Formal | All six BMC/prove/cover tasks pass; 19 ALU and eight controller covers reached |
| Synthesis | 3,352 total cells including 393 ALU cells; no inferred latches; Yosys `check -assert` reports zero problems |

The immutable external Intel emulator is used directly, without the AMD
ANA/ANI correction. Canonical LF hashes of its source and header are checked.
All ALU operands and all 32 status combinations are covered for the eight
binary operations; all values/status combinations are covered for INR/DCR,
DAA, rotations and CMA. Four additional UVM operand pairs explicitly check
both register ANA and immediate ANI, distinguishing Intel 8080 AC from AMD,
8085 and an incorrect result-bit implementation.

Opcode checks include both conditional outcomes, memory destinations,
stack/direct-word wrap, PSW and the exact next instruction actually fetched
and executed. Unused instruction-test locations are HLT poison. Historical
diagnostic instruction bytes are unchanged; the harness provides bootstrap
and CP/M BDOS outside the original image. Complete BDOS console output also
matches the independent oracle. READY stalls occur during real-code execution.

UVM exercises READY stability, completion-before-HOLD, HOLD priority during
HALT, disabled-interrupt HALT, EI recognition delay, RST injection, injected
CALL operand streams, reset retention, I/O, all twelve excluded opcodes and
the injected-XTHL validity boundary. The inherited register-save ISR has
PUSH PSW/B/D/H, POP H/D/B/PSW, EI/RET; its AMD source is identified in the
test plan. A pending INT during EI must not preempt RET.

Formal ALU equations derive independently from external C helpers. Controller
depth-32 ABC BMC and unbounded SMT induction establish reset/retention, stable
stalls, HOLD/fault bus suppression, status/space decode and retirement
boundaries. These control proofs do not prove every instruction; the opcode
and real-software regressions perform the semantic comparisons.

## Findings and tool diagnostics

The first integrity check rejected the shared oracle because Git had checked
out its upstream LF text with Windows CRLF endings. Normalizing only line
terminators reproduced the pinned upstream source hash exactly. The check
now accepts either checkout representation without rewriting vendor files.
No RTL semantic mismatch was found by the verification suite.

The xezim/UVM runtime emits 23 `UVM/COMP/NAME` warnings for ordinary valid
component names and a library phase-delay diagnostic at time zero. They
remain visible; no blanket suppression is used. All scenarios finish well
before the watchdog with zero UVM errors/fatals. ABC reports combinational
network notices during synthesis and unconstrained-input notices during
formal AIG preparation. These are recorded rather than described as a
warning-free tool run. Standalone RTL/testbench Verilator lint is clean.

## Remaining milestones and limits

The initial scope is the complete **documented instruction set on a
functional ready/valid bus**. Native two-phase pin timing and manufacturer
T-state counts are not implemented. Undocumented aliases raise model faults.
Normal XTHL works; externally injected XTHL remains an explicit limitation.
Three-byte interrupt CALL tests pass the inherited functional contract, but
Intel-specific historical device/software evidence for subsequent operand
bus cycles remains open. This provisional assumption is not signed off by
ordinary diagnostics. Scope remains the 8080 chip and chip-level verification;
computer/board/system builds are excluded. Historical diagnostic software is
test stimulus. See the [specification](../spec/spec.md) for the full ledger.
