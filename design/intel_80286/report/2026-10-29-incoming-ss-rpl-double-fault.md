# Incoming SS selector-RPL double-fault coverage

**Date:** 2026-10-29 02:11 UTC  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 row 9, printed page 8-6 (PDF page 156). The table assigns `#SS` to
an invalid incoming stack selector. The manual page was reviewed in Chrome
with Playwright CLI; capture:
`design/intel_80286/work/ss_selector_rpl_double_fault_20261029_17/table-8-1-page156-playwright-cli.png`
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

The incoming CPL-0 task loads SS=`002B`: it selects the writable DPL-0 stack
descriptor at GDT offset `0028`, but carries RPL 3. The direct incoming
selector matrix establishes first-fault `#SS(0028)`. Four new escalation
executions give that fault a malformed vector-12 gate, selecting null-error
`#DF` shutdown, or a valid vector-8 task gate. Both paths pass with READY
immediate and stalled. Checks cover the rejected descriptor and both gate
lookups, final event context, shutdown quiescence, exact faulting TSS save with
SS=`002B`, backlink/busy state, null error push and exact handler successor.

## Verification

- `scripts/preflight.py`: pass.
- Verilator 5.052 `-Wall` CPU runner build: pass. Build fingerprint
  `6fa787ef5618d4a864cdecdf833cebd283347eda0df912518e51e51ed1fae180`;
  the manifest binds `tb/bootstrap.cpp` SHA-256
  `22289668f7e58edfa37f0f45d80f3e1f0c6aba0fe55c5a11a5c83a90b8c1cd89`.
- Focused `Vintel_80286 --iopl-controls`: pass, including four selector-RPL
  shutdown/task-entry executions across both READY modes.
- Full `scripts/run_sim.sh`: exit 0 with 192 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay: 79 cases pass in unstalled and READY-stalled modes;
  its source-bound manifest records `result: PASS`.
- `git diff --check`: pass apart from existing line-ending conversion
  warnings.

The change is testbench-only; no RTL behavior changed, so the existing
13-target Yosys synthesis remains applicable. The Table 8-1 audit now has
incoming SS selector-RPL escalation coverage. Later task-entry fault phases,
current-source connected-core formal proof, authentic software execution and
whole-CPU acceptance remain open. The later DS/ES row-13 work and exact GDT
fixture correction are in the
[DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md).

Evidence is under
`design/intel_80286/work/ss_selector_rpl_double_fault_20261029_17/`.

