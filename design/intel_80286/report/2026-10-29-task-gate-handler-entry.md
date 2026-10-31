# Task-gate handler-entry fault recovery — 2026-10-29

## Follow-up: unavailable #DF target TSS — 06:40 UTC

The same #TS handler-entry fault now also runs with the #DF task-gate target
TSS marked not present. Both READY policies enter shutdown with vector 8,
zero error code and the first fault's saved CS:IP, FLAGS and SP. The target
TSS is not accessed; its backlink sentinel and descriptor remain unchanged,
and the original task's backlink and busy state are retained. Eight further
cycles check that shutdown stays active and issues no data transfer. Two
successful #DF recovery cases still pass. No RTL changed in this follow-up.

The focused task-gate option passes 32 executions (12 event, 16 incoming-task
recovery, 2 handler-entry recovery and 2 #DF target shutdown); the full
bootstrap passes 110 `PASS:` lines with no `FAIL:`/`ERROR:` lines. Verilator
5.052 `-Wall` runner fingerprint:
`b42b86ebd6ae34d7ab8673d3009aa2d7c26d5faf1810d7229bebf295c5b8b709`.
All 38 source entries in its build manifest match the current worktree.
Evidence is retained in the ignored directory
`design/intel_80286/work/task_gate_df_target_shutdown_20261029_01/sim/`:

- `bootstrap.cpp` SHA-256: `06535B6EB57FBEBE48092CAE7B2406949A5759DF0130E48E6A7A77A4E745BCE5`.
- `build_manifest.json` SHA-256: `E7A9FE5D6180FCD1DEBDED33938322FA231A3ED433DD320901F501AA04A030E7`.
- `Vintel_80286` SHA-256: `82CD7B1E0B72A02F3D721432697A7225EE890B79BA453425D2D9C2242008BACC`.
- `focused.log` SHA-256: `B8D6AEAC248455B00E5A6498E31051D64CF10A873D66E7EA3D38DA418529F0B2`.
- `full_bootstrap.log` SHA-256: `5B1B4B4C533E89C2532FB8F1BB540F04B063CA85F5DE868E5120F93A445E512D`.

The checkpoint was posted and read back in
[issue comment 6489860781](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489860781).

## Result

Added a protected-mode regression for a fault while an exception task gate is
loading its handler task. An external INTR enters a task whose CS is null,
raising #TS. The #TS task-gate target TSS is marked not present, so delivery of
that contributory exception raises #NP. The core now escalates this nested
contributory fault to #DF, enters a valid #DF task gate, and preserves the
original faulting task's saved context. The #DF handler repairs the original
TSS CS selector, task-IRETs back, and verifies that the resumed task executes
the exact NOP then HLT successor.

The case runs with READY asserted and stalled. Both executions check the #DF
event packet and null error word, saved TSS selector, task backlink/busy/NT/TS
state, repair write, task-IRET destination, and exact resumed successor. The
change also updates `TASK_GATE_TSS_CHECK`: a target-TSS protection failure
while delivering a contributory exception enters #DF with error word zero and
returns to event delivery while retaining the first fault's context. A failure
while already delivering #DF still enters shutdown.

## Architectural source

Reviewed Intel order 210498-005, §9.6.2 and Table 9-3, using `playwright-cli`.
The source describes the double-fault pairing for contributory exceptions and
recommends a task gate for #DF. The local screenshots are from scanned pages
171 and 172:

- [Table 9-3, scanned page 171](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=171)
- [§9.6.2, scanned page 172](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=172)

Screenshot SHA-256 values are `4812E84D2269C497557F2254D9CE4703F9F4693FBE249723F008AC64C8AEB07E`
for page 171 and
`78AC1D2EF0E568E5CB583CDE0CD402B6D6F1E814D2A5C1676EF4DFDCEC96D26A` for page
172. Both images are retained in the ignored work evidence directory
`design/intel_80286/work/task_gate_handler_entry_20261029_01/source/`.

## Reproduction and evidence

Built in `ai-hw-engineer:latest` with Verilator 5.052, g++ 15.2.0 and `-Wall`.
The build runner fingerprint is
`f72e6175cdf76c4d9ee92d38ef7535843dbe36d1e7c6f52fd6aeebab5e0b5f0f`.
The focused `--protected-event-task-gate` run reports 12 event cases, 16
incoming-task recovery executions and 2 handler-entry recovery executions
passed (30 total). The full bootstrap has 110 `PASS:` lines and zero
`FAIL:`/`ERROR:` lines.

The compiled runner and logs are retained under
`design/intel_80286/work/task_gate_handler_entry_20261029_01/sim/`:

- `bootstrap.cpp` SHA-256: `4C36B754B7D917B5A2932176A55A9900FF97463C53F553EA05A0F670EC8819DA`.
- `intel_80286.sv` SHA-256: `A3323E45226C03352EA63924437A3B30B92B90A784D86E15B3C087E8AE2F92CE`.
- `build.log` SHA-256: `47DBCE513832BCE277600E2495335C82A7727AAA4C35407A30207F54DD84D483`.
- `build_manifest.json` SHA-256: `EA43B6A137AB87DD2FEE96E4AB8D3E7977AA54CF4158AD9FE8B49CC70091E579`.
- `Vintel_80286` SHA-256: `5FA789FE4DFA81EDB7ED2506528C63DE471A60961E15B32A9165C0BF45EB810A`.
- `task_gate_handler_entry_focused.log` SHA-256: `904DD122AD375F72BBF09544E054CF340EE603FCE95AAF65BA61232A66454037`.
- `full_bootstrap.log` SHA-256: `E38FF24833E0B471842B2F5100AA75AA59B4AE3195312EBDA9D3BC9BA623AE66`.

The source snapshot, exact command manifest, full log and focused log are the
reproduction record; no test was rerun after this documentation-only update.
The issue checkpoint was posted and read back in
[comment 6489742960](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489742960).

## Scope and remaining work

This covers a not-present #TS task-gate target TSS while delivering a
contributory #TS, followed by successful #DF task-gate delivery and repair.
It is not a full matrix of handler-entry failures, other failures while entering
the #DF handler, all exception-pair combinations, or shutdown paths. Current-source
connected-core formal, full POST/boot, OS/2 CPGREP on RTL, native-interface
qualification and whole-CPU acceptance remain open.
