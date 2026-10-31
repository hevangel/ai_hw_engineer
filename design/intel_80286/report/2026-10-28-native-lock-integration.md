# Native CPU LOCK integration — 2026-10-28

**Checkpoint:** 07:13 UTC  
**Branch/worktree:** `design/intel-80286`, `B:\ai_hw_engineer\worktree\intel-80286`  
**Status:** core LOCK intent is wired to the native bus pins and covered by directed and full simulation. Yosys 0.69 synthesis completed all 11 targets for this checkpoint; the later 82288 integration and 12-target synthesis are recorded in the [controller report](2026-10-28-82288-local-controller.md).

## Implementation

`intel_80286` now exports the active-high `bus_lock_o` intent. The connected
`intel_80286_native_cpu` wrapper wires it to the bus controller's `lock_i`;
the controller drives active-low `LOCK#` and blocks a HOLD grant while lock is
active. The core separately tracks the F0 prefix and its operand lock window,
so the request includes data accesses and internal gaps without locking
instruction fetch.

Implemented operation paths are explicit LOCK-prefixed memory MOV, MOVS, INS,
OUTS and rotate-memory forms, plus implicit memory XCHG. REP string operations
keep the lock across all iterations. The source basis and the distinction
between LOCK-prefix coverage and automatic hardware locks are in
[`native_bus_interface.md`](../spec/native_bus_interface.md). Descriptor-table
and processor-extension automatic lock cases, complete prefix legality and
privilege behavior are not implemented by this checkpoint.

## Verification

Tools: Verilator 5.052 from `ai-hw-engineer:latest`.

The focused pin-level test passed and checked:

- LOCK XCHG `[BX],AX`, explicit LOCK MOV load/store, explicit LOCK ROL on
  memory, unlocked MOV load and implicit memory XCHG. The test checks the
  stored `1234h`, rotated `2468h` and final exchanged `5678h` values.
- LOCK across the read/write and internal gaps, two iterations each of
  `REP LOCK MOVSB`, `REP LOCK INSB` and `REP LOCK OUTSB`, and READY waits on
  both memory and I/O cycles.
- `REP LOCK INSB` returns `ABh` from port `0070h` to memory `0610h/0611h`;
  `REP LOCK OUTSB` reads `5Ah/C3h` from `0410h/0411h` and writes the odd-port
  high data lane at `0071h`. LOCK remains active on each memory and I/O beat.
- No HOLD grant during locked operand gaps, HOLD grant after lock release,
  and inactive LOCK during instruction fetch.
- Even/odd word lanes, two-cycle INTA with its hardware lock, interrupt frame,
  and exact IRET return to HLT.

Retained focused-test result:
`work/native-lock-candidate-20261028/native_cpu_sim/run.log`.
SHA-256: `EF015990561176264786D2487410B6509FF79E2B86ECFAE44F741AC79A799CB9`.

The full `run_sim.sh` command completed with exit code 0 and 141 PASS lines,
including the connected pin test and all 79 protected-mode replay cases. The
protected replay manifest reports `result: PASS` and 79 passed cases in both
unstalled and READY-stalled modes:

`work/native-lock-candidate-20261028/protected_mode_lock_20261028T0708Z/build_manifest.json`

Manifest SHA-256:
`0504A7548B9CCC117D3CD161DE618DEEB94583310938CDC9F729A22218F62DBF`.
Replay-log SHA-256:
`1D68741FFD6A53DBA2B3BC30CB5FA0679EF542B42BD98FE6529B80EC12E02FB7`.

Reproduction, from the mounted worktree inside `ai-hw-engineer:latest`:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/native-lock-candidate-20261028 \
  sh design/intel_80286/scripts/run_native_cpu.sh

INTEL_80286_WORK_DIR=/work/design/intel_80286/work/native-lock-candidate-20261028 \
  sh design/intel_80286/scripts/run_sim.sh

INTEL_80286_WORK_DIR=/work/design/intel_80286/work/native-lock-candidate-20261028 \
  sh design/intel_80286/scripts/run_synth.sh
```

Yosys 0.69 `run_synth.sh` completed all 11 targets. Every target log ended
normally, has three `Found and reported 0 problems` checks, and contains no
`ERROR:`. The integrated `intel_80286_native_cpu` target reports 50,003 generic
cells. Logs and synthesized JSON netlists are retained under
`work/native-lock-candidate-20261028/synth/`. The integrated wrapper log
SHA-256 is
`87C6D86EF2AACF8FDB7E50B34E047D30E5203F0649504EA91EF50532EF6FE632`.

GitHub issue #80 was updated and read back at
[comment 6463032004](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6463032004).

## Source identity

| File | SHA-256 |
|---|---|
| `src/intel_80286.sv` | `71EBADCE9B7AE4EBEFF104274254B938424FA9FCA8AA2F171DCA34A18109C7C5` |
| `src/intel_80286_native_cpu.sv` | `15F87C6FE4C12405C5A80FBE4C77AFBD86A3D035AD3301F68B91BE6E58D7D6DB` |
| `tb/native_cpu.cpp` | `BB7CE3787E533B25285108E9DB65C76B43C4D248E1ADDFE20540E717BEF4DFAC` |
| `spec/native_bus_interface.md` | `032F6B75A9A1C89F5C0F5DBF1FA5C2FF793E29D5DC2CF4C4265C5BAB28D2604D` |

## Remaining work

This is a modeled processor-clock pin boundary, not a complete 80286 hardware
implementation. External CLK division and RESET timing, the 82288 command/ALE
component, 80287 signaling, automatic descriptor and coprocessor locks,
current-source connected-core formal closure, an independent instruction
trace, CPGREP on RTL, and the complete `run_all.sh` release gate remain open.
The old cover result ended with SBY `ERROR`/rc=16 and 45/73 reached goals; it
predates native-beat RTL. The corrected depth-12 induction result remains
UNKNOWN. Issue #80 remains Open/Building with Agent Codex, Path
`ai_hw_engineer/design/intel_80286`, first Start date `2026-10-23` and Sprint 1.

