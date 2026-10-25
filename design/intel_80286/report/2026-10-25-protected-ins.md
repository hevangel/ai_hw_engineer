# Protected INS fault-state correction — 2026-10-25

Issue: [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80).
Status: implementation milestone; the full 80286 remains incomplete.

## Change and independent expectation

The recovered core preserved DI/CX when its ES destination precheck denied
INS. Intel's original technical memos require handler repair of those
registers. The [failure note](../../../failure_notes/2026-10-25-intel80286-ins-fault-state.md)
links the manufacturer documents and records why the initial tests shared
the incorrect assumption. The specification now selects the corrected
post-C2 count behavior and qualifies A20's unverified native port timing.

The core updates fault-time DI/CX, including 16-bit wrap, and sends word INS
at FFFF through the same destination checker. The formal transition checks
account for this specific register change. The diagnostic handler repairs
the indices/count, widens ES, then retries from the exact instruction prefix.

## Identified source and tools

- Core SHA-256:
  `0947d5aa793426c868899ae9e5a48efa7cff4e07157e9d77996d251afc669b26`.
- CPU properties SHA-256:
  `4bac795c0b5564c83604b12c02fcb95c667811e3dffc699e11bc9cf8e20a776d`.
- Replay binary SHA-256:
  `ea0b380bb27cb7794689423d2b6db778b4d65a6d53101ee2580b43c68a3a14c1`.
- Tool container: `ai-hw-engineer:latest`, invoked with `--pull=never`.
  Verilator 5.052; Yosys 0.69, git `9f75ca1f9`. The replay manifest records
  the compiler version and every RTL/C++/runner input hash.

Run commands inside the container with
`B:/ai_hw_engineer/worktree/intel-80286` mounted at `/work` and working
directory `/work`:

```sh
bash design/intel_80286/scripts/run_protected_mode_replay.sh \
  protected_ins_native_20261025_01
python3 design/intel_80286/scripts/run_protected_ins_mutations.py \
  design/intel_80286/work/protected_ins_native_20261025_01/build_manifest.json \
  protected_ins_native_mutations_20261025_01
yosys -Q -q -l design/intel_80286/work/ins_checks_20261025_01/synthesis.log \
  -s design/intel_80286/work/ins_checks_20261025_01/synth.ys
```

The synthesis script reads all 14 RTL files, runs `synth -top intel_80286`,
`check -assert`, and `stat`. Preserved formal configs retain the standard
properties/engines, set the BMC smoke depth to 12 and retain cover depth 64.
Run those from `design/intel_80286/formal`:

```sh
sby -d ../work/ins_checks_20261025_01/bmc12_retry \
  ../work/ins_checks_20261025_01/bmc12_retry.sby bmc
sby -d ../work/ins_checks_20261025_01/cover64 \
  ../work/ins_checks_20261025_01/bmc12.sby cover
```

Use fresh output directories when reproducing. The replay runner refuses
existing evidence directories; a direct guard check confirmed that the prior
passing binary remains unchanged after such a refusal.

## Results

- **Regression PASS:** five existing protected recovery/reset cases and ten
  INS cases. INSB beyond limit, INSW crossing the limit, INSW at FFFF, and REP
  INSW faults on final/nonfinal elements run both without stalls and with
  every byte request stalled. The checks include prefix restart PC and exact
  successors, error frame, DI/CX at fault and after repair, unchanged AX,
  completed-element counts, memory byte writes and input byte consumption.
- **Old-core failure reproduced:** the source-derived register expectation
  fails before the fix. The old binary, source hashes and captured diagnostic
  are in `work/protected_ins_native_red_20261025/`.
- **Mutation PASS:** all five compiled mutants fail with the expected
  diagnostic. They ignore destination denial, check only the first byte,
  save the successor PC, preserve pre-fault indices, or decrement REP twice
  on a successful element. `work/protected_ins_native_mutations_20261025_01/mutations.json`
  binds the baseline and per-mutant cores/logs to hashes.
- **Strict RTL lint PASS:** the replay build uses Verilator `-Wall` and
  completes without warnings.
- **Synthesis PASS:** 28,654 cells including submodules; zero problems from
  `check -assert`. The log and exact script are in
  `work/ins_checks_20261025_01/`.
- **Bounded formal PASS:** the depth-12 retry passes in 221 seconds. The
  first depth-12 BMC hit a 180-second limit while
  checking frame 10, with no counterexample. Its output is preserved in
  `work/ins_checks_20261025_01/bmc12/`; the passing retry with its 600-second
  allowance is in `bmc12_retry/`. This shallow bound does not establish
  unbounded safety or reach the whole protected INS workload.
- **Cover incomplete:** depth-64 cover mode reaches 11 complete witnesses
  before its 180-second timeout while checking step 10. The retained witnesses
  do not prove native INS fault non-vacuity; the explicit simulation cases
  demonstrate that path. The full cover gate remains open.
- **Source audit PASS:** all 18 replay inputs and each of the three 21-file
  formal snapshots match current source bytes. The formal audit is retained
  at `work/ins_checks_20261025_01/source_audit.json`.

## Limits and next work

No full proof or full release-suite result is established by this milestone.
The old depth-24 BMC/PDR/cover artifacts predate the changed source. The
historical broad testbench sources and release runner are still missing.
The current directed workload is synthetic, and OS/2 CPGREP has not run.
A20 port timing, IOPL faults, decrementing-direction integration and native
fault repair of the other string instructions remain open. Keep the issue
Building until the full completion ledger is satisfied.
