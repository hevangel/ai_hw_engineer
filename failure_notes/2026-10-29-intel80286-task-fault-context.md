# 80286 incoming-task fault context and hidden segment caches — 2026-10-29

## External evidence and failure

Intel's [80286 and 80287 Programmer's Reference Manual, order 210498-005,
§8.3, printed page 8-6](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=156)
says the new task's registers load before its LDT and segment checks finish.
Faults during those checks run in the incoming task context. The note also
warns that DS/ES can retain nonzero selector values even though they are not
accessible, and that the handler may need to save those values before fixing
them. The page was reviewed in Chrome with `playwright-cli`; the capture is
`design/intel_80286/work/historical_software_current_20261029_23/manual-page156-table.png`.

The implementation updated visible task state when an incoming descriptor
faulted but retained outgoing hidden segment caches. A same-level #GP handler
therefore combined incoming SS:SP with the outgoing SS base, and a handler
read through rejected DS could reach the outgoing task's data base. The
pre-fix unstalled regression reproduced a missing frame on the expected
incoming stack and an outgoing-stack write. No release or upstream change
occurred.

## Cause

`task_entry_fault_context` installed the incoming registers and selectors but
did not replace or invalidate all hidden segment caches on a post-load fault.
Existing task-switch tests checked fault packets, task images, and successful
handler delivery, but did not execute a same-level handler after an incoming
DS fault and inspect the exact stack and data bus traffic. The shared
testbench invariant also rejected hidden-cache transitions before the final
event pulse, so it could not model Intel's documented partial task context.

## Fix and re-verification

The fault path now installs only validated incoming segment and LDTR caches,
invalidates the rest, and sets `cs_trusted` only after CS validation. Each new
TSS load clears staged descriptor caches. The updated two-READY-mode test
checks exact #GP frame words on incoming SS:SP, no outgoing-stack write, a
second #GP for access through rejected DS, and no read from the outgoing DS
base.

Exact-source full simulation passed 198 checks, including 79 protected replay
cases in both READY modes. Exact-source Yosys synthesis passed all 13 targets
and 39 structural checks. The unchanged IBM AT REV1 BIOS passed 196,846 exact
instruction states through ROM-checksum success; the hex helper, IRQ8 and
system-register regressions also passed. Full POST/boot, OS/2 CPGREP on RTL,
current-source connected-core formal and whole-CPU acceptance remain open.
Detailed hashes and evidence paths are in
[`design/intel_80286/report/2026-10-29-task-fault-context.md`](../design/intel_80286/report/2026-10-29-task-fault-context.md).

## Prevention

`AGENTS.md` now requires 286 task-fault tests to execute the handler after a
post-load validation fault, verify that its stack uses incoming SS:SP, and
prove that rejected DS/ES caches cannot expose outgoing task memory. Such
tests must check exact stack writes and bus addresses, not only the exception
packet. The broader independent-oracle and escaped-defect rules remain in
force.
