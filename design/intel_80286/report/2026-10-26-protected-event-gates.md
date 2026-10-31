# Protected interrupt and trap gate checkpoint

## Scope

This checkpoint implements protected IDT interrupt-gate (type 6) and trap-gate
(type 7) delivery from a reachable CPL-3 program to a more privileged,
nonconforming code target. A privilege change selects the target's SPn:SSn pair
from the current 80286 TSS, validates the new stack, checks the complete frame
span, writes the outer event frame, then publishes SS:SP and CS:IP together.
Interrupt-gate entry clears IF and TF; trap-gate entry preserves IF and clears
TF. Software `INT n` applies the gate-DPL check and denied access becomes
#GP(selector); processor exceptions ignore gate DPL.

The behavior follows Intel 210498-005 §9.4, the 286 gate/interrupt tables and
Figure 9-4. The [Intel Programmer's Reference Manual](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
is the primary source. Modern x86 behavior is not used to fill 286-specific
rules.

## Directed evidence

The `--protected-event-outer` suite covers:

- CPL-3 #GP delivery through an interrupt gate and a trap gate.
- Software `INT` gate-DPL rejection through each gate type, producing
  #GP(006A).
- Both immediate-ready and stalled READY operation for each scenario.
- TSS stack-pair access before new SS descriptor validation, complete frame
  bytes/order, no writes to the old user stack, IF/TF effects, handler repair,
  and outer IRET to the exact instruction successor.

All eight scenarios pass. The `--system-decode` check also passes its four
invalid protected selector-group encodings. The complete `bootstrap` suite
passes every reported real-mode, event, selector, CALL-gate, return, reset,
stall and protected replay-setup case against the same runner binary.

Six strict-compiled mutations are detected by the matching protected-segment
and event suites. The five event-path mutations cover wrong saved PC, missing
error word, early CS/cache publication, reversed software-INT DPL comparison
and interrupt-gate IF not cleared. The sixth checks that a failed cached
segment permission check is not ignored. Suite output and mutant binary hashes
are retained in
`work/protected_event_mutations_20261026_04/results.json` with each mutant's
build and run logs.

## Reproducible evidence

Evidence directory:
`work/protected_event_outer_20261026_07/`.

- Focused result: `protected_event_outer.log`.
- Complete run: `full_bootstrap.log`.
- Runner manifest and binary: `build/build_manifest.json` and
  `build/Vintel_80286`.
- Verilator: 5.052 (`--cc --exe --build -j 2 -Wall --top-module intel_80286`).
- Build fingerprint: `e9ca9902fb57e97a94d408a0f765424bc01932e1bedb8535f557a0a71542d6f3`.
- Runner SHA-256: `46f647eaea4fbe0681e19a0fe328ca58076eb0eedac878f418973eaba92bf5a2`.
- Core RTL SHA-256: `7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1`.
- CPU-property SHA-256: `0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`.
- Bootstrap source SHA-256: `247aebddec6991aabc39367332a5f279d66d5da001d99dfffbbfd156c8fd8741`.
- Mutation results SHA-256: `f895dfd9ac59d99e01cbb09a5ab437d86a55f60603fe348f624074d33b16e15c`.

The full core also passes Yosys 0.69 synthesis and `check -assert` with zero
problems and 40,652 cells. Its exact command, 14 input RTL hashes, log hash
and JSON netlist hash are recorded in
`work/protected_event_outer_20261026_01/synthesis/synthesis_manifest.json`;
the log and netlist are retained alongside the manifest.

The release preflight passes after refreshing the reviewed property inventory.
The current CPU property file has 285 assertions, one assumption and 49 covers.
The full design helper suite passes 78 tests (one POSIX-only test skipped).

The depth-24 connected-core ABC BMC completed `PASS 0 2293` at 22:49:18 UTC
with no counterexample through 24 frames. Its manifest records RTL SHA-256
`7ad3e9a821f87640c632bfef1294a612a091617b7a9a7e88692c2eee9e97cea1` and
the pre-refinement CPU-property SHA-256
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`.

The depth-12 prove on that property snapshot passed its base case and returned
`UNKNOWN` at induction on `intel_80286_props.sv:213–214`. Its induction-only
witness exposed an assertion that conflated event-stack validation with an
ordinary DS load. Later `_02`–`_07` induction witnesses exposed an obsolete
state bound, incomplete event-packet provenance and the need to constrain
old-stack preflight before TSS stack activation. The properties were refined
against these traces; no reset-reachable counterexample has been found.

The `_08` run passed its depth-12 base case but returned `UNKNOWN` at
induction on `intel_80286_props.sv:74`. Its induction-only witness begins in
`EVENT_STACK_SELECT` with PE clear and no active event; the resulting TSS stack
validation changes the stack cache. No reset-reachable counterexample was
found. The witness, staged sources and manifest are retained under
`work/formal_runs/protected_event_outer_20261026_08/core_prove/`. The property
set now requires exclusive protected IDT states to retain a valid active
protected event packet.

Current CPU-property SHA-256 is
`5055f212d8397f2505bf6e6c681758146547167cb4b942e785564f988ea2e874`, with 290
assertions, one assumption and 49 covers. Depth-12 Yices prove `_20` passed its
base case but returned `UNKNOWN` at induction on `intel_80286_props.sv:160`.
Its induction-only witness starts in `CODE_LOAD_WAIT` with PE clear and fails
the PE ownership invariant; no reset-reachable counterexample was established.
The manifest, staged sources and witness are under
`work/formal_runs/protected_event_outer_20261026_20/core_prove/`. Runs `_12`–
`_20` all passed the depth-12 base case but returned `UNKNOWN` at induction.
Their traces exposed stale packet fields, unowned TSS stack state, real-mode
entries into protected descriptor waits, and a far-return continuation paired
with an invalid opcode. The properties now bind interrupt packet checks to
active valid delivery, constrain stack markers to event paths, require PE in
descriptor waits and validate the FAR_RETURN_DONE opcode. These are
induction-only witnesses; no reset-reachable counterexample has been found and
no current-snapshot induction proof has passed. The earlier BMC remains valid
only for pre-refinement CPU-property SHA-256
`0a05576210b770e0647ad2e7615402476ad5cd86b3608cfaf79be69eb9e32703`. The
matching current-source depth-24 ABC BMC now passes (`PASS 0 2055`, no
counterexample through 24 frames), and all 36 component formal tasks pass on
current sources. Core prove `_21` repeats the line-160 induction-only
`UNKNOWN` from `_20`. The current exact-source audit is 37/40. At 2026-10-27
08:03 UTC, matching the reached-cover log to the 49 CPU assertions shows
38/49 reached (11 remain). There are 43 generated VCDs; the newest is a
`multiply_divide` component witness at step 32, so the CPU count is unchanged.
The cover solver is at step 32. The outstanding CPU goals target async
REP/debug events, F7 /6 and PUSHA, protected event error-frame write and
outer-IRET code-load commit, PE-enabled CS and DS/ES/SS cache transitions,
and vector-8 IDT-limit fault delivery (properties 485, 486, 697, 699, 783-788
and 790). SBY logged a 30-minute cover wait at 07:22:57 UTC, with Yices still
active. SBY logged another 30-minute wait at 08:02:12 UTC. The previous PDR
anytime pass ended at frame 29 with 366 proven outputs and 28 timeouts (latest
on output 137); ABC started a new clause-reusing pass and is at frame 5 with
two timeouts, latest on output 367.
Both runs are still active;
no full proof or cover pass is claimed.
Run evidence is under
`work/formal_runs/protected_event_outer_20261027_21/`. See the
[latest issue checkpoint](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6436754143).
The previous `_29` induction run and `_30` PDR attempt
predate these event-gate changes and are not evidence for this source snapshot.

## Remaining work

This checkpoint does not implement task gates or task switching. Failure while
reading the IDT gate, validating the handler, selecting the TSS stack, or
building the frame still stops diagnostically; nested-fault escalation,
double-fault task delivery and 80286 shutdown are not implemented. The
remaining vector/error-code matrix, CPL1/CPL2 event transitions, native
interrupt-pin timing, current-source proof/cover/PDR, independent historical
software and full-chip release gate remain open.
