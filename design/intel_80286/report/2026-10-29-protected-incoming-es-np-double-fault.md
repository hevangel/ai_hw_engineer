# Incoming-ES #NP double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling. Table
8-1 row 15 requires incoming DS/ES descriptors to be present; an absent
segment raises `#NP(selector)`. Playwright CLI visually reviewed the complete
table on printed page 8-6 (PDF page 156); the capture is
[`table-8-1-row15.png`](../work/incoming_es_np_double_fault_20261029_02/table-8-1-row15.png).

The test sets incoming ES to GDT selector `0020`, a writable DPL-0 data
descriptor with its present bit cleared (`access=12h`). The post-transfer
fault is `#NP(0020)`. Its malformed vector-11 gate raises a second protection
fault, which selects null-error `#DF`.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the ES descriptor is read, then checks the
  exact vector-11 and vector-8 gate reads, null-error #DF packet, original
  task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and quiescent
  sticky shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the incoming faulting TSS including
  `ES=0020`, sets the backlink and busy bits, and reaches the exact HLT
  successor `0030:0501`. The #DF task uses the still-valid DS/ES selector
  `0010`, isolated from the intentionally non-present incoming ES descriptor.

This extends the direct incoming-segment matrix, which already exercises
Table 8-1 row 15, through both #DF outcomes. Other post-transfer fault rows,
full #DF classification and the full task-entry contract remain open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 177 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_es_np_double_fault_20261029_02/`. The replay
directory is `protected_mode_sim_20261029T003402Z/`.
The GitHub checkpoint was posted and read back in
[issue comment 6484561385](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484561385).

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `1f0d9a8596521a0eddc4c1a12bc08b4c006c8d959f65fa0373d5d2de262eac38` |
| Runner fingerprint | `b9e673dddbece3182eac9efd2dffd27f8d46616e4282d7bdb04072bedbfe7a2b` |
| Simulation binary | `b02392dacf4d130da31e58e35ff040f4774b235721fa0376e7d3a87e0d2709a8` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `4062969bc4959a5364df58077f17eefdddd14e2931e8a2a7a51e77b744ef2c68` |
| `full_run.log` | `e29a274846b146ca4b51608d32caae654667cb7908b72d468883cdb0f2e03889` |
| `sim/build_manifest.json` | `5dcc0f18311c5ee710d3cd7098e6aab86da229cbc55bbd52944ad07341281bd1` |
| Replay manifest | `b63eae20a8086a54d2b64bb04bde5a8f4de163245e44bc892f0862befc9d009f` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR still runs against its earlier source snapshot;
it does not verify this current source. Current-source connected-core proof and
reachable covers, other task-entry fault phases, authentic historical
software, native timing qualification and whole-CPU release acceptance remain
open.
