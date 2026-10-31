# Incoming-DS privilege #GP double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling.
Table 8-1 row 16 requires a nonconforming incoming DS descriptor's DPL to be
no greater than the incoming CPL. Playwright CLI visually reviewed the row on
printed page 8-6 (PDF page 156); the capture is
[`table-8-1-row16.png`](../work/incoming_ds_privilege_double_fault_20261029_05/table-8-1-row16.png).

The incoming task runs at CPL 0 and loads DS selector `0013`, which names a
DPL-0 writable data descriptor but carries RPL 3. Since `max(CPL,RPL) > DPL`,
the post-transfer validation raises `#GP(0010)`. A malformed vector-13 gate
raises another `#GP`, selecting null-error `#DF` under the 286 rule. The
existing incoming-segment matrix checks the direct fault's exact `#GP(0010)`
packet.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the rejected DS descriptor is read, then
  checks the exact vector-13 and vector-8 gate reads, null-error #DF packet,
  original task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and
  sticky shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the faulting incoming TSS with `DS=0013`,
  sets backlink and busy bits, and reaches the exact HLT successor
  `0030:0501`. The #DF task uses valid DS/ES selector `0010`.

This extends the direct Table 8-1 DS privilege fault through both #DF outcomes.
Other task-entry fault rows, complete #DF classification and full task-entry
acceptance remain open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 180 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_ds_privilege_double_fault_20261029_05/`. The
replay directory is `protected_mode_sim_20261029T004902Z/`.

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `44a8144aba13296a9542f6e8c5537057f34daaf602dd74b214393cd61d490fdf` |
| Runner fingerprint | `277b58d88777adee3c88adcab19b9adc184ccd06b1d6fdb931aebc954f1e7eee` |
| Simulation binary | `beda796f0167f557b349cab75dafab4b7981e0b498865469a9f572f49d1924e6` |
| `preflight.log` | `620391f4b26b482a0626e5666340ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `0859160d9df1276c80b6b01ae0230590fb39ca936aa0050f5179e406adb46ba9` |
| `full_run.log` | `f5ad24ba3a8257dab828c1832fd834b64ce8caf6d3ae8a17d4113acca0ee5f0f` |
| `sim/build_manifest.json` | `0c16e09f9510d07161a8bbfcd20eaa8e21e12f5634125937bc22f4636df8f86d` |
| Replay manifest | `922006e81f9bfb59faff9b69c24a6c2e4918975867fad9d7d8b20d29cfaf3ee6` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older source
snapshot and does not verify this current source. Current-source connected-core
proof and reachable covers, other task-entry fault phases, authentic historical
software, native timing qualification and whole-CPU release acceptance remain
open.
