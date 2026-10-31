# Incoming-SS #SS double-fault escalation — 2026-10-29

## Architectural basis

Intel's [80286 Programmer's Reference Manual, order 210498-005, §9.6.2 and
Table 8-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
defines task-switch validation and 286 double-fault handling. Table 8-1 row
11 requires the incoming stack segment to be present; a non-present stack
descriptor raises stack fault `#SS(selector)`. The table was visually reviewed
with Playwright CLI on printed page 8-6 (PDF page 156); see the
[`table8-1-row11.png`](../work/incoming_ss_np_double_fault_20261029_01/table8-1-row11.png)
capture.

The test uses incoming SS selector `0010` with a writable DPL-0 data
descriptor whose access byte is `12h` (present bit clear), yielding
`#SS(0010)` after the task registers and TR have transferred. Its malformed
vector-12 gate raises the second protection fault and selects null-error
`#DF`.

## Cases and observations

The `--iopl-controls` regression adds four executions: invalid-`#DF`-gate
shutdown and valid-`#DF`-task-gate delivery, each with READY immediate and
stalled.

- **Shutdown:** the all-zero vector-12 gate causes escalation and the invalid
  vector-8 gate causes sticky shutdown. The test checks the null-error #DF
  packet with `CS:IP=0030:0300`, FLAGS `4202h`, SP `0080h`, exact vector-12 and
  vector-8 gate reads, no event-frame writes, and continued bus quiescence.
- **Successful delivery:** a valid vector-8 task gate enters the #DF TSS. The
  test captures the packet at the vector-8 event and checks the null error and
  exact context. It checks the incoming faulting TSS image word-for-word,
  including SS=`0010`, backlink and busy bits, the zero error word on the #DF
  stack, exactly one task entry, and the handler's HLT successor at
  `0030:0501`. The #DF task uses valid DS/ES descriptors independent of the
  non-present incoming SS descriptor.

The existing incoming-segment matrix already checks direct `#SS(0010)` for a
non-present incoming SS. This extension exercises the first-fault #SS through
both #DF escalation outcomes; the other task-entry fault phases and full
double-fault classification remain open.

## Verification

`scripts/preflight.py` exits 0. The focused runner uses Verilator 5.052
`-Wall`; `--iopl-controls` passes with the four new executions and no debug
output. The strict `scripts/run_sim.sh` exits 0 with 176 `PASS:` lines and no
`FAIL:` or `ERROR:` lines. Its exact-source protected-mode replay passes 79
cases in both unstalled and READY-stalled modes. RTL behavior did not change,
so the prior 13-target Yosys 0.69 synthesis remains applicable; it was not
rerun for this testbench-only change.

Evidence is under
`design/intel_80286/work/incoming_ss_np_double_fault_20261029_01/`. The
protected replay was built at `protected_mode_sim_20261029T002713Z/`. The
testbench SHA is
`7ca039189158dd75a021e5ec10952fb2700fe7398b78ec955e65a56609e82609`; the RTL
SHA remains `4616be2d6c9d5bff4245e9964c92b8a26b45a3b67abca9ef4f56ab4b90dd6ee7`.

| Artifact | SHA-256 |
|---|---|
| `preflight.log` | `620391f4b26b482a0626e5666340ca46d0547c4af1391112540bdc0575e28aa` |
| `focused.log` | `c4addb7750a32c5e1d41c3b3e1ac106dfa6b4258a26476e08693da6e67c1fa6e` |
| `sim/build_manifest.json` | `f3072f896a47ea2a6b74e0f3bfa2afa27cfaa32cf32215c631f71722e0d9238f` |
| `full_run.log` | `2fe01d6e4dc6be3e5223782fe1975a57d4038f685bd578046f52eaca1f2f3cae` |
| `protected_mode_sim_20261029T002713Z/build_manifest.json` | `2e4623764342dd8df5ca7f8d4521a562f5861604d1785179e46f7b79dec59192` |
| `table8-1-row11.png` | `ecb968495a483b70d7d08745b6479b78f922cb996a7583924879eeedb7d78cde` |

## Remaining limits

The separate whole-core ABC PDR remains active against its older 21-file
snapshot, not this current source. At the latest observed checkpoint it was at
frame 45 with 342 outputs proved and 40 timeout retries, with no terminal
result. Current-source connected-core proof and reachable covers, other
task-entry fault phases, authentic historical software, native timing
qualification, and the full CPU release gate remain open.
