# Incoming-CS #NP double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines task-switch validation and 286 double-fault handling. Table 8-1 row 7
requires the incoming code segment to be present; a non-present code descriptor
raises `#NP(selector)`. Playwright CLI visually confirmed row 7 on printed
page 8-6 (PDF page 156); the captured source page is
[`table8-1-row6-7.png`](../work/incoming_cs_np_double_fault_20261029_01/table8-1-row6-7.png).

The test uses selector `0008` for a DPL-0 code descriptor with access byte
`1Ah` (code, present bit clear). It expects first-fault `#NP(0008)` after the
incoming task state has been loaded. A malformed `#NP` gate raises the second
protection fault and selects null-error `#DF`.

## Cases and observations

The `--iopl-controls` regression adds four executions: invalid-`#DF`-gate
shutdown and valid-`#DF`-task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the all-zero vector-11 gate triggers escalation; the all-zero
  vector-8 gate causes sticky shutdown. The test checks the null-error #DF
  packet with `CS:IP=0008:0300`, FLAGS `4202h`, SP `0080h`, the exact eight-byte
  vector-11 and vector-8 gate reads, no event-frame writes, and continued bus
  quiescence.
- **Successful delivery:** a valid vector-8 task gate switches to the #DF TSS.
  The test captures the packet at the vector-8 event and checks its null error
  code and exact saved context. It also checks the faulting incoming TSS image
  word-for-word (including CS=`0008`), backlink and busy bits, the zero error
  word on the #DF stack, exactly one vector-8 task entry, and the handler's HLT
  successor at `0030:0501`.

The existing incoming-segment matrix already checks direct `#NP(0008)` delivery
for a non-present incoming CS. These new cases extend that source-backed
classification through both #DF escalation outcomes; other task-entry fault
phases and the full double-fault classification remain open.

## Verification

`scripts/preflight.py` exits 0. The focused runner uses Verilator 5.052
`-Wall`; `--iopl-controls` passes with the four new executions. The strict
`scripts/run_sim.sh` exits 0 with 175 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its exact-source protected-mode replay passes 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so the prior
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_cs_np_double_fault_20261029_01/`. The
protected replay was built at `protected_mode_sim_20261029T002045Z/`. The
testbench SHA is
`5ec7975beeee1778d10ad59b50ba2285bde37ae67213366269224ac7faf9b33e`; the RTL
SHA remains `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

| Artifact | SHA-256 |
|---|---|
| `preflight.log` | `620391f4b26b482a0626e5666340ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `2bb4099c1fc1a898f420027c4498f67b94f7e466f5e85b2499b059edd6f2fe32` |
| `sim/build_manifest.json` | `ccb6084b2ed0c753d1d65d154f313c74508f55813d72a83f3a7218ee70f3b8a6` |
| `full_run.log` | `af2f8f288083352e40cf15e9e57fccda051556588b5a15e1b88ff48e20d30b58` |
| `protected_mode_sim_20261029T002045Z/build_manifest.json` | `e4ff5ed995572e750b77382d7251b488ecc3c0c122ebedc965f2a8803c7fcace` |
| `table8-1-row6-7.png` | `ecb968495a483b70d7d08745b6479b78f922cb996a7583924879eeedb7d78cde` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older 21-file
snapshot, not this current source. At the latest observed checkpoint it was at
frame 45 with 342 outputs proved and 40 timeout retries, with no terminal
result. Current-source connected-core proof and reachable covers, other
task-entry fault phases, authentic historical software, native timing
qualification, and the full CPU release gate remain open.
