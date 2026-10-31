# Incoming-CS #TS double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines the 286 double-fault rules and task-switch validation order. Table 8-1
row 6 maps an invalid incoming CS selector to `#TS(selector)`. A null incoming
CS selector therefore faults with `#TS(0000)` after the task switch has loaded
the incoming task state. If the `#TS` gate is malformed, its protection fault
escalates to null-error `#DF`.

## Cases and observations

The `--iopl-controls` regression adds four executions: invalid-`#DF`-gate
shutdown and valid-`#DF`-task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the incoming TSS has null CS and LDTR selectors, with valid
  SS, DS and ES.
  Its `#TS` gate is all zero, so gate validation raises the second fault. The
  all-zero vector-8 gate then causes sticky shutdown. The test checks the
  null-error vector-8 packet with `CS:IP=0000:0300`, FLAGS `4202h`, SP `0080h`,
  the exact eight-byte `#TS` and `#DF` gate reads, no event-frame writes, and
  continued bus quiescence.
- **Successful delivery:** the same incoming-CS `#TS` and malformed `#TS`
  gate escalate through a valid vector-8 task gate. The test captures the
  packet at the vector-8 event because packet-valid clears after delivery; it
  checks null error code and the exact invalid-CS saved context. It also
  checks the faulting incoming TSS image word-for-word (including CS=`0000`),
  the backlink and busy bits, the zero error word on the `#DF` stack, exactly
  one vector-8 task entry, and the handler's HLT successor at `0030:0501`.

These tests distinguish the later CS-validation `#TS` phase from the already
covered incoming-LDTR `#TS` phase. They do not cover every post-transfer
failure phase or the full 286 double-fault classification.

## Verification

`scripts/preflight.py` exits 0. The focused runner uses Verilator 5.052
`-Wall`; `--iopl-controls` passes with the four new executions. The strict
`scripts/run_sim.sh` exits 0 with 174 `PASS:` lines and no `FAIL:` or `ERROR:`
lines. Its exact-source protected-mode replay passes 79 cases in both
unstalled and READY-stalled modes. RTL behavior did not change, so the prior
13-target Yosys 0.69 synthesis remains applicable; it was not rerun for this
testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_cs_double_fault_20261029_01/`. The protected
replay was built at `protected_mode_sim_20261029T001334Z/`. The testbench SHA is
`55ddf4412b87391cc7fea1ee99e75148416b1264538b7d82c389c4a63198049d`; the RTL
SHA remains `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

| Artifact | SHA-256 |
|---|---|
| `preflight.log` | `620391f4b26b482a0626e5666340ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `ade6f945fa2e63f057a7706fdbf8a3bba3a25d872e901b97c127ea78be3d7f23` |
| `sim/build_manifest.json` | `ee04e8cfb32ee62eff547bfba965683faac44d7a8ae84db56bf8ed8792924a1c` |
| `full_run.log` | `0aafcaae20550999255401705061b09623b11682adbb8ee6d6ed5ba9039105ca` |
| `protected_mode_sim_20261029T001334Z/build_manifest.json` | `741aa5d34ebe5fb95fb5ac0c42fb08629e93074eeb55e96c9f3eb4615968c5f8` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older 21-file
snapshot, not this current source. At the latest observed checkpoint it was at
frame 45 with 342 outputs proved and 40 timeout retries, with no terminal
result. Current-source connected-core proof and reachable covers, the other
task-entry fault phases, authentic historical software, native timing
qualification, and the full CPU release gate remain open.
