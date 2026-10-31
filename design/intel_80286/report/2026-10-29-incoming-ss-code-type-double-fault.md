# Incoming SS descriptor-type double-fault coverage

**Date:** 2026-10-29 02:05 UTC  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 row 10, printed page 8-6 (PDF page 156). The row requires the
incoming stack segment to be writable data and assigns `#GP` for a violation.
The source was opened in Chrome and reviewed with Playwright CLI; the capture is
`design/intel_80286/work/ss_code_type_double_fault_20261029_16/table-8-1-page156-playwright-cli.png`
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

The incoming task now checks both present descriptor types that violate row
10: a read-only data descriptor and a readable code descriptor. For each, an
invalid vector-13 gate causes the first-fault `#GP` to escalate to null-error
`#DF` and sticky shutdown; a second execution uses a valid vector-8 task gate
and checks successful #DF entry. Each path runs with READY immediate and
stalled. The tests check the rejected descriptor read, both gate lookups,
the exact event context, incoming TSS save, backlink and busy bits, null error
push, handler successor, and shutdown quiescence where applicable. The two
descriptor classes add four shutdown and four successful #DF-task executions.

## Verification

- `scripts/preflight.py`: pass.
- Verilator 5.052 `-Wall` CPU runner build: pass. Build fingerprint
  `ade45840ca1fdda9a2886735be2a304b90c4beb720a22847e19851ab432d754a`;
  the manifest binds `tb/bootstrap.cpp` SHA-256
  `0bd124c8d7ef49e4c8dc9596c6dd7f0632079890637522e2825160576d9eaede`.
- Focused `Vintel_80286 --iopl-controls`: pass, including all eight descriptor
  type/READY/escalation combinations.
- Full `scripts/run_sim.sh`: exit 0 with 191 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay: 79 cases pass in unstalled and READY-stalled modes;
  the generated manifest records `result: PASS` and binds the run to its
  source files and binary hash.
- `git diff --check`: pass apart from existing line-ending conversion
  warnings.

The change is testbench-only; no RTL behavior changed, so the existing
13-target Yosys synthesis result remains applicable. The table audit now closes
the incoming-CS GDT-limit and incoming-SS code-type rows. Later task-entry
phases, current-source connected-core formal proof, authentic software
execution and whole-CPU acceptance remain open. The later DS/ES row-13
escalation and exact GDT fixture correction are recorded in the
[DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md).

Evidence is under
`design/intel_80286/work/ss_code_type_double_fault_20261029_16/`.

