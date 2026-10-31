# IDT task-gate event delivery — 2026-10-29

## Result

Added an IDT task-gate regression for CPL1 and CPL2. Across both READY
policies, twelve cases cover external INTR vector 13, software `INT 13h`, and
NMI vector 2 through DPL-0 task gates. External INTR and NMI ignore the gate
DPL and enter the target task without an error word. INTR acknowledges once;
NMI does not acknowledge, is blocked on task entry, and is released by task
IRET. Software `INT` raises #GP with IDT selector error code `006A`; exception
delivery ignores gate DPL and enters the target task with that error word on
its stack.

Both paths check the saved current-task IP, FLAGS, SP, CS and SS; backlink
`0068`; outgoing and incoming busy bits; NT/TS; event packet fields; and
preservation of the interrupted ring stack. The external-INTR path additionally
returns through task IRET and executes the exact interrupted-task successor.
The NMI path checks no INTA transaction and NMI block/release across task
entry/IRET. The software-INT #GP path checks the error word at `SS:007E` and
runs the target handler to its exact HLT successor. No RTL changed in this
slice.

## Source and scope

Intel 210498-005 §9.4 says external interrupts and exceptions ignore the
program CPL while accessing the IDT; Table 9-1 lists the IDT gate checks. I
visually reviewed scanned pages 166 and 168 through `playwright-cli`. Page 166
contains the §9.4 rule and page 168 the gate-check table:
[scanned Intel manual, page 166](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=166),
[page 168](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=168).

This closes the basic CPL1/CPL2 external-INTR, software-INT/#GP, and NMI paths
through an IDT task gate. A follow-up now covers eight incoming-task selector
faults (null, wrong-type and not-present CS; null and not-present SS;
not-present DS/ES; and wrong-type LDTR) under both READY policies. A repair
task handles each fault, task IRET returns to the repaired task, and the exact
resumed successor is checked; see the
[fault-recovery report](2026-10-29-task-gate-fault-recovery.md).
The follow-on [handler-entry report](2026-10-29-task-gate-handler-entry.md)
adds a not-present #TS handler-TSS case that escalates to #DF and recovers by
repair plus task IRET. Other vectors, malformed task-gate entry, other nested
fault combinations, native interrupt-pin timing, connected-core formal and
whole-CPU acceptance remain open.

## Reproduction and evidence

Built in `ai-hw-engineer:latest` with Verilator 5.052, g++ 15.2.0 and `-Wall`:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/task_gate_events_20261029_01 \
  sh design/intel_80286/scripts/build_runner.sh
design/intel_80286/work/task_gate_events_20261029_01/sim/Vintel_80286 \
  --protected-event-task-gate
design/intel_80286/work/task_gate_events_20261029_01/sim/Vintel_80286 \
  --protected-event-ring12-external
design/intel_80286/work/task_gate_events_20261029_01/sim/Vintel_80286
```

All commands exited 0. The task-gate test reports 12/12 cases passed; the
existing CPL1/CPL2 external interrupt/trap-gate test reports 8/8 passed. The
complete default bootstrap reports 108 `PASS:` lines and no `FAIL:` or
`ERROR:` lines. The runner fingerprint is `e5d7f7f02ff5`; the final testbench
source SHA-256 is
`C2D16BF438BE930A67AED21A75ACA4E292AF99B7B7FABA5F67C56686342FB2E5`.

Logs and their SHA-256 values are preserved under the ignored
`design/intel_80286/work/task_gate_events_20261029_01/sim/` directory:

- `protected_event_task_gate.log` — `87E82CECD4338E778F92815076C96E2092A7380EF469A509BD4F1CD9895DC27C`.
- `protected_event_ring12_external.log` — `007B7CB074DB8FAE4C35EB4E87C2F17B9484BD149BAB80D5E31DC3324EE7C6AD`.
- `full_bootstrap.log` — `2D042AD4633232FFFEC2C24C44EC265908D820F2C38ED569EC753BD3F64EDE78`.
- `build.log` — `7F0A511A983415A3A2DABBBF30D0E1897BED86F972977642A387968DC5BC6C31`.
- `build_manifest.json` — `D63B4C2F0661188C07BA31BA7EC141079CB3FFE08EA8D715E490E04AEC99D114`.
- `Vintel_80286` — `D8D310D6377ADB455DC5D3882EC720A8FAA3C88495D8D6CF65C0A52D31D7FEEC`.

Manual screenshots from the Playwright CLI review are also retained in the
ignored `design/intel_80286/work/task_switch_audit_20261029_46/` directory.

Current-source connected-core formal, full POST/boot, OS/2 CPGREP on RTL,
other protected fault combinations, native-interface qualification and
whole-CPU acceptance remain open. Issue #80 remains Open/Building with Agent
Codex, Path `ai_hw_engineer/design/intel_80286`, first Start date
`2026-10-23`, Sprint 1. The initial 8-case checkpoint is [comment 6488920899](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6488920899);
the expanded 12-case checkpoint was posted and read back in
[comment 6489004572](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489004572).
