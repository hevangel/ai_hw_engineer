# Full 80286 completion requirements

The project objective is a complete, independently verified Intel 80286
implementation. A passing subset regression, synthesis run, or bounded
protected-mode slice does not complete that objective. The architectural
reference is Intel order 210498-005; later x86 behavior must not be assumed
when the 286 documentation is silent.

| Area | Completion evidence | Current state |
|---|---|---|
| Reset and real-mode compatibility | Documented reset/cache behavior, exact instruction traces, historical software, and checked boundary/reset cases | Partial; prior evidence exists but the harness and report set need recovery and exact-source re-audit |
| Instruction set and system instructions | Every documented instruction and mode restriction accounted for; exact PC, flags, register, memory, and I/O effects; explicit handling for undefined encodings | Incomplete; protected-mode system behavior remains under development |
| Protected segmentation | Descriptor-table lookup and validation; GDT/LDT and code/data/stack cache commit; privilege and access checks; precise faults | Incomplete; a bounded ring-0 GDT path is the current milestone |
| Events and task state | Protected IDT delivery, interrupt/exception frame rules, IRET, privilege transitions, task register/TSS and task switching, plus defined escalation behavior | Incomplete; same-level vector-13 delivery/IRET retry is only a narrow slice |
| Bus and restart behavior | Stable requests through waits, exclusive ownership, reset cancellation, whole-span access checks, precise instruction restart, and externally visible I/O ordering | Partial; protected read recovery and INS destination fault/handler repair have directed coverage; native INS port timing and other string faults remain open |
| Independent evidence | External-oracle instruction cases, real historical software, reviewed assumptions, formal assertions/proofs/covers, strict lint, mutation checks, and synthesis | Incomplete; OS/2 CPGREP harness and independent trace remain open |
| Release gate | One reproducible full `run_all.sh` run against a source-identified snapshot, with all required stages and no stale or missing outputs | Not achieved |

## Completion rules

- Keep source-backed decisions and explicit `ASSUMPTION:` entries in the spec
  and RTL. Validate assumptions against an independent 286 artifact or real
  software before sign-off.
- Use an independent external artifact for the instruction oracle; do not
  derive the expected model by re-reading this RTL.
- Assert exact post-instruction PC and next-executed instruction. Do not add
  padding that tolerates an unknown control-flow landing.
- Run cover tasks and check non-vacuity. Bind every PASS to exact source hashes,
  tool identity, command, and retained log/result paths.
- Include actual historical software in the design's release regression. The
  selected first workload is Microsoft OS/2 SDK 1.00 `CPGREP.EXE`; its install
  and run harness must be completed and its behavior checked against an
  independent 286 trace.

See the [continuation plan](../../../plans/286/README.md) and
[current status](../../../plans/286/STATUS.md) for task order and live evidence.
