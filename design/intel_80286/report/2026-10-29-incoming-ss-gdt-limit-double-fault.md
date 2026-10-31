# Incoming SS GDT-limit #SS double-fault escalation

## Scope

Intel 80286 Programmer's Reference Manual, order 210498-005, Table 8-1 row 9
requires a valid stack selector. Printed page 8-6 (PDF page 156) was reviewed
in Chrome with Playwright CLI; the source capture is retained with the run
evidence. [Scanned Intel manual, page 156](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

The incoming task uses GDT limit `0187` and SS selector `0188`, just beyond
that limit. The expected first fault is `#SS(0188)`. The direct
incoming-selector matrix already checks the exact vector and selector error;
four new post-transfer executions drive the first fault through a malformed
vector-12 gate, then cover both invalid vector-8 shutdown and valid #DF
task-gate delivery with READY immediate and stalled.

The tests check that no descriptor read crosses the GDT limit, both gate
lookups, the null-error #DF packet, the faulting TSS image with `SS=0188`,
backlink/busy state and null error push on successful task delivery, shutdown
quiescence, and the exact handler successor.

## Verification

- `scripts/preflight.py` passes.
- The exact-source Verilator 5.052 `-Wall` runner build passes.
- Focused `--iopl-controls` regression passes, including four SS GDT-limit
  escalation executions.
- Full `scripts/run_sim.sh` exits 0 with 190 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay passes all 79 cases in both READY modes.
- RTL is unchanged from the prior synthesis snapshot; the existing 13-target
  Yosys 0.69 synthesis remains applicable.

## Evidence

Evidence is in
`design/intel_80286/work/incoming_ss_gdt_limit_double_fault_20261029_15/`.
The protected replay is `protected_mode_sim_20261029T015811Z`. SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `tb/bootstrap.cpp` | `6ce6bee8c49feee9e7ab97e1c24cd7242f46fcd3cae8bcf339292da3d298e19c` |
| `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Runner build manifest | `7cb6d30943e6e6bba28425a323b0b60c46ba3337638bc4992aff011729c432bb` |
| Protected replay manifest | `19481a828acd1d1c5433adf3aed3750808a53db867ee503f090e782dead30688` |
| Full-run log | `c758f8fa91563922e5d87b24526d69aa9d400240b7f7482ff168919c07de5f17` |
| Focused log | `9a28a1cbf06b96bccc8ea73f2564d987b51762634ac43e2e4ba3fe91a06574ab` |
| Protected replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Playwright CLI source capture | `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91` |

## Remaining work

This closes one row-9 selector-limit escalation case, not all 80286 task-entry
or CPU acceptance requirements. Other selector variants, remaining task-entry
fault phases, current-source connected-core formal, authentic historical
software on the RTL, and the complete release gate remain open. The preserved
whole-core PDR remains active on a different source snapshot and is not
current-source proof.

## Exact-boundary fixture follow-up

The 2026-10-29 02:22 UTC fixture audit found that the shared incoming-task
helper had placed `0187` in IDTR.limit while leaving GDTR.limit at `007F`.
The earlier selector-`0188` execution was out of bounds but not exactly one
byte beyond the claimed limit. The helper now configures GDTR.limit as `0187`;
the corrected focused and full regressions re-run this SS `#SS(0188)` case
along with the CS and DS/ES limit cases. See the corrected
[DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md).
