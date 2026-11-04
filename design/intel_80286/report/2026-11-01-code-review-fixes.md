# 2026-11-01 - Code review fixes (issue #80 review of f8b528d)

Branch `design/intel-80286-review-fixes`, from `main` at `f8b528d`. This
report answers the eight items of the 2026-10-31 code review posted on
[issue #80](https://github.com/hevangel/ai_hw_engineer/issues/80). The
post-mortem is
[failure_notes/2026-11-01-intel80286-review-bus-strobes-ext.md](../../../failure_notes/2026-11-01-intel80286-review-bus-strobes-ext.md).

## Sources

Quotes were taken from the text layer of these scans:

- Intel 210498-005, 80286 and 80287 Programmer's Reference Manual (1987):
  section 9.4 (printed page 9-5), 9.6.2 (9-10), 11.6 (11-7), Appendix B
  (B-8, B-49, B-50), Table 9-5.
- Intel 210760-002, 80286 Hardware Reference Manual (1987): pages 3-12,
  3-13, 3-15, 3-18, 3-19, 3-23, 3-41, 3-42, 3-67, 3-68.
- Intel 210253-009 80286 data sheet, 210453-004 82284 data sheet and
  210471-005 82288 data sheet, in the 1986 Intel Microsystem Components
  Handbook, Volume I (pages 4-3, 4-11, 4-14, 4-25, 4-26, 4-141, 4-150).
- Intersil/Renesas 82C284 data sheet FN2966.

## Items

| # | Review item | Result |
|---|---|---|
| 1 | 82288 asserts MRDC# on I/O reads | Fixed. MRDC# requires `held_memory`, per the 82288 command table (page 4-150). The bench now checks that each read asserts exactly one command. |
| 2 | Spurious NMI after reset | Fixed. The edge detector samples the NMI level through reset. NMI is edge-triggered (210760-002 p. 3-12) and not recognized during reset (p. 3-67). |
| 3 | Pending NMI discarded in shutdown | Kept and cited. A pending NMI still exits shutdown. The pending NMI is dropped only after an NMI recovery attempt faulted, when 210498-005 9.6.2 says shutdown is exited only by RESET. No source states what happens to an NMI arriving after that point. |
| 4 | 82C284 reset model | Fixed. Power-up value "RES asserted" (assumption A27); `RES_SYNC_DELAY_CLKS` outside 1-2 is rejected at elaboration. |
| 5 | Native bus drops invalid beats silently | Fixed. `protocol_error_o` latches until RESET; simulation stops with `$fatal` unless `FATAL_ON_PROTOCOL_ERROR=0`. |
| 6 | No pipelined addressing | Documented as an implementation limit in [native_bus_interface.md](../spec/native_bus_interface.md): at least three processor clocks per zero-wait transfer instead of two. Modeling the overlap needs the core to issue the next beat during `Tc` and is open work. |
| 7 | Error codes never carry EXT | Fixed in the core, not the check units. `enter_event` sets EXT when the fault arises while INTR, NMI, single step or vector 7/9/16 is being delivered, including incoming-task faults of a task gate (App. B p. B-8, Table 9-5). The check units stay EXT-free by contract ([spec.md](../spec/spec.md)). Delivery faults that the core still reports as a development stop are not covered. |
| 8 | Core structure | Not changed here. Converting the 7-bit state constants to an enum and splitting the sequencer rewrites the verified core; proposed as a separate issue. |

Formal bookkeeping found while running the connected-core BMC: several lists
in `formal/intel_80286_props.sv` predated the ESC register-save and
task-switch states (state upper bound, `memory_return` continuations,
`retire_o` and `event_o` sources, event-delivery path, segment-load
publication during a task switch). The connected-core BMC had been failing on
`main` for this reason. A static audit of every state list against the RTL
drove one set of fixes; uncertain or strengthening-only findings were left
for later.

## Verification

All runs used the `ai-hw-engineer:latest` image (Verilator 5.052, Yosys
0.69).

| Check | Result |
|---|---|
| `verilator --lint-only -Wall`, changed modules and full core | Clean |
| `-GRES_SYNC_DELAY_CLKS=3` | Rejected at elaboration, as intended |
| `run_82288.sh`, `run_82c284_reset.sh` (1 and 2 CLK), `run_native_bus.sh`, `run_native_cpu.sh`, `run_native_cpu_82c284_reset.sh`, `run_native_core.sh` | Pass |
| `run_segment_check.sh` / `run_code_check.sh` | Pass, 16413 / 98612 cases |
| `run_event_control.sh` | Pass, 8024 checks |
| `run_event_mutations.py` | All 7 mutations detected |
| `run_formal.sh intel_80286_event_control.sby` | Preflight, BMC, prove and 7 covers pass |
| `run_sim.sh` (full) | Pass, 218 PASS lines, exit 0 |
| `run_protected_mode_replay.sh` | Pass, 79 PASS lines |
| `run_at_bios_native.sh` / `run_at_timer_bios.sh` | Pass |
| `run_synth.sh` | 13 targets, `check -assert` 0 problems |
| `preflight.py` (property inventory) | Pass |
| `intel_80286.sby` BMC (`abc bmc3`), final tree | Pass, no assertion in 24 frames, 1:03:41 |
| `test_audit_formal.py` | 17 tests OK |

The connected-core BMC failed on unmodified `main` (stale state bound at
step 10); it passes here only after the bookkeeping fixes above.

## Connected-core k-induction (follow-up, 2026-11-02)

The `prove` task (`smtbmc yices`, depth 12) was run 42 times. The base case
passed every time, so no assertion fails within 12 cycles of reset. Each
induction failure was decoded from its trace and fixed either by stating a
missing invariant or by hardening the RTL; none was left by weakening an
assertion without an RTL or Intel reason.

RTL changes found this way (all re-simulated: `run_sim.sh` 218 PASS, exit 0):

- A task-gate NMI handler now clears shutdown recovery at `TASK_ENTRY_COMMIT`
  (Intel 210498-005 9.6.2). Before, any later fault in the NMI task put the
  CPU back into shutdown.
- `enter_event` clears abandoned CALL-gate, RETF and IRET transfer flags and
  their helpers, and task-switch flags; `EVENT_START` and shutdown entry clear
  the CALL/JMP task-switch kind. Stale flags could steer a later delivery's
  stack load or misroute a task-gate event as a direct switch.
- The inner-stack segment load in `CALL_STACK_SELECT`/`EVENT_STACK_SELECT`
  starts only with the CPU bus grant, matching the state's own advance.
- NMI cannot exit shutdown after a failed NMI recovery (9.6.2: RESET only).

About 35 invariants were added (opcode ownership of far-transfer states,
descriptor engines tied to their wait states, task-switch and delivery
exclusivity, PE stickiness, shutdown precedence, `cs_trusted`), and several
stale properties were corrected (NMI exit from shutdown, #DF IDT-limit
shutdown, task-entry fault context, IRET #SS(0)). Property count: 340.

## Event-delivery development stops replaced (2026-11-02)

Fourteen protected-mode handler-invocation checks that stopped the core (`STOPPED`, `fault_code_o=3`) now raise the Intel-specified exception: a fault while delivering #DE/#TS/#NP/#SS/#GP becomes #DF, a fault while delivering #DF shuts down, and other events take #GP/#NP/#TS/#SS with App. B error codes plus EXT (210498-005 9.6.2, App. B B-49/B-50, Table 8-1). ASSUMPTION A28 covers a current TSS too short for the inner SS:SP pair. New directed tests: `protected_event_delivery_faults` (10 runs), the empty-IDT #UD to #GP to #DF to shutdown decode case, and `protected_shutdown_nmi_task_gate_recovery` (fails with the task-gate NMI fix reverted). Both shutdown-NMI tests now run in the default list. `run_sim.sh` 221 PASS, exit 0; AT BIOS native and timer runs pass against Unicorn.

Status: induction is not yet closed; run 42 still fails on an unstated fact
(the `0F` continuation list). The `cover` task (depth 64) has reached 45 of 89
covers after 22 hours at step 33. This remains bounded evidence, not a proof.


## Development stops replaced and k-induction closed (2026-11-03)

RTL changes, each with directed tests that fail on the old RTL or that check
the Intel-specified result:

- `b4a5d41`: protected POP ES/SS/DS and LES/LDS load through the
  segment-load engine with MOV Sreg checks. They commit SP or the offset
  register with the segment, and a fault restarts the instruction (App. B).
  The segment-load stack rules were driven by a stale ModRM byte, so a task
  gate after `MOV SS` rejected a legal read-only incoming DS or ES. See
  `failure_notes/2026-11-03-intel80286-task-switch-stale-modrm-stack-check.md`.
- `f1b8e4a`: stack wraparound and real-mode shutdown now follow the 1985
  iAPX 286 PRM (App. A "Shutdown", Table 5-2, App. B). Assumption A29 covers
  ENTER. Test `stack_wrap_contracts` has 20 cases.
- `ec74f75`: ESC D8h-DFh runs the CPU-side 80287 command phase. Its contract
  matches 4,967 physical Harris D8 captures, and assumption A30 covers
  D9h-DFh (see `2026-11-03-esc-command-phase.md`).

Development stops in the core went from 27 to 13. The remaining stops are:
- ESC memory forms in protected mode, which need the processor extension
  data channel.
- Real-mode aligned IRET/RETF frames that wrap past FFFF.
- NT IRET when the current-TSS descriptor is invalid.
- Decode fallbacks.

Connected-core k-induction is closed. Prove run 94 (`smtbmc yices`, depth 12)
passes the base case and induction for all 390 core assertions:
"successful proof by k-induction". Runs 50-93 added invariants. They tie the
far-transfer, task-switch, event-stack and ESC states to their opcodes, ModRM
forms and owning flags, and require decode-valid ModRM in every post-decode
stage.

Several stale properties were also corrected:
- An outer-level IRET requests CS offset 0.
- A task JMP also clears the busy bit in `TASK_RETURN_CLEAR_BUSY`.
- The #DF handler must be a task gate (9.6.2).
- Real-mode exception 8 or 13 outside the IDT limit shuts down.
- A real-mode NMI may recover from shutdown.

The cover run on the earlier RTL was stopped at 45 of 89 covers after 42
hours. It has been restarted on the final tree.
