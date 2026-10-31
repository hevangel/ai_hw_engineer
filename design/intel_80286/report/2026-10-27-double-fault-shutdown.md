# Protected double-fault shutdown checkpoint

**Date:** 2026-10-27 13:10 UTC  
**Scope:** qualifying handler-gate escalation and shutdown during protected #DF delivery  
**Issue:** [hevangel/ai_hw_engineer#80 checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6442740201)

## Behavior and implementation

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
says a second protection violation while processing exception 8 enters
shutdown. Shutdown processes no further instructions or exceptions; RESET
leaves it. The manual also describes a special external HALT bus operation
during shutdown.

The core now exposes sticky `shutdown_o`, asserts `halted_o`, suppresses new
bus requests and holds the shutdown state until reset. It routes these
protected #DF-delivery failures to shutdown: vector-8 IDT-limit overflow,
invalid/non-present vector-8 gates or non-task gate types, task-gate selector
and target-TSS admission faults, and incoming task LDTR/segment/code
validation faults. Existing valid #DF task-gate entry and task IRET remain
covered. The current byte-transaction bus abstraction has no external HALT
cycle encoding, and NMI wake from shutdown is not implemented.

Gate validation now also escalates an invalid handler gate to #DF when the
first restartable protected exception is #DE, #TS, #NP, #SS or #GP. The new
directed #DE case executes DIV-by-zero, reads the invalid vector-0 gate, then
reads the vector-8 gate; it verifies that the original CS:IP:FLAGS:SP remain
saved in the null-error #DF packet before the invalid #DF gate enters shutdown.

## Evidence

The focused `--iopl-controls` regression passes in immediate and stalled READY
modes. Its five failure categories run under both modes and verify shutdown,
halted status, no diagnostic fault, no retirement and no pending bus request:

- An invalid vector-8 gate is read exactly once, with no stack frame writes.
- A vector-8 IDT-limit violation performs no out-of-bounds descriptor read.
- DIV-by-zero plus an invalid #DE gate escalates to #DF, then shuts down on
  the invalid #DF gate after exactly the vector-0 and vector-8 gate reads.
- A not-present task-gate target TSS is read without task-switch writes.
- An invalid incoming LDTR reaches shutdown after the task-switch busy and
  backlink effects, without dispatching a nested #TS handler.

The all-zero #DF gate cases remain quiescent over additional cycles, then reset and
verify that shutdown clears. The successful #DF task-switch/IRET regression,
valid non-null LDT entry, null-selector variants and the other protected
privilege matrices also pass. The full default bootstrap passes.

Commands and evidence:

```text
python3 scripts/preflight.py                                      PASS
verilator --lint-only -Wall --top-module intel_80286 src/*.sv       PASS
python3 -c "build_runner.build_or_reuse(work=...)"                  PASS
work/shutdown_20261027_05/Vintel_80286 --iopl-controls              PASS
work/shutdown_20261027_05/Vintel_80286                              PASS
```

The runner was built with `scripts/build_runner.py`'s `build_or_reuse()` using
`work/shutdown_20261027_05/`, in the Verilator container from the design
directory. Logs and `build_manifest.json` are under
`design/intel_80286/work/shutdown_20261027_05/`.

| Artifact | SHA-256 / count |
|---|---|
| RTL `src/intel_80286.sv` | `e6429782c310eed0f6ac724f6e6598923bb758834bf027f64b757b7b6a6c72d9` |
| Testbench `tb/bootstrap.cpp` | `74579ba5384517347cb8153b24f83cdefa69bffcff107ee892c33ae1cb717e64` |
| `formal/intel_80286_props.sv` | 302 assertions, 1 assumption, 50 covers; SHA-256 `9c4a383bd7591bbd734f9050bd4af8d935bfc54dcfce5ad2838af4b552a3a50a` |
| `formal/property_inventory.json` | SHA-256 `ada195f001f283c532e4376a6de36738b15a52d024a4c70ae8e5dbff779e78de` |
| Built runner | `7b4f1dc73505bdc0ff459d906ab76f0fb8b7705f0c07fd67dd640462dbf093e2` |
| Build fingerprint | `e0b13ef5d453fc03a40c9f5a406caa99fcb2ab947b773d5b71524b0d3e9c1993` |

## Remaining work

This is a bounded shutdown implementation, not complete 286 exception closure.
The full #DF-generation matrix and additional faults at every delivery phase
need independent cases. Add the 286 NMI wake/re-shutdown behavior, model the
external shutdown HALT bus cycle in the bus contract, and add reset cuts and
connected-core formal properties for task-switch/shutdown state. No
current-source connected-core proof has evaluated this checkpoint; the older
`_21` cover/PDR jobs use prior snapshots. Full-chip acceptance remains open.
