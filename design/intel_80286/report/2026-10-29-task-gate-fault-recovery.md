# IDT task-gate fault recovery and task IRET — 2026-10-29

## Result

Expanded `--protected-event-task-gate` to recover from eight incoming-task
validation faults under both READY policies, for 16 recovery executions:

| Incoming selector fault | Exception | Handler repair |
| --- | --- | --- |
| Null CS | #TS(0000) | Install valid CS in saved TSS |
| Wrong-type CS | #TS(00C0) | Install valid CS in saved TSS |
| Not-present CS | #NP(00A0) | Install valid CS in saved TSS |
| Null SS | #SS(0000) | Install valid SS in saved TSS |
| Not-present SS | #SS(00A8) | Install valid SS in saved TSS |
| Not-present DS | #NP(00B0) | Repair saved DS to null |
| Not-present ES | #NP(00B0) | Repair saved ES to null |
| Wrong-type LDTR | #TS(00B8) | Repair saved LDTR to null |

An external INTR first enters the task with the invalid incoming selector. The
task-switch fault is delivered through a second IDT task gate to a valid
handler task. The handler repairs the exact selector in the faulting task's
saved TSS and executes task IRET. The returned task reaches its exact NOP/HLT
successor.

Assertions check the exception vector and selector error code, saved TSS
registers, backlinks, all task busy bits, the handler error push and repair
write, restored segment selectors, and the resumed successor. Together with
the 12 existing external-INTR, software-INT/#GP and NMI event cases, the
focused option passes 28 executions. No RTL changed.

## Source review

Intel 210498-005 §8.3, scanned page 156, states that task registers are loaded
before incoming segment validation; faults then run in the new task context,
and exception handlers must account for unusable incoming DS/ES state. Section
8.4, scanned page 157, describes the interrupt task's backlink and NT state,
and says task IRET switches to the backlink task. I reviewed both scanned
pages visually using Playwright CLI. Screenshots are preserved in the ignored
work directory.

- [Intel manual, scanned page 156](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156)
- [Intel manual, scanned page 157](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=157)

This covers repair-and-IRET for the eight listed incoming-task faults. Faults
during task-gate handler entry, malformed gates, other nested delivery
failures, current-source connected-core formal, native timing and whole-CPU
acceptance remain open.

## Verification

Built in `ai-hw-engineer:latest` with Verilator 5.052, g++ 15.2.0 and `-Wall`.
Runner fingerprint:
`e1c4f8629b7d5493ebf90039c9173eb4281e31ecea6c56b39fe6b73cfef421cb`.

- `--protected-event-task-gate`: exit 0; 12 event cases and 16 task-entry
  fault-recovery executions pass.
- Full default bootstrap: exit 0; 109 `PASS:` lines, zero `FAIL:` or `ERROR:`
  lines.

The exact commands, logs, binary and build manifest are under the ignored
`design/intel_80286/work/task_gate_fault_recovery_20261029_02/sim/` directory.
Source screenshots are under
`design/intel_80286/work/task_switch_audit_20261029_46/`.

| Artifact | SHA-256 |
| --- | --- |
| `tb/bootstrap.cpp` | `749B6EC68A32C040A14B9F9FE2801930EC987A0C020D6CFC935BBA193B34C210` |
| `build.log` | `EDBDA246C562839CD406277FF8026AB14BC9E8A55128C72436F21377C27FBBED` |
| `build_manifest.json` | `187EFBA720F5FD7A40100AE6FB6F1ED882B762133EF20932542168CE7C2F547F` |
| `Vintel_80286` | `D4359A42412ED4689563827D5B3FE591E87F1C8D4299BB6657A04D8F91AF161A` |
| Focused log | `A9F083D970B6735FC13FA76AE36671CD6096A974B46C0D09737304A80F47091F` |
| Full bootstrap log | `D87BA49C01F814D07F3C1188DDE249CD783993788B2BE5B872A10C95EB053663` |
| Page 156 screenshot | `512F82BF49B681115F54A2F272FA946B8CE54759A93FD7BDD0F4C9242FA9D4AB` |
| Page 157 screenshot | `BDFA72343840ED5BEF683721E8A6ED366DF7C807FA28FF38CE5DD20DC54C5D48` |

The 06:00 UTC checkpoint was posted and read back in
[issue comment 6489249590](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489249590).
