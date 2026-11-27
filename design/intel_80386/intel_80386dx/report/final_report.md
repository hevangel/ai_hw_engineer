# Verification report: Intel 80386 core, milestone M1 (real-address mode)

Date: 2026-11-27. Canonical issue: [hevangel/ai_engineer#116](https://github.com/hevangel/ai_engineer/issues/116).

## Summary

| Gate | Result |
| --- | --- |
| Lint (`verilator --lint-only -Wall`, 5.020) | pass, with justified pragmas: BLKSEQ only for scratch values, and partial-width helper arguments |
| Physical-capture replay (SingleStepTests/80386 `459d49fb`, `v1_ex_real_mode`, 941 files) | **1,758,671 pass, 20 fail** (all 20 listed open), 8 waived, 1 upstream-revoked; 937 of 941 files fully pass |
| Formal: divider (W = 4) prove + cover | pass |
| Formal: ALU flags | cover pass; the 32-bit prove did not finish within the session's memory limit (see below) |
| Synthesis (Yosys) | see the Synthesis section |
| Original historical software | **not run; this gate is open** |

The milestone delivers the real-mode architectural core. It is **not** a complete 80386. Protected mode, paging, virtual-8086 mode, debug breakpoints, hardware interrupts and both native bus units remain (see `plans/implementation_plan.md`). Nothing here should be read as acceptance of issue #116 as a whole.

## Reproduction

The commands below were run from `design/intel_80386/intel_80386dx`, with `SST386_DIR` pointing at a clone of the pinned upstream revision.

```sh
sh scripts/run_lint.sh
SST386_DIR=/path/to/SingleStepTests-80386 sh scripts/run_vectors.sh
I386_SBY=yowasp-sby sh scripts/run_formal.sh
sh scripts/run_synth.sh
```

Tool versions used in this session (a cloud container, not the project Docker image): Verilator 5.020, Yosys 0.33 (native) and 0.71 (YoWASP), SymbiYosys from upstream `b21f778`, z3 4.8.12. The Docker image pins newer Verilator and Yosys revisions. A replay under the image is still to be recorded.

## Oracle

- **Source.** SingleStepTests/80386 v1.0.0 real-mode set, revision `459d49fbe6280e9ed46fee887b58dacd9cb880ab`. Each test was captured twice from a physical **Intel 80386EX** (KU80C386EX33) through ArduinoX86 and accepted only when both captures agreed. The test generator does not use an emulator. This makes it an external artifact, independent of this RTL.
- **Selection.** All 941 files; 1,758,699 records after the one upstream revocation. The file list is committed in `scripts/sst386_real_mode_files.txt`, and the manifest records every file's SHA-256.
- **Compared.** All 20 captured registers (CR0, CR3, eight GPRs, six selectors, EIP, EFLAGS, DR6, DR7) and every captured final memory byte. Any other write that changed memory is rejected. EFLAGS and pushed FLAGS images go through the capture's per-opcode `f_umask`, which masks the documented-undefined flags.
- **Not compared.** Bus cycles, prefetch order and timing: the EX's 16-bit bus and SMM-lengthened timings are not DX evidence. Hidden descriptor state is also not compared, since the real-mode set does not carry it.

## Measured behaviour fixed during this milestone

The first full replay passed 1,739,794 records. Each remaining class was traced to a 386 behaviour that the manual leaves unstated, and fixed as measured. Every fix cites its capture evidence in `spec/spec.md` section 3.3.

- **SIB with index 100b and a nonzero scale** scales the base register.
- **16-bit SHLD/SHRD with count > 16** uses the dest:src:src field (the source refills itself).
- **Shift and rotate OF** follows the final-result rules (MSB⊕CF for left shifts and rotates, MSB⊕MSB−1 for right ones). RCL/RCR with an effective count of zero still update OF. Byte SHL/SHR by 16 or 24 set CF as a shift by 8.
- **POPA** commits each register as it pops. **POPAD on a 16-bit stack** loads ESP[31:16] from the skipped slot. **PUSHA** writes bottom-up.
- **PUSHFD** clears VM, RF and the reserved bits. **32-bit POP Sreg** reads one word and releases a doubleword.
- **Interrupt delivery** reads the vector before pushing the frame.
- **DAS** keeps the low-nibble borrow in CF.
- **LOCK** is valid on 82h. An invalid LOCK raises #UD before the 15-byte #GP.

## Waived records (8)

`scripts/sst386_waivers.json` lists 8 records: taken `66 0F 8x` Jcc instructions whose target (1CF1h) lies inside the instruction itself. Each capture records **no change to any register or memory, EIP included**, although the test ends with an executed HLT, which always advances EIP. No execution of the instruction can produce that state, so these are treated as artifacts of the capture board's HLT injection on the re-fetched word. Each waiver is pinned by its upstream hash.

## Open discrepancies (20)

These records are not reproduced. The gate requires the failing set to equal `scripts/sst386_open.json` exactly.

| Files | Records | Observation | Status |
| --- | --- | --- | --- |
| F6.7, 67 F6.7 | 9 | IDIV r/m8 with a true quotient below −128 sometimes completes with AL = 80h and AH = (dividend + 128×divisor) mod 256, without #DE. Example: AX = 648Ch, divisor B7h. Most other negative overflows fault. | Selection rule not derived; needs more samples or a microcode-level model |
| D4 | 10 | AAM 0 raises #DE as expected, but SF/ZF/PF change to "PF only" or "none". The value does not follow from AL, AH or the prior flags. | Source unidentified |
| C2 | 1 | RET imm16 (BC90h) with SS = FFFFh: the captured SP (D56Ah) differs from SP + 2 + imm (18D8h), with EIP equal to the popped word | Unexplained single record |

## Unvalidated paths

The captures contain no records for these paths. They are implemented from the PRM, have no independent check yet, and are listed in the assumption ledger where they rely on assumptions:

- ESC D8–DF (A8)
- 0F00 (always #UD in real mode)
- 0F01 SGDT/SIDT/LGDT/LIDT/SMSW/LMSW (A9)
- 0F02/03 (#UD)
- 0F06 CLTS
- 0F20–23 MOV CR/DR
- LOADALL 0F07 (#UD in M1, which is incorrect for a real 386)
- LOCK on register forms (A10)
- the reset state (A6)

## Formal

- **Divider** (`formal/intel_80386_divider.sby`, W = 4). The prove task passes by induction: quotient×divisor + remainder = dividend and remainder < divisor at every completion. The cover task reaches a quotient above 15 and a maximal remainder.
- **ALU** (`formal/intel_80386_alu.sby`). The cover task passes. The 32-bit prove task under z3 was killed by the container's memory limit before finishing. It has to be rerun under the project image, or decomposed per operand size, before it counts as evidence.
- **Decoder.** A harness over an unconstrained 128-bit window ran z3 out of memory and was removed. The decoder is covered only by the replay for now.

## Synthesis

The core was restructured for synthesis: a single limit-check/base-add stage shared by every data access, one shared multiplier, and AAM on the iterative divider. Results of `scripts/run_synth.sh` are recorded below when available.

SYNTH_RESULT_PLACEHOLDER

## Limits

- **Function only.** No clock-for-clock timing, no bus-cycle equivalence, no electrical behaviour.
- **Oracle variant.** The oracle is a 386EX. Its internal I/O registers at 22h/23h are modelled in the bench fixture, not in the core.
- **Software gate.** AGENTS.md requires a real-software regression for CPU designs. None exists yet for the 386, so this milestone cannot be signed off as a complete CPU gate.
