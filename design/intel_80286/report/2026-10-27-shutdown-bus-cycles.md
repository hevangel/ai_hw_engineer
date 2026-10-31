# HALT/shutdown bus-cycle indications and task-switch reset cuts

**Date:** 2026-10-27 14:11 UTC  
**Scope:** distinguish HLT from protected shutdown at the bus abstraction and
check reset during nested #DF task-gate entry and task IRET  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)

## Contract and implementation

Intel's [80286 Hardware Reference Manual, order 210760-002, §3,
“HALT/SHUTDOWN CYCLES”](https://bitsavers.org/components/intel/80286/210760-002_80286_Hardware_Reference_Manual_1987.pdf)
specifies a special local-bus operation with `S1:S0=00`, `COD/INTA=0`, and
`M/IO=1`; address A1 distinguishes HLT (1) from shutdown (0). The operation
does not wait for READY. The 286 exits shutdown on NMI or RESET, and ignores
INTR, as described in Intel's [Programmer's Reference Manual,
§11.6](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf).

The byte-transaction interface now exposes `bus_halt_cycle_o` while the HLT
latch is active and `bus_shutdown_cycle_o` while shutdown is active. The
outputs are mutually exclusive, do not assert a normal byte request, and do
not depend on `bus_ready_i`. They preserve the HLT/shutdown distinction at
this interface boundary. Raw status, A1 and ALE pins are not modeled.

The protected `--iopl-controls` regression now resets the CPU after every
accepted data transfer from nested #DF task-gate lookup through incoming
handler commit: 117 transfer cut points in each READY policy, 234 total. Each
cut checks that RESET clears the event packet and special-cycle outputs, then
executes an exact HLT at the reset vector. The task-IRET regression also cuts
after every accepted data transfer from the #DF handler task back to the
interrupted task: 90 transfer positions in each READY policy, 180 total. It
checks reset cleanup, reset-vector HLT replay and the fixture's interrupted
CS identity. Together, entry and return cover 414 accepted-transfer reset
cuts; other task-switch phases and the complete nested-fault matrix remain
open.

## Verification

The focused `--iopl-controls` regression passes, including 480 protected
privilege scenarios, shutdown NMI recovery, 234 task-gate entry cuts and 180
task-IRET cuts. The full default Verilator bootstrap passes. Strict Verilator
5.052 `-Wall` lint and release preflight pass on the unchanged RTL/property
snapshot. Yosys 0.69 completes full-core synthesis;
`check -assert` reports zero problems. The synthesized design contains 49,771
cells across the core and 11 submodules.

The pre-bus current-core BMC epoch was stopped while still incomplete at frame
17; it produced no terminal result and is not evidence for this implementation.
A fresh current-source connected-core BMC at depth 24 is running in
`work/formal_runs/shutdown_bus_core_20261027_01/intel_80286_bmc/`; its last
recorded progress is frame 10 and it has no terminal result. Connected-core
prove/cover/PDR and aggregate audit remain open.

Reproducible commands and retained logs:

```text
python3 scripts/build_runner.py                                      PASS
work/sim/Vintel_80286 --iopl-controls                                PASS
work/sim/Vintel_80286                                                PASS
verilator --lint-only -Wall --top-module intel_80286 src/*.sv        PASS
python3 scripts/preflight.py                                         PASS
yosys -Q -l work/synth_shutdown_bus_20261027_01/intel_80286.log ...  PASS
sby intel_80286.sby bmc (depth 24)                                   RUNNING
```

Focused and full-bootstrap logs are under
`work/shutdown_bus_20261027_01/`, including
`iopl_controls_task_iret.log` and `bootstrap_task_iret.log`. The runner
manifest is under `work/sim/`;
synthesis JSON, log and input hashes are under
`work/synth_shutdown_bus_20261027_01/`; the formal input hashes and live BMC
logs are under `work/formal_runs/shutdown_bus_core_20261027_01/`.

| Artifact | SHA-256 / count |
|---|---|
| Core RTL | `50f13319c5ab0db29546f7a0b7fd434544837bc531e46fe8b9fafbb44ad1a8c8` |
| Core properties | 309 assertions, 1 assumption, 52 covers; SHA-256 `85baefefc8950c0d7dee8df2c9c2f7616a43769ea682ee666a46d560dc5e1eb6` |
| Reviewed property inventory | SHA-256 `6eede75fc179430056330696dcc2f5b6f4b30a78af14cbfa292127825daf0c69` |
| CPU testbench | SHA-256 `30a3229168edc5a62c1544b08d43eccbc1d34d724726f284c1825c6d96d80340` |
| Verilator runner fingerprint | `5d486e5d26d41d4b5eabf8973bf234d9ac5a5f5e9565331d69780bf74a57eb59` |
| Verilator runner binary | SHA-256 `c93d825e0a196cfa828071caf22d0202252d9104bbc99e366e22a230e723c41a` |
| Synthesized JSON | SHA-256 `ffa34e5515717f92eaabf1482d701a78d809f2db42e44986f28c46fb3654d5d6` |
| Synthesis source manifest | SHA-256 `38e6553c04789f125e5f238acb4ef16f118a3f5be31bdd98887cfdd37f2e8f8e` |
| Tools | Verilator 5.052, g++ 15.2.0, Yosys 0.69, SymbiYosys 0.70 |

## Remaining limits

This change identifies special HALT and shutdown cycles at the current
transaction abstraction; it does not implement raw 80286 bus pins. The reset
cuts cover accepted data transfers during task-gate entry and task IRET, not
every task-switch phase. The connected-core formal run has no terminal result,
and the full #DF matrix, independent OS/2 CPGREP execution, broad ISA coverage
and full release gate remain open. Full 80286 completion is not claimed.
