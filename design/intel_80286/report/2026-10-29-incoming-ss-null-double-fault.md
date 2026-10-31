# Incoming SS null-selector #SS double-fault escalation

## Scope

Intel 80286 Programmer's Reference Manual, order 210498-005, Table 8-1 row 9
states that loading a null stack selector raises `#SS(0000)`. The row was
reviewed with Playwright CLI on printed page 8-6 (PDF page 156).

The protected task-entry regression now checks the post-transfer case where
the incoming TSS contains `SS=0000`. The processor first raises `#SS(0000)`;
the intentionally invalid vector-12 gate escalates this contributory fault to
null-error `#DF`. The regression then covers both invalid vector-8 shutdown and
successful delivery through a valid #DF task gate. Both paths run with READY
immediate and with READY stalls.

The four new escalation executions check the transferred task state, that no
GDT descriptor is read for the null selector, vector-12/vector-8 gate reads,
the #DF TSS image and backlink/busy state on successful delivery, the
null-error push, shutdown quiescence, and the exact handler successor.
The existing direct incoming-selector matrix independently checks the exact
first-fault vector and error code for this row.

## Verification

- `scripts/preflight.py` passes.
- The exact-source Verilator 5.052 `-Wall` runner build passes.
- Focused `--iopl-controls` regression passes, including four null-SS
  escalation executions and the 52-case incoming CS/SS/DS/ES matrix.
- Full `scripts/run_sim.sh` exits 0 with 188 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay passes all 79 cases in both READY modes.
- RTL is unchanged from the prior synthesis snapshot; the existing 13-target
  Yosys 0.69 synthesis remains applicable.

## Evidence

Evidence is in
`design/intel_80286/work/incoming_ss_null_double_fault_20261029_13/`.
The full run is `protected_mode_sim_20261029T014348Z`; its manifest records the
source files, Verilator/compiler versions, and replay result. SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `tb/bootstrap.cpp` | `318f45e708b7694130e86b7b821cdda002564585e28cb66ae80c79702fdb8862` |
| `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Full-run manifest | `365f2e5d4b9154e6da4ace0f9bb65a00cf3ffac2af1a98661832f288449c5c4a` |
| Full-run log | `0dd5bad8bdb5672a61493c18c9cd7b4aadc74e4cb7518b846687d4bcf9d5b55c` |
| Protected replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Playwright CLI source capture | `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91` |

## Remaining work

This is a directed task-entry fault checkpoint, not full CPU acceptance.
Current-source connected-core formal, authentic historical software running
on the RTL, remaining task-entry fault phases, and the complete release gate
remain open. The preserved whole-core PDR is still running on a different
source snapshot and is not current-source proof.
