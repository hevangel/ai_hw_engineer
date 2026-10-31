# Incoming CS DPL/RPL #TS double-fault escalation

## Scope

Intel 80286 Programmer's Reference Manual, order 210498-005, Table 8-1 row 8
requires the incoming code segment DPL to match the incoming CS selector RPL.
The row was reviewed with Playwright CLI in Chrome on printed page 8-6 (PDF
page 156); the captured source is retained with the run evidence. See the
[scanned Intel manual, page 156](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156).

The directed task-entry case uses incoming `CS=0038`: its selector has RPL 0,
while the present nonconforming code descriptor at GDT selector `0038` has
DPL 3. The expected first fault is `#TS(0038)`. The direct incoming-selector
matrix already checks that exact vector and selector error in both READY
modes. Four new post-transfer executions drive that first fault through a
malformed vector-10 gate and cover both invalid vector-8 shutdown and valid
#DF task-gate delivery, each with READY immediate and stalled.

The tests check the rejected code descriptor read, vector-10/vector-8 gate
lookups, null-error #DF packet with the faulting CS context, transferred TSS
image, backlink and busy state on successful delivery, null error push,
shutdown quiescence and the exact #DF handler successor.

## Verification

- `scripts/preflight.py` passes.
- The exact-source Verilator 5.052 `-Wall` runner build passes.
- Focused `--iopl-controls` regression passes, including the four new CS
  DPL/RPL escalation executions.
- Full `scripts/run_sim.sh` exits 0 with 189 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay passes all 79 cases in both READY modes.
- RTL is unchanged from the prior synthesis snapshot; the existing 13-target
  Yosys 0.69 synthesis remains applicable.

## Evidence

Evidence is in
`design/intel_80286/work/incoming_cs_dpl_double_fault_20261029_14/`.
The protected replay is `protected_mode_sim_20261029T015140Z`; its manifest
binds the replay to the source files, toolchain and binary. SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `tb/bootstrap.cpp` | `229026b39dff5b7859546c60a6c3f04d5317f3b529b45e5d70c92e5d478c2da7` |
| `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Runner build manifest | `cb467cba7a49d57c95b99e4feafd8f422536a23c632e9a44a0cab9ffa0345960` |
| Protected replay manifest | `bfee210da0c6c0c02486343817af8c3fb7188b9eeddfc026faf98aeeb5766ac6` |
| Full-run log | `aad50880456fe01bb4651327c2cf7d2311f78a692a210d3a4231b4699091ef59` |
| Focused log | `261aec8b2f8697dbdb35ad5921370e0bd8ecc3fad5187812e190cca830354016` |
| Protected replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Playwright CLI source capture | `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91` |

## Remaining work

This is directed incoming-task validation, not complete 80286 acceptance.
The broader Table 8-1 gap audit, remaining task-entry fault phases,
current-source connected-core formal, authentic historical software on the
RTL, and the full release gate remain open. The preserved whole-core PDR is
still active on a different source snapshot and is not current-source proof.
