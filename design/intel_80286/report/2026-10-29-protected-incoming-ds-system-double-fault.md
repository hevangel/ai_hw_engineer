# Incoming-DS system-descriptor `#GP` double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling. Table
8-1 row 13 requires the incoming DS/ES selector to name a code or data
descriptor; a system descriptor raises `#GP(selector)`. Playwright CLI
reviewed the table on printed page 8-6 (PDF page 156); the capture is
[`table-8-1-rows13-15.png`](../work/incoming_ds_system_double_fault_20261029_07/table-8-1-rows13-15.png).

The incoming task loads DS selector `0050`, which names a system TSS
descriptor. Post-transfer validation raises `#GP(0050)`. Its malformed
vector-13 handler gate raises a second `#GP`, selecting null-error `#DF`. The
existing direct incoming-selector matrix checks the exact DS system-descriptor
`#GP(0050)` packet.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms selector `0050` is read as a GDT descriptor,
  then checks the vector-13 and vector-8 gate reads, null-error #DF packet,
  original task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and
  sticky shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the incoming faulting TSS including
  `DS=0050`, sets the backlink and busy bits, and reaches the exact HLT
  successor `0030:0501`. The #DF task uses valid DS/ES selector `0010`.

This extends the direct Table 8-1 DS system-descriptor fault through both #DF
outcomes. Other task-entry fault rows, complete #DF classification and full
task-entry acceptance remain open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 182 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_ds_system_double_fault_20261029_07/`. The
replay directory is `protected_mode_sim_20261029T010505Z/`.

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `cadc04ac7d89abf3f817dcc3c4d8dfa9584b8f4c7595455d8a5cc27ba6035580` |
| Runner fingerprint | `488c8adc41da02ecae9568dd1bfda695793b54fb6ffc2fe618f8e1bd3d8ddf79` |
| Simulation binary | `6f744110314eefe8232d69a145cdc7ca5efef0feb7a5964f99d35e45a8a84000` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `e676a9e1985214716252454b9fafc728a45efb2f8f396fc7a5c4e80a6139baf9` |
| `full_run.log` | `ef009638c8eb67477b5b6014f8da99edcf008bf01924ae34363704c640d7c459` |
| `sim/build_manifest.json` | `7a508da55bcb90d010b5096f186e9e25e4cf7a32da8827fb19dee51c6928a4db` |
| Replay manifest | `35e37914487f8dfa12eee570884e8505687965a7c460bcf7b138e063d8852543` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older source
snapshot and does not verify this current source. Current-source connected-core
proof and reachable covers, other task-entry fault phases, authentic
historical software, native timing qualification and whole-CPU release
acceptance remain open.
