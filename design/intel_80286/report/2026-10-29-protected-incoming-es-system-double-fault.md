# Incoming-ES system-descriptor #GP double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling.
Table 8-1 row 13 requires incoming DS/ES selectors to name valid code or data
descriptors; a system descriptor is invalid and raises `#GP(selector)`.
Playwright CLI visually reviewed the complete table on printed page 8-6 (PDF
page 156); the capture is
[`table-8-1-rows13-15.png`](../work/incoming_es_type_double_fault_20261029_04/table-8-1-rows13-15.png).

The incoming task uses selector `0050` as ES. It names a busy 286 TSS system
descriptor, so the post-transfer check raises `#GP(0050)`. The malformed
vector-13 gate raises another `#GP`, selecting null-error `#DF` under the
286 rule.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the system descriptor is read, then checks
  the exact vector-13 and vector-8 gate reads, null-error #DF packet, original
  task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and sticky
  shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the incoming faulting TSS with `ES=0050`,
  sets backlink and busy bits, and reaches the exact HLT successor
  `0030:0501`. The #DF task uses valid DS/ES selector `0010`.

The incoming-segment matrix separately checks direct `#GP(0050)` delivery for
an ES system descriptor. This extension exercises that fault source through
both #DF outcomes; other Table 8-1 post-transfer fault rows, full #DF
classification and full task-entry acceptance remain open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 179 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_es_type_double_fault_20261029_04/`. The replay
directory is `protected_mode_sim_20261029T004538Z/`.
The GitHub checkpoint was posted and read back in
[issue comment 6484718375](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484718375).

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `da47b7e252b2ce47457d7e5cb6068fc43598fcc6ae5a1c8a027ede16188692de` |
| Runner fingerprint | `11629c2e7082f13d1cff6b689ae81d883212269821f28e2be1fa481306aabea2` |
| Simulation binary | `e2a0f1db4da39d6ace0b7798911c86e69aede0d5044dfb7267eb9b3f034435bf` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `7bb1ce797e0c8e51f7e792076350b2d8bc21c7bb114efc28d252e7d19e8e64c5` |
| `full_run.log` | `883dad92a29908173a80529eef593c6cf3dd5678542aa017873c1b08c2ff649d` |
| `sim/build_manifest.json` | `10968e454058a77aae42f968e93be7abb9e61bb620d129cc48c8941010976240` |
| Replay manifest | `15a052753d522d5f49273ebf9952d195c7e783af28ec995f91093e28c9c71911` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR still runs against its earlier source snapshot;
it does not verify this current source. Current-source connected-core proof and
reachable covers, other task-entry fault phases, authentic historical
software, native timing qualification and whole-CPU release acceptance remain
open.
