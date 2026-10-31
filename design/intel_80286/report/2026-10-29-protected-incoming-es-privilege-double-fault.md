# Incoming-ES privilege `#GP` double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines validation of incoming task state. Table 8-1 row 16 rejects a
nonconforming incoming DS or ES descriptor whose DPL is below the maximum of
the incoming CPL and selector RPL. Playwright CLI reviewed the row on printed
page 8-6 (PDF page 156); the captured row is
[`table-8-1-row16.png`](../work/incoming_ds_privilege_double_fault_20261029_05/table-8-1-row16.png).

The incoming task runs at CPL 0 and loads ES selector `0023`. It names a
writable DPL-0 data descriptor but carries RPL 3, so `max(CPL,RPL) > DPL` and
post-transfer validation raises `#GP(0020)`. The existing incoming-segment
matrix checks the exact direct-fault packet. A malformed vector-13 handler
gate raises a second protection fault, selecting null-error `#DF`.

## Cases and observations

The `--iopl-controls` regression adds four executions: invalid-#DF-gate
shutdown and valid #DF task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the rejected descriptor at GDT offset
  `0020` is read, then checks vector-13 and vector-8 gate reads, the null-error
  #DF packet, original task context `CS:IP=0030:0300`, FLAGS `4202h`, SP
  `0080h`, and sticky shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the faulting incoming TSS with `ES=0023` and
  `DS=0010`, sets backlink and busy bits, and reaches the exact HLT successor
  `0030:0501`.

This adds the incoming-ES row-16 path beside the matching DS privilege case.
Other task-entry fault rows, complete #DF classification and whole-CPU
acceptance remain open.

## Verification

Preflight passes. The exact-source Verilator 5.052 `-Wall` runner build
passes, and focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 183 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so the prior
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_es_privilege_double_fault_20261029_08/`.
The protected replay run is
`protected_mode_sim_20261029T011122Z/`.

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `ad27e0fb83dfc6485a3902f6a847d70229518eb64c83b68142e9cde492de663f` |
| Runner fingerprint | `34ef89c3170d19f1cf4bf09aa36d89358798aeab5036d4452d4991ea0e0e6fe0` |
| Simulation binary | `19ecd79f80dd66399837df07d8ddf3ea5ec4bb6fb3f7a8e2c374e41f25dc0f1e` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `694eeda39e06ebfe06298a5f85eab3d648134301613364e7446452dd008528be` |
| `full_run.log` | `73f925890945a45fa2b030a1f4dd2cec60dde7e03c658bc82fafef3be6954da0` |
| `sim/build_manifest.json` | `a3cd3ea623608dd47ec93ae0c669ef3c2b7e6dab8a57f0b0bdaa036d2d96daa2` |
| Replay `build_manifest.json` | `fa096b7bdeea184844adaf272ce82365e4406a85511cd598e1184bbf0dd8cc07` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older source
snapshot and does not verify this current source. Current-source connected-core
proof and reachable covers, other task-entry fault phases, authentic
historical software, native timing qualification and whole-CPU release
acceptance remain open.

The checkpoint was posted and read back in
[issue comment 6485126780](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6485126780).
