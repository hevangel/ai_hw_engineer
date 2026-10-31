# Incoming-DS `#NP` double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling. Table
8-1 row 15 requires the incoming DS/ES descriptors to be present; a missing
segment raises `#NP(selector)`. Playwright CLI reviewed the full table on
printed page 8-6 (PDF page 156); the evidence capture is
[`table-8-1-row15.png`](../work/incoming_ds_np_double_fault_20261029_06/table-8-1-row15.png).

The incoming task loads DS selector `0010`, a writable DPL-0 data descriptor
with its present bit cleared (`access=12h`). Post-transfer validation raises
`#NP(0010)`. Its malformed vector-11 handler gate raises `#GP`, selecting
null-error `#DF`. The existing direct incoming-segment matrix also checks the
exact `#NP(0010)` packet.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the non-present DS descriptor is read, then
  checks the vector-11 and vector-8 gate reads, null-error #DF packet, original
  task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and sticky
  shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the incoming faulting TSS including
  `DS=0010`, sets the backlink and busy bits, and reaches the exact HLT
  successor `0030:0501`. The #DF task uses valid DS/ES selector `0020`.

This extends the direct Table 8-1 DS presence fault through both #DF outcomes.
Other task-entry fault rows, complete #DF classification and full task-entry
acceptance remain open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 181 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_ds_np_double_fault_20261029_06/`. The replay
directory is `protected_mode_sim_20261029T005749Z/`. The GitHub checkpoint was
posted and read back in
[issue comment 6484884414](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484884414).

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `56caafadcf3712dbebba5069a2bac140d45d1eacc164860054dcbfae4614027f` |
| Runner fingerprint | `e1d4fcb3e125346ad9bcb84bfdb70b4f27fbb0136562036732b0fdc57dbfbce8` |
| Simulation binary | `3817c9df99bfa741b6725982609cc52b806708b7088e91f5a2ab7e908b782495` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `c244f6119f831ea1339da2783951214c927181d539cd7e8a5b9c01898e9ec5b2` |
| `full_run.log` | `2092fe3240fc4e0f8601459c3e356b5a239e0456790bc5346e2148e093b5d4f9` |
| `sim/build_manifest.json` | `b2c45cb8717e1afb1456a2a1bfbe7fee2773cc3b8fa00b31c74eaa650d0e577b` |
| Replay manifest | `3e0400aa3f240a793ce653f45afc7bec4f1acd63a416d38882d9d7ea79a1cc3b` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older source
snapshot and does not verify this current source. Current-source connected-core
proof and reachable covers, other task-entry fault phases, authentic
historical software, native timing qualification and whole-CPU release
acceptance remain open.
