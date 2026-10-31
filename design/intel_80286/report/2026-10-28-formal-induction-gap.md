# Connected-core formal induction gap — 2026-10-28

## Result

The CPU proof has no reset-reachable counterexample in its configured depth-12
base case, but temporal induction is still `UNKNOWN`. The failure is an
induction-only state relation in the properties, not a demonstrated RTL defect.
Do not count the current connected-core prove as closed.

## Evidence and source identity

The aggregate attempt used the isolated evidence root
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/` and stopped
with exit code 4 at `intel_80286_prove`:

- All component BMC, prove and cover tasks passed.
- Connected-core depth-24 BMC passed without output or counterexample. Its
  engine log SHA-256 is
  `19478725D2A951895A255E6751B0D4AEEC554C9A43CFB6278C328CE95CAE3248`.
- Connected-core depth-12 prove passed its base case and failed induction at
  copied property line 812, then SBY returned `UNKNOWN` (rc=4).
- The copied property file has SHA-256
  `FEBE486C2A49558E438B1FFEA4DA32F02D04C4549B7DAD1AD1ED3694FF750FD0`. It
  predates the subsequent property-only fixes. The 14 core RTL sources in the
  prove target match the worktree; the native CPU and native bus wrapper files
  are not in this core proof target and receive no formal coverage here.
- Strict lint and the four preflight/helper Python suites passed before formal
  execution. Later run-all stages did not run.

After that aggregate run started, two assertion scopes were corrected in
`formal/intel_80286_props.sv`:

1. The protected event-delivery property now excludes the known contributory
   exception that escalates to #DF when vector 8 itself exceeds the IDT limit.
   The dedicated #DF invariant checks that escalation and saved context.
2. The retire-origin assertion now requires `rst_n` in its own antecedent,
   because induction can otherwise assert `retire_o` during reset.

A separate proof at
`design/intel_80286/work/formal_runs/induction_reset_mask_20261028_0830/`
uses the current property file, SHA-256
`A86878199D5B1CE79CD92F2C2987723F13E430A12FA9312F1616E8E503006BA2`. Its
depth-12 base case passes; induction returns `UNKNOWN` at
`formal/intel_80286_props.sv:189`:

```systemverilog
if (rst_n && (state==SEGMENT_LOAD_WAIT || state==CODE_LOAD_WAIT)) assert(msw[0]);
```

The induction trace SHA-256 is
`66084D61B7A3C66163A2DD6EB64992F0D95550C155EDE4573C4E15F2E4DDCE49`. It
starts from arbitrary internal state `TASK_SEGMENT_START` with `MSW.PE=0`,
advances into `SEGMENT_LOAD_WAIT`, and violates the broad state invariant.
That starting state is admitted by induction but is not shown reachable from
reset. The failing property reflects task-switch state provenance that the
current invariant set does not establish. No RTL was changed in response.

## Independent release stages — 2026-10-28

The stages skipped by `run_all.sh` after the formal failure were run separately
against the current LOCK-connected RTL in
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/`:

- Verilator `run_sim.sh`: 141 PASS lines, including the 79-case protected
  replay. Manifest SHA-256:
  `542AF94A7BB1276B43D29D95CA622B6A214460512AB215EB0E7295CE6305A35E`.
- Independent vectors: 99,650 Unicorn cases and 1,715,162 instruction states.
  Hardware replay: 68,510 physical captures and 52 #GP protection captures in
  both READY modes, plus all corruption checks.
- Mutation suites detected 4 undefined-opcode, 4 protection, 6 event and 15
  protected-string faults. Two stale source patterns were corrected to the
  current event-call API after the first mutation attempt exposed them.
- IBM AT software regressions passed with the pinned original BIOS, including
  196,846 exact ROM execution states, IRQ timer and system-register checks.
- Yosys 0.69 completed all 11 targets. Each log ends normally and contains
  three zero-problem `check -assert` results with no `ERROR:`. Eleven JSON
  netlists were written.

The `audit_formal.py` audit of the aggregate snapshot returned 36/40. All
component BMC/prove/cover tasks passed. Core BMC and prove were rejected as
stale because their copied property file predates the two assertion fixes; core
cover and whole-core PDR were not reached. This is an incomplete aggregate
formal audit, not proof closure.

Key retained log hashes:

| Evidence | SHA-256 |
|---|---|
| Simulation | `C8B5D02D37D0B0C7AE764B661A05B875D475EF56FEB26C2D623070CFCEDF4FC8` |
| Vectors and hardware replay | `FBE23235D9B654FC8F298B0B503AC1212F05225798DB0B8817F5D62597C1BABA` |
| Passing mutation retry | `A1B60E310DE2107A69C6FD09BA20CA55CF8C4E8146D0A9D81BD5753566A16D65` |
| Software and all synthesis targets | `86AF96769C954704BABCDE680344D20E20CC10FEE5C2EC536D221DBA5D0A527F` |
| Formal audit | `24525FB0E0A3D6812392E19788FD429EB3C75B37E963F08DC20BD33A81FAAC32` |
| Formal audit JSON | `1A7468A14C070AD7CFA8FD2BC9D73CDD611C9D381F5FB5A189F3C8137E8AEF2F` |

## Separate current-source whole-core PDR follow-up — 2026-10-28 09:36 UTC

A standalone `intel_80286_pdr.sby` run was started with fresh evidence under
`design/intel_80286/work/release_lock_checkpoint_20261028_0720/formal_runs/current_pdr_20261028_0926/`.
All 21 copied RTL/property files match the current worktree. The current top
property file SHA-256 is
`A86878199D5B1CE79CD92F2C2987723F13E430A12FA9312F1616E8E503006BA2`.
Yosys translation completed in 299.26 seconds. At the 09:36 UTC checkpoint,
ABC PDR had reached frame 24 and proved 181 of 411 assertion outputs. The
task-switch/PE assertion at line 189 remains in the timeout set; no reachable
counterexample or terminal PASS/FAIL has been reported. The engine is retrying
timed-out outputs with larger budgets. External inputs remain unconstrained;
no environment assumptions were added. This separate run does not replace a
fresh `run_all.sh` or make the 80286 completion claim. Progress was recorded
in [issue comment 6465565038](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6465565038).

### Progress checkpoint — 2026-10-28 09:58 UTC

The same run reached frame 19 and proved 240/411 assertion outputs, with 99
timeout retries. It remains active without a counterexample or terminal result.
The exact-source check and unconstrained external-input setup are unchanged.
The checkpoint is recorded in
[issue comment 6465985361](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6465985361).

### Progress checkpoint — 2026-10-28 10:17 UTC

The separate current-source run remains active. Its latest log entry, at
10:15:33 UTC, shows frame 9 with 259/411 assertion outputs proved and 10
timeout retries in the current anytime pass. It has not reported a reachable
counterexample or terminal result. The 21-file copied RTL/property snapshot
and unconstrained external inputs are unchanged.

A Playwright CLI rerun reached retail OS/2 1.0's command prompt and reproduced
`CPGREP -yn fast ..\README`, returning the expected line 11 containing `FAST`.
The attempted instruction-history capture still contains only the OS/2 shell
wait loop; this is emulator-only software evidence, not a CPGREP trace or RTL
execution. The aggregate `run_all.sh` gate remains open. See
[issue comment 6466403347](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466403347).

### Progress checkpoint — 2026-10-28 10:21 UTC

The latest log entry, at 10:21:44 UTC, shows frame 13 with 260/411 assertion
outputs proved and 37 timeout retries in the current anytime pass. The run
advanced one frame since the issue checkpoint but proved no additional output.
It remains active without a reachable counterexample or terminal result;
source snapshot and unconstrained-input setup are unchanged. The Playwright
CLI OS/2 CPGREP rerun and the instruction-history limitation are recorded
above. See
[issue comment 6466456540](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466456540).

### Progress checkpoint — 2026-10-28 10:24 UTC

The latest log entry, at 10:23:57 UTC, shows frame 15 with 260/411 assertion
outputs proved and 46 timeout retries in the current anytime pass. The engine
has advanced from frame 12 to frame 15 since the prior GitHub checkpoint, but
has not proved another output. The run remains active without a counterexample
or terminal result. Source snapshot and unconstrained-input setup are unchanged.
See
[issue comment 6466516265](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466516265).

### Progress checkpoint — 2026-10-28 10:25 UTC

At 10:24:59 UTC ABC PDR reached frame 16 and proved output 212, bringing the
total to 261/411 assertion outputs. The current anytime pass has 51 timeout
retries. The run remains active without a reachable counterexample or terminal
result. This is one additional proved output since the 10:24 checkpoint; the
source snapshot and unconstrained-input setup are unchanged. See
[issue comment 6466541236](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466541236).

### Formal evidence correction and checkpoint — 2026-10-28 10:27 UTC

The exact current-run assertion map (`model/design_aiger.ywa`) maps output 147
to `formal/intel_80286_props.sv:189`. The PDR log records `Proved output 147 in
frame 14` at 09:30:52 UTC. Therefore, the current-source whole-core PDR has
proved the line 189 PE assertion. The separate depth-12 proof's UNKNOWN
induction result at that line is historical and belongs to a different proof
attempt.

At 10:27:39 UTC the whole-core PDR had reached frame 19 and proved 261/411
assertion outputs, with 63 timeout retries in the current anytime pass. It is
still active and has no counterexample or terminal result. Its latest retry
set contains core and descriptor-engine assertions; the aggregate release
gate remains open. The source snapshot and unconstrained-input setup are
unchanged. See
[issue correction 6466581278](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6466581278).

## Verification status and next work

The LOCK-connected `run_sim.sh` passed with 141 PASS lines, including all 79
protected-mode replay cases, and Yosys 0.69 synthesis passed all 11 targets
with three zero-problem `check -assert` runs per target. Those independent
results are recorded in
[`2026-10-28-native-lock-integration.md`](2026-10-28-native-lock-integration.md).
They were rerun in the isolated release root and cover the same RTL used by the
aggregate formal run; only formal properties and mutation-script match strings
changed afterward.

The full aggregate has not been rerun after the property edits. Continue the
active whole-core PDR until it reaches a terminal result, then run reachable
covers and the exact-source formal audit on one consistent source snapshot.
The line 189 PE assertion itself is already proved by the current PDR; this
does not close the remaining core assertions or the release gate. A bounded
PASS or an induction-only trace is not a full proof.

Issue #80 remains Open/Building. The stopped run and correction are recorded in
[issue comments 6464509177 and 6464545239](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6464545239).
