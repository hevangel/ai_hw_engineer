# Incoming CS GDT-limit double-fault coverage

**Date:** 2026-10-29 02:05 UTC  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 row 6, printed page 8-6 (PDF page 156). The source capture from
Chrome/Playwright CLI is preserved at
`design/intel_80286/work/ss_code_type_double_fault_20261029_16/table-8-1-page156-playwright-cli.png`
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

With GDT limit `0187`, incoming CS selector `0188` raises `#TS(0188)` without
reading the out-of-limit descriptor. Four post-transfer executions cover an
invalid vector-10 gate followed by null-error #DF shutdown and a valid vector-8
task gate, both with READY immediate and stalled. The cases check the final
event context, absence of an out-of-limit read, both gate lookups, shutdown
quiescence, the exact faulting TSS image, task backlink/busy state, null error
push and exact handler successor.

## Verification

The cases passed in the focused `Vintel_80286 --iopl-controls` run and the full
`scripts/run_sim.sh` run. The Verilator 5.052 `-Wall` runner manifest has
fingerprint `ade45840ca1fdda9a2886735be2a304b90c4beb720a22847e19851ab432d754a`
and records `tb/bootstrap.cpp` SHA-256
`0bd124c8d7ef49e4c8dc9596c6dd7f0632079890637522e2825160576d9eaede`. The full
simulation exits 0 with 191 `PASS:` lines and no `FAIL:` or `ERROR:` lines;
protected replay passes 79 cases in each READY mode. This run also includes the
incoming-SS descriptor-type tests documented in the
[SS code-type report](2026-10-29-incoming-ss-code-type-double-fault.md).

These changes are testbench-only, so existing synthesis evidence remains
applicable. Incoming SS selector-RPL escalation and DS TI/null-LDTR and DS/ES
GDT-limit escalation remain open, along with current-source connected-core
formal proof, authentic software execution and whole-CPU acceptance.

Evidence is under
`design/intel_80286/work/ss_code_type_double_fault_20261029_16/`.

## Exact-boundary fixture follow-up

The 2026-10-29 02:22 UTC fixture audit found that the shared incoming-task
helper had placed `0187` in IDTR.limit while leaving GDTR.limit at `007F`.
The earlier selector-`0188` execution was out of bounds, but not exactly one
byte beyond its claimed limit. The helper now configures GDTR.limit as `0187`;
the corrected focused and full regressions re-run this CS `#TS(0188)` case
along with the DS/ES and SS limit cases. The corrected full run is documented
in the [DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md).

