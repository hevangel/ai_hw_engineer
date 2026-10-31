# Intel 80286 formal plan

## WAIT/event counterexample — 2026-10-29

The current-source PDR run described below finished **FAIL** at step 9.
The witness shows WAIT retiring from `WAIT_BUSY` as an NMI is selected;
the event is held across `BOUNDARY` for `EVENT_POLL`. The retirement and
event-poll assertions omitted those legal states. A maskable interrupt can
similarly hold its acknowledgement across the same transition. The properties
now include these cases, and CPU regressions for both NMI and delayed INTR at
BUSY deassertion pass. The subsequent BMC failed on an outdated state bound;
that bound is now corrected. The following BMC and older PDR failed on a real
WAIT/extension-error event-priority race. The RTL correction passes bootstrap
simulation; BMC and PDR for the corrected snapshot are running. See the
[counterexample report](../report/2026-10-29-wait-event-formal.md)
for exact evidence and the status of subsequent verification. No whole-core
proof is established by the failed run.

## Current-source PDR after container loss — 2026-10-29

The Docker engine became unavailable during a separate software run. After it
returned, the previous `dcd30140a9c0` container was absent from Docker's
inventory, and its preserved PDR directory had no terminal SBY status. Its
last saved solver progress was 344/411 outputs proved, not a proof result.
The old evidence remains under `work/release_lock_checkpoint_20261028_0720/`.

Started a fresh current-source PDR in retained Docker container
`codex-intel80286-pdr-20261029-01` (ID `8b76ac7e9857`), using
`work/current_pdr_20261029_01/formal_runs/pdr/`. Preflight passed, SBY copied
21 RTL/property files, and all 21 matched the worktree at dispatch. The Yosys
translation completed and ABC PDR subsequently failed at step 9 as described
above. Preserve its counterexample and source snapshot.
Current-source connected-core BMC, induction and cover also remain open.

## Current-source code-load component — 2026-10-29 04:22 UTC

Ran `scripts/run_formal.sh intel_80286_code_load.sby` in the repository
container, with evidence under
`work/task_switch_ss_cs_priority_20261029_38/formal_runs/code_load/`. BMC
passes at depth 24, the k-induction proof passes, and cover passes with eight
reached witnesses. Preflight passed. SHA-256 comparisons confirm that the
captured `intel_80286_code_load.sv`, `intel_80286_code_check.sv` and
`intel_80286_code_load_props.sv` match the current sources. This is a
component-level result only; it does not close the connected-core formal gate.

The preserved whole-core PDR remains active on a different 21-file source
snapshot. Its current status and the restriction on starting a competing
connected-core run are recorded below.

## Preserved whole-core PDR status — 2026-10-29 04:03 UTC

The preserved whole-core PDR remains active on its different 21-file source
snapshot. At 04:03 UTC the container was still active, and its latest solver
log line remained the 03:07:38 UTC frame-166 result: 344/411 outputs proved
and 67 timeout retries. No terminal PASS or failure is recorded. A byte
comparison found 19 of 21 copied RTL/property sources match current files;
`intel_80286.sv` and `intel_80286_code_load.sv` differ. Its eventual result
therefore cannot establish current-source proof. See the
[PDR source-epoch audit](../report/2026-10-29-pdr-source-epoch-audit.md) and
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).

Preserve the active job and its directory; do not start a competing
connected-core formal run until this PDR reaches a terminal result. Then
reconcile the saved source epoch and run the current-source connected-core
BMC, induction, cover, PDR and aggregate exact-source audit. Current-source
connected-core formal remains open.

The 192-case direct task-gate DPL matrix and full 170-PASS simulation do not
change formal status. They are directed simulation evidence; no current-source
whole-core formal was started.

## Current-source component formal refresh — 2026-10-28 14:46 UTC

All 12 standalone component configurations pass BMC, proof and cover: 36/36
tasks, with 59 reached cover witnesses. `preflight.py` passes. The partial
exact-source audit confirms that saved task configurations and every copied
source match current inputs (36/36). Evidence and hashes are in
[`2026-10-28-formal-components-current.md`](../report/2026-10-28-formal-components-current.md).
The result is also recorded in
[issue comment 6472164584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472164584).

This does not include the connected-core BMC/prove/cover or PDR. The active
whole-core PDR is still tied to an older 21-file snapshot; at 14:46 UTC it had
reached frame 89 with 321/411 outputs proven and 70 timeout retries. Follow the
existing source-epoch rule: preserve that job and do not present it as evidence
for current RTL. The next formal stage is a coordinated connected-core epoch
and complete exact-source audit after the old job reaches a terminal result.

## Connected-core epoch — 2026-10-28 04:47 UTC

The pre-correction 21-file property snapshot passed the configured depth-24
connected-core BMC using `abc bmc3`, with no output asserted and no
counterexample. It is a bounded check only. The first depth-12 prove passed
its base case but failed induction on `intel_80286_props.sv:526`: the
reachable shutdown state keeps `halt_latch=1`, so the HLT-only state assertion
was too strong. The property now excludes `shutdown_o`, and preflight passes.
The corrected depth-12 prove passes its base case but returns UNKNOWN on
induction assertions at `intel_80286_props.sv:525` and `:775`. The induction
trace begins from unconstrained internal state; reset reachability beyond the
checked bound remains unresolved. Source-to-log audit finds 45/73 active
cover goals reached: 38/52 top-level CPU-property covers and 7/21 active
component covers. The newest is `intel_80286_muldiv_props.sv:38`, reached at
step 32 and saved as `trace42`; the search advanced to step 33 and reached a
1-hour wait marker without a new witness or terminal result.
Earlier
`44/52` shorthand mixed component hits with the CPU-only denominator. Yices
remains active without failure or terminal result in
`work/formal_runs/core_20261027_04/intel_80286_cover/`. SHA-256 comparison
confirms all 21 copied run inputs (14 RTL and 7 property files) match current
sources. The pre-correction BMC no longer matches the current property file;
rerun BMC, PDR and aggregate exact-source audit against the corrected snapshot.
Preserve all run directories and copied inputs.

## Verification checkpoint — 2026-10-27 14:11 UTC

Protected shutdown now has a separate `bus_shutdown_cycle_o`; an active HLT
uses `bus_halt_cycle_o`. The cycle-class outputs are mutually exclusive,
remain active when READY is low, and do not issue byte requests. Raw 80286
status/A1/ALE pins remain outside the transaction abstraction. The expanded
`--iopl-controls` suite passes 480 privilege scenarios, 234 reset cuts during
nested #DF task-gate entry and 180 during task IRET, including exact
reset-vector replay in both READY policies. The full default bootstrap, strict Verilator 5.052 `-Wall`
lint and release preflight pass. Core properties contain 309 assertions, one
assumption and 52 covers; exact hashes are in the
[bus-cycle and reset-cut report](../report/2026-10-27-shutdown-bus-cycles.md).

Full-core Yosys 0.69 synthesis completed with `check -assert` reporting zero
problems. The synthesized core has 49,771 cells across 11 submodules. The
standalone event controller still passes 8,016 checks and its current-source
BMC, k-induction and cover, including a reachable shutdown-NMI witness.

The pre-bus connected-core BMC was stopped at frame 17 without a terminal
result. A new current-source depth-24 connected-core BMC is running in
`work/formal_runs/shutdown_bus_core_20261027_01/`; its last logged progress is
frame 12 and it has no terminal result. No connected-core formal task has
passed. Prove, cover, PDR and aggregate audit remain open, as do raw bus-pin
timing, broader #DF delivery failures, independent historical software and
release acceptance.
GitHub checkpoint: [issue comment 6444263447](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6444263447).

## Previous connected-core checkpoint — 2026-10-27 11:00 UTC

The combined `--iopl-controls` regression passes 480 scenarios across both
READY modes, including 120 protected nonzero-CPL denials for LGDT/LIDT/LMSW/
CLTS and 40 CPL-0 controls. The full default Verilator bootstrap and release
preflight pass. The two nested protected #GP cases also pass: IDT-limit
failure during initial #GP gate lookup selects vector 8 with null error code
and preserves the original saved context, before the interrupt/trap-only gate
validator rejects the all-zero vector-8 descriptor. RTL SHA-256 is
`2777eaea08bd5de2247a994d1468ab707f5d596d4e367915bb097c031af75d90`; the
testbench hash is
`42a1726bd7dd589426934650f947788944b732c23c763f2540a222362eb8d137`.
The core property source now adds an assertion for the #DF packet, null error
code and saved-context preservation, plus a cover for the IDT-limit transition.
Preflight passes with 299 assertions, one assumption and 50 covers; property
SHA-256 is `d650dd7231a11b85b7737a9295afe0161a2cf87c235ae90fff6915f2688b28cb`.
The Verilator 5.052 runner fingerprint is
`50306e079cfaa8a48e8dd565ca9e092620e7aef3dbb5015f7d42333dc9f599d8`. The
full bootstrap log is
`work/double_fault_classification_20261027_01/full_bootstrap.log`; see the
[double-fault report](../report/2026-10-27-double-fault-escalation.md).

No connected-core formal result covers this RTL/property pair. At the latest
check, the `_21` cover job remained waiting on the solver at step 35 (last log
10:42:24 UTC); PDR advanced to frame 29 with 366 outputs proved and 28 timeout
retries (10:58:49 UTC). Both remain on older snapshots. Wait for them to terminate
before starting a current exact-source epoch. Then run connected-core BMC,
induction, cover and PDR, followed by the aggregate source audit. Component
passes and older core snapshots remain separate evidence. Full formal closure
and release acceptance remain open.

## Previous connected-core checkpoint — 2026-10-27 09:46 UTC

The RETF stack-span cleanup is in RTL and passes the focused
`--call-gate-retf-faults` suite in both READY modes; release preflight and the
full Verilator bootstrap pass. The bootstrap log is
`work/sim_codex_20261027/full_bootstrap.log`. RTL SHA-256 is
`ffa9248d1866ecea38b2357f265028821a79768349e2ba86b7f0ac036ba6642b`.

Run `_27` used that RTL with property hash
`edbef28f43c79e09a09035ea7d40a8b76e18d95c58adf2d17a6051e35b96ee36`. Its
depth-12 base case passed, then induction returned UNKNOWN at line 86 on an
arbitrary RET/IRET owner state. That trace did not exercise the memory-check
cleanup path. The broad owner/opcode invariant was replaced with a one-cycle
assertion that a denied `MEMORY_CHECK` clears the protected RET owner and all
outer-return flags.

Run `_28` passed the depth-12 base case, then returned UNKNOWN at line 578. Its
induction trace starts from an arbitrary BUS return continuation and reaches
`RET_CODE_START` with opcode `83`; the denied-memory-check cleanup assertion
passed. The state-specific RET code-load assertion now checks PE and the
active owner there, while `FAR_RETURN_DONE` retains the RETF opcode check.

Preflight passes. Current properties have 298 assertions, one assumption and
49 covers; SHA-256 is
`b46fea44605d534db9578a494663fdd3d76b0f1ad07e263ba8d9ca041d96e9c5`.
Connected-core prove `_29` copied the previous property snapshot at 09:36:34
UTC. Its depth-12 base case passed; induction returned UNKNOWN at line 329 on
an arbitrary BUS continuation carrying `EVENT_GATE_TAIL` with no event owner
or valid packet. The reverse event-state assertion now requires a prior-cycle
active event owner; the complementary owner-to-path assertion remains. The
next proof snapshot has not started while the older `_21` cover and PDR jobs
remain active. Current-property BMC, prove, cover, PDR and exact-source audit
remain open. No reset-reachable counterexample is established. Task gates,
task switching and nested-fault escalation remain open.
Latest issue checkpoint:
[comment 6438637209](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6438637209).

### Earlier connected-core retry history — 2026-10-27 09:03 UTC

The `_22` retry added outer-IRET ownership assertions; `_23` added CALL/TSS
ownership and exposed the overly broad event-completion assertion, which was
refined before `_24` passed the depth-12 base case but failed induction at
line 160 on an unreachable PE-clear protected CALL continuation. A
state-exclusion invariant made `_25` pass that property, but `_25` then failed
induction at line 572. Its induction-only trace carries `protected_ret_active`
with opcode `2Ch` into `RET_CODE_START`; RTL creates that owner only for
protected RETF/RETF-imm. The invariant binds `protected_ret_active` to PE and
opcodes `CA`/`CB`.

The 2026-10-27 refresh passes release preflight and all 36 component formal
tasks (BMC, prove and cover across 12 component configurations). The exact
source copies, SBY logs and cover traces are under
`work/formal_runs/protected_event_outer_20261027_21/components/`. The previous
aggregate run audited against current files as 9/40 because component source
copies were stale and current core result directories were absent; it does not
contradict this refresh. The connected-core depth-24 ABC BMC now passes
(`PASS 0 2055`, no counterexample through 24 frames) under
`work/formal_runs/protected_event_outer_20261027_21/core/intel_80286_bmc/`.
Core prove `_21` returned `UNKNOWN` after its depth-12 base case passed;
induction fails at line 160 with the same induction-only trace as `_20`. The
exact-source audit is 37/40. At 2026-10-27 08:14 UTC, matching reached-cover
records against the 49 CPU assertions shows 38 reached and 11 remaining. The
43 VCD files include component witnesses; the latest is the `multiply_divide`
goal at step 32, not a CPU goal. Yices remains active. Remaining core cover goals target
async REP/debug events, F7 /6 and PUSHA, event-error-frame write and IRET code-load commit,
PE-enabled CS and DS/ES/SS cache transitions, and vector-8 IDT-limit delivery
(properties 485, 486, 697, 699, 783-788 and 790). SBY last reported a
30-minute wait at 08:02:12 UTC. The previous PDR anytime pass ended at frame
29 with 366 proven outputs and 28 timeouts (latest on output 137). ABC started
a new anytime pass reusing clauses and has advanced to frame 7, retaining 366
proven outputs and three timeouts queued from outputs 350, 357 and 367.
Neither task is terminal, so the aggregate audit remains open. Run
evidence is under
`work/formal_runs/protected_event_outer_20261027_21/`; see the
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

The event-gate RTL SHA-256 is
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`.

The connected-core depth-24 ABC BMC completed `PASS 0 2293` at 22:49:18 UTC,
with no counterexample through 24 frames. This run used CPU-property SHA-256
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`; its
source hashes and terminal log are recorded in
`work/formal_runs/protected_event_outer_20261026_01/core_bmc/run_manifest.json`.

The depth-12 Yices prove on that same property snapshot passed the base case,
then returned `UNKNOWN` at induction on `intel_80286_props.sv:213–214`. Its
induction-only witness sets `segment_load_target=3` (DS),
`event_stack_active=1`, `event_delivery_active=0` and TSS SP=7. The RTL takes
the expected stop path for an undersized event stack and preserves DS; the
assertion incorrectly assumed every target-3 segment load commits DS. This is
not a reset-reachable counterexample. The witness and hashes are retained in
`work/formal_runs/protected_event_outer_20261026_01/core_prove/run_manifest.json`.

The TSS-selected event-stack assertion distinguishes event-stack validation
from ordinary DS loads. Further review refined the software-INT event scope,
the upper event-state bound, event-packet provenance and the old-stack
preflight invariant. Current CPU-property SHA-256 is
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874`, with
290 assertions, one assumption and 49 covers. Release preflight passes.
Depth-12 Yices prove `_20` passed the base case but returned `UNKNOWN` at
induction under
`work/formal_runs/protected_event_outer_20261026_20/core_prove/`. Its latest
induction-only trace starts in `CODE_LOAD_WAIT` with PE clear and fails the PE
ownership invariant; actual code-load launch paths are PE-gated or originate
in protected event/return states. Runs `_12`–`_20` passed their bounded base
cases but returned `UNKNOWN` at induction. Earlier witnesses drove explicit
ownership properties for valid active event packets, TSS stack state, shared
descriptor waits and far-return continuations. No reset-reachable
counterexample has been found and no induction proof has passed. The earlier
depth-24 BMC used pre-refinement properties. The matching current-source
depth-24 core BMC now passes through 24 frames. A fresh prove run `_21` repeats
the line-160 induction-only failure from `_20`; cover is running, and PDR and
aggregate exact-source audit remain open. Latest issue checkpoint:
[comment 6436940553](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436940553).

Depth-12 Yices run `_29` and PDR run `_30` under
`work/formal_runs/selector_privilege_current_20261026_29/` and `_30/` are
pre-event snapshots. `_29` passes the base case through 12 frames but is
`UNKNOWN` at induction on the event-frame ownership property; its witness is
an induction-only state, not a reset-reachable counterexample. `_30` was
interrupted while ABC PDR was still working and is not a terminal result.
Neither qualifies the current interrupt/trap-gate RTL or properties.

The prior property review corrected outer-IRET state ownership, LTR's
`COMMIT_MEMORY` continuation, protected CALL/return ownership and the captured
memory-precheck return state. Those source-history findings remain useful for
designing the next invariant, but all `_21`–`_30` statuses are stale for the
current RTL/property pair. Full-core formal closure remains open.

## Previous core evidence status — snapshot `run.ySqmJ8` (2026-10-26)

### Snapshot `run.ySqmJ8` (2026-10-26)

These results predate ARPL and do not verify the current core hash. Refresh the
connected-core tasks and exact-source audit after the current replay baseline
is rebuilt. Reuse component results only where the saved source snapshots still
match their unchanged inputs.

The source-matched run in
`work/formal_runs/run.ySqmJ8/` has PASS status for all 36 component tasks and
connected-core depth-24 BMC (`PASS 0 1699`). Core depth-12 prove is `UNKNOWN`:
the base case passed through the configured depth, but induction failed at
`intel_80286_props.sv:388`.
Its induction-only trace starts in `CODE_LOAD_WAIT` for an event target with
`event_packet.valid=0` and a stale `instruction_retired=1`, then reaches
`EVENT_FRAME_CHECK`; the starting state is inconsistent with the event-packet
lifecycle. Treat this as an invariant-strengthening gap, not a reachability
result; the run does not prove the full assertion set. The core cover was interrupted at step 15 after 21
witnesses. Full-core PDR was interrupted after proving 243 outputs, with no
terminal SBY status. Neither interrupted task counts as PASS. Exact logs and
traces are preserved in that run directory.

The first full-run attempt exposed that the runner ordered `intel_80286_pdr`
before segment components and the bounded core. `scripts/run_formal.sh` now
discovers each config's `[tasks]`, runs components before the core and PDR last,
and accepts config basenames for targeted runs. The 36 component PASS results
and depth-24 BMC are useful gates, but the exact-source audit still fails until
proof and cover are complete.

The exact-source audit now understands the PDR-only `prove` config. For this
snapshot its result was 37/40 tasks: all components and core BMC pass; core prove is UNKNOWN,
and core cover/PDR have no completion status. It reports 229 elaborated CPU
assertions and 49 covers in the core models. `test_audit_formal.py` passes all
17 tests, including a prove-only configuration fixture. Recheck with
`python3 scripts/audit_formal.py --work-dir work/formal_runs/run.ySqmJ8
--core-work-dir work/formal_runs/run.ySqmJ8` after generating terminal results.

## Historical core evidence status (2026-10-21)

The restored CPU properties reconcile the earlier #UD snapshot with the later
real-mode vector-13 and IDTR-limit transitions. The owner reports a passing
recovery k-induction proof in `work/protection_recovery_formal/intel_80286_prove`.
The matching BMC and cover, followed by the full exact-source audit, remain
pending. The earlier 36-task #UD/TEST-alias audit described below is historical
to its recorded source snapshot and must not be used as a current-tree result.

The datapath harness independently specifies arithmetic as unsigned arithmetic,
signed range overflow checks, nibble carry/borrow and parity. It also specifies
each documented one-bit shift/rotate for both operand widths. The input space
is unconstrained: every operand, input flags word and operation is covered.
It does not assert architectural values for undefined flags or group /6.
BMC, unbounded proof and reachability each use Z3 at configured depth 2.

The core includes formal/intel_80286_props.sv only with FORMAL. Its sole
environment constraint is initial reset; later reset, data and ready are
unconstrained. There is no fairness assumption. Safety properties cover:

- Documented reset state, real-mode MSW reserved bits, CLTS/LMSW effects and
  explicit exclusion of PE until protected execution is connected.
- Table-register commits only on full operand completion/retirement, loaded
  base/limit byte layout and stable architecture through six-byte bus stalls.
- Asserted ownership of iterative shift/divide states, 0F bus continuations,
  system-store completion and software-event retirement. These rule out
  unreachable instruction/continuation combinations in induction, without
  assuming any instruction bytes or restricting bus data/ready/reset.
- Stable requests and architecture during a stalled fetch.
- Architectural writes only on retirement, completed event delivery or a
  completed string element. Element contracts check exact CX/SI/DI updates,
  unchanged segments and preserved flags for non-comparison strings.
- Diagnostic-stop persistence, halt context while polling/waking, valid FSM
  states and nonzero active shift count.
- Retirement origin, SAHF flag update/preservation and exact conditional-jump IP.

Core BMC uses ABC bmc3 at depth 24. Unbounded Yices k-induction uses configured
depth 12. Yices cover uses depth 64 and reaches fetch, MOV, far jump, HLT,
unsupported/boundary diagnostics, CL shift retirement and immediate-group
retirement, memory/I/O writes, near/far CALL, division, real event delivery,
PUSHA, ENTER, in-range BOUND, vector 5, XLAT, partial REP progress, repeat
completion, comparison early termination and string I/O. Covers are non-vacuity witnesses,
not whole-ISA coverage metrics. All bus command and write-data fields are
checked for stability during stalls. The memory continuation register's valid
return-state set is an asserted induction invariant, not an environment assumption.
Explicit memory_map converts the small register arrays to flip-flops before
backends are generated. Independent instruction vectors supplement the safety
properties; no complete processor equivalence or protected-mode proof is claimed.

The EA harness proves all modular base/index/displacement sums, displacement
lengths and BP-based default-segment selection with unconstrained register
values. Its BMC/prove/cover tasks use Z3 at depth 2 and include wrap witnesses.

The iterative multiply/divide unit has BMC depth 36, induction depth 8 and
cover depth 40 with Yices. Contracts assert accepted operand snapshots, stable
results while busy, restoring-division remainder bounds and countdown progress,
fault preservation, division flag stability and multiply flag preservation.
These are protocol/algorithm invariants, not a complete quotient equivalence
proof. Independent external vectors check arithmetic semantics.

The decimal combinational reference is independently derived from pinned 86Box
1db9ae4 x86_ops_bcd.h, not from RTL. All AX/flag/base inputs are unconstrained;
defined outputs and A3 undefined-bit preservation are compared. BMC/prove/cover
use Z3 depth 2, including whole-AX wrap/borrow and base-zero AAD witnesses.
The CPU asserts divider ownership while busy and the AAM flag snapshot, plus
exact final S/Z/P and preserved DX. These are asserted reachable-state
invariants, not input constraints.

The standalone event controller uses unconstrained transaction inputs, with
only initial reset assumed. A protocol monitor sourced from Intel sections
9.2/9.5 and functional abstraction A8 asserts selection priority, one-entry NMI
retention/blocking, exact vector capture, held delivery, reset cancellation
and no delivery before acknowledgement. It does not model instruction-boundary
semantics. State legality and sampled-edge history are asserted induction
invariants; no bus fairness or forced-ready assumption is used. Z3 runs BMC,
induction and cover at depth 16. Covers witness remembered NMI, priority,
acknowledgement/delivery stalls and reset in both transaction phases.

The core now includes that controller with unconstrained INTR/NMI and vector
acknowledgement inputs. Contracts forbid memory/fetch traffic during boundary
polling and INTA, assert controller/core ownership, preserve outstanding bus
requests and restrict the halt latch to halted/boundary/poll states. The new
cover histories distinguish actual asynchronous entry, halted wake and entry
after a completed partial REP element from ordinary software INT delivery.
These histories are coverage observations, not assumptions or a golden model.
The TF extension asserts first-byte flag sampling and higher-priority debug
selection at an eligible boundary, with asynchronous inputs unconstrained.
A new history distinguishes selected debug delivery from software INT 1.

The standalone protected segment-load checker compares all inputs against an
independent reference derived from 86Box loadseg_2386's accepted-type lists and
decision order, with PCjs's pinned 286 byte layout. No input is constrained.
The reference uses arithmetic selector extraction and enumerated descriptor
types rather than RTL bit tests. BMC/prove/cover use Z3 depth 2; covers include
LDT index zero, null GDT, both not-present fault classes, conforming-code privilege
exemption and the last descriptor ending exactly at FFFF. These component
proofs do not establish descriptor bus/cache integration or protected CPU behavior.

The protected segment-load engine has BMC/cover depth 24 and induction depth
12 with Yices. Only initial reset is assumed; start, request inputs, ready and
read data remain arbitrary. A separate accepted-byte monitor checks captured
metadata, command stability, request snapshots, result stability until done,
eight reads before validation, accessed write before successful publication,
and reset cancellation. Its asserted zero accepted-write count while busy
strengthens induction without restricting the environment. Covers witness a
successful stalled load with busy-start attempts, both pre/post-read faults,
null completion and reset during read/write. Pure validation semantics are
proved separately against the external-artifact reference; this is not a
protected CPU equivalence proof.

The current formal inventory is 40 tasks: twelve component configurations
with BMC/prove/cover (36 tasks), the connected-core BMC/prove/cover (3 tasks),
and one full-core ABC PDR task. Run the full inventory with
`scripts/run_formal.sh`; pass configuration basenames to run selected suites.
Each invocation writes to a fresh `work/formal_runs/run.*` directory unless
`FORMAL_WORK_DIR` selects an existing evidence directory. The runner discovers
task names from each `[tasks]` section, runs component suites before the core,
and leaves the long PDR job last. An interrupted run is incomplete even when
many tasks have PASS status files.

The ordinary CS checker has a separate unconstrained combinational harness
derived from the primary CALL/JMP type enumeration and check order. It checks
type/privilege/presence priority, CALL stack-before-offset priority, special
descriptor deferral, CS RPL normalization and complete table bounds. Covers
witness each fault class, conforming RPL independence, LDT index zero and the
last possible descriptor. Its SBY configuration additionally uses strict net
declarations and `check -assert` to reject an undriven witness signal. Results
are under work/formal/intel_80286_code_check_{bmc,prove,cover}/.

The CS transaction harness independently counts accepted reads/writes and
captures descriptor bytes. It asserts complete request snapshots, immutable
busy context, stable commands/results through stalls, eight-byte reads,
no write for faults/special descriptors, exactly one accepted accessed write
before ordinary-code publication and reset cancellation. Completion packets
are one of fault/special/ordinary and retain prior metadata until the next
completion. BMC/prove/cover use Yices without data/ready/fairness assumptions;
only initial reset constrains the environment. Results are under
work/formal/intel_80286_code_load_{bmc,prove,cover}/.

The cached-access harness compares enumerated primary type permissions and
independently derived low/high intervals for every input. It covers full-size
expand-up, empty expand-down, strict lower boundaries, code/read/write
distinctions, end overflow and unusable SS. Map initialized lookup ROMs to
constant logic before induction (`memory_map; opt`) so the pure combinational
reference does not acquire arbitrary ROM contents in the inductive start.
No input assumptions are used. Current results are under
work/formal/intel_80286_access_check_{bmc,prove,cover}/.

The real-cache prelude adds complete bank reset, A14 limit/access/usability,
real data-base/selector coherence and both legitimate CS-base forms. Hidden
metadata may change only on instruction/event commit, not on intermediate
string elements. Covers witness nonzero MOV SS and LDS cache commits. These
are real-mode invariants while PE remains disabled; they must be replaced by
protected load/commit invariants as that integration is implemented.

After solver completion run `python3 scripts/audit_formal.py` from the design
directory. It requires all bmc/prove/cover tasks for every current SBY config,
PASS status/marker, matching saved task configuration and exact SHA-256 matches
for every RTL/property source snapshot. Missing or stale evidence returns
nonzero; a still-running task cannot count as passed. The audit supports the
simple task/file grammar used here and rejects unsupported syntax. Run
`python3 scripts/test_audit_formal.py` for its nine evidence-rejection fixtures.
Use `--core-work-dir work/reference_formal` to audit a separate core epoch
against current component results. Missing results never fall back to older
passing core tasks.
The audit does not replace proofs, witness inspection or independent oracles.

The cache-bank reference harness uses explicit role cases and primary type
lists to compare selected cache fields, normal/expand-down intervals, the A14
trusted-CS fetch exception, fault classification and physical-address modulo.
No inputs are constrained. Covers witness raw-93 inherited CS fetch, rejection
without trust, denied CS data write, unusable/overflow CS, aliased ES/SS fault
classification, address wrap and valid expand-down data. All three tasks pass
under `work/formal/intel_80286_cached_reference_{bmc,prove,cover}/`.
There are fourteen configurations/40 tasks: twelve component configs, the
connected-core config and a PDR-only connected-core config. The 36-task audit
described below passed for the earlier #UD/TEST-alias source snapshot; it is
not current after the real-mode protection-fault changes. Earlier core
snapshots are archived.

The connected-core harness now checks request count/context, validation before
bus ownership, unchanged architectural state across validation, complete-span
allow for every segmented bus transfer and exact selected-base+offset address.
Fetch must be CS/execute/size 1; held role/offset/span/kind are immutable.
The memory FSM includes MEMORY_CHECK. These invariants and all core proof
snapshots changed; the older live cache epoch cannot certify the new source.

Initial AIG export exposed padding X from variable selection over the 96-bit
base bank. Complete explicit role selections in RTL and the address assertion
remove those undefined padding bits. No assertion or input freedom was weakened.
The independently enumerated frontend was re-proved and its ten compiled
mutants rerun. Current BMC/induction/cover are in separate core work roots;
the aggregate snapshot audit must pass before claiming all 36 current tasks.

## Real-mode #UD and native TEST-alias epoch

The core now separates source-backed invalid encodings from unimplemented
features and captured F6/F7 `/1` TEST aliases. A transition invariant checks
vector 6, the first-prefix saved IP, non-retirement and unchanged GPRs/FLAGS
before frame delivery. A cover witnesses actual `64h` fault entry.
The witness reaches that non-retiring vector-6 entry at step 24 (cover at
`intel_80286_props.sv:242`, `engine_0/trace31` in the completed cover directory).
The earlier #UD/TEST-alias source snapshot passed BMC, induction and all covers
in `work/undefined_final_formal/`; its aggregate audit passed 36/36
exact-source/configuration tasks, recorded in
`work/undefined_complete_formal_audit.json`. It predates the real-mode #GP and
IDTR-limit changes. The current recovery k-induction result is narrower; current
BMC, cover and full audit remain pending. Native LOCK arbitration, complete
opcode validity, protected exception delivery and protected execution remain
open. See [#UD contract](../spec/undefined_opcode.md).
