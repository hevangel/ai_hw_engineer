# Incoming-ES #GP double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines post-transfer task-switch validation and double-fault handling.
Table 8-1 row 14 requires incoming DS/ES code segments to be readable.
Playwright CLI visually reviewed the complete table on printed page 8-6 (PDF
page 156); the capture is
[`table-8-1-rows14-15.png`](../work/incoming_es_gp_double_fault_20261029_03/table-8-1-rows14-15.png).

The incoming task uses selector `0030` as both CS and ES. Its access byte is
set to `98h`: present, DPL-0, execute-only code. The code descriptor is valid
for CS but not readable through ES, so the post-transfer segment check raises
`#GP(0030)`. A malformed vector-13 gate raises a second `#GP`, selecting
null-error `#DF` under the 286 rule.

## Cases and observations

The `--iopl-controls` regression adds four executions: malformed `#DF`-gate
shutdown and valid `#DF` task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the test confirms the execute-only descriptor is read, then
  checks the exact vector-13 and vector-8 gate reads, null-error #DF packet,
  original task context `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, and
  sticky shutdown over additional cycles.
- **Successful delivery:** a valid vector-8 task gate enters the #DF task,
  pushes a zero error word, saves the incoming faulting TSS with `ES=CS=0030`,
  sets backlink and busy bits, and reaches the exact HLT successor
  `0030:0501`. The #DF task uses readable DS/ES selector `0010`, independent
  of the execute-only incoming descriptor.

The existing incoming-segment matrix separately checks direct `#GP(0030)`
delivery for the same execute-only ES descriptor. This extension exercises
that fault source through both #DF outcomes; other Table 8-1 post-transfer
fault rows, full #DF classification and full task-entry acceptance remain
open.

## Verification

The container preflight and exact-source runner build pass with Verilator
5.052 `-Wall`. Focused `--iopl-controls` passes. The complete
`scripts/run_sim.sh` exits 0 with 178 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its protected replay manifest reports `PASS` for 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so existing
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_es_gp_double_fault_20261029_03/`. The replay
directory is `protected_mode_sim_20261029T004102Z/`.
The GitHub checkpoint was posted and read back in
[issue comment 6484652251](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6484652251).

| Artifact | SHA-256 / value |
|---|---|
| RTL `src/intel_80286.sv` | `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7` |
| Testbench `tb/bootstrap.cpp` | `69cf236ad859264cfb185878cf6b4ca977b8f1a70b8f7d9ebf6a9fcab18d2e5a` |
| Runner fingerprint | `7dd08cde56d8fc26eb82f83e7b596dd7dfdfce2cb968b396d6cb0a73c09ecbc4` |
| Simulation binary | `8a4081a3971d955f29da08955a9d260f9773e8b4184d3f3cec5afa70d76aa750` |
| `preflight.log` | `620391f4b26b482a0626e56663440ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `a9ac600967d025b48b238f00eb6ec312e1d791336861e565cd3ae57217010654` |
| `full_run.log` | `185424e0476be62046fe3ba324223cf575b2ca01b8abdff914596d2f7eed82e3` |
| `sim/build_manifest.json` | `7a2229c0403ee1d9772f4e1245dcf651b17d76117949ab67c54bb449e9bb5f88` |
| Replay manifest | `060513d94a63475ad8b20bad0c1e622228009a66c42d72c43cfaf21252451c16` |
| Replay log | `1d68741ffd6a53dba2b3bc30cb5fa0679ef542b42bd98fe6529b80ec12e02fb7` |
| Table capture | `4196cca01846781b19e29f55df7841c62070b4b31e3d29b93b94a980f2082e68` |

## Remaining limits

The separate whole-core ABC PDR still runs against its earlier source snapshot;
it does not verify this current source. Current-source connected-core proof and
reachable covers, other task-entry fault phases, authentic historical
software, native timing qualification and whole-CPU release acceptance remain
open.
