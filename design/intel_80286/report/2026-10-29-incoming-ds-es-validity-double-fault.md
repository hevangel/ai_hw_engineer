# Incoming DS/ES validity double-fault coverage

**Date:** 2026-10-29 02:22 UTC  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 row 13, printed page 8-6 (PDF page 156). `playwright-cli` opened
and captured the source page at
`design/intel_80286/work/ds_es_gdt_limit_double_fault_20261029_19/table-8-1-page156-playwright-cli.png`
(SHA-256 `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`).

The row assigns `#GP(segment selector)` when an incoming DS or ES selector is
invalid. The incoming-task matrix now checks three row-13 causes:

- DS selector `005C` has TI=1 while LDTR is null and raises `#GP(005C)`.
- DS selector `0188` is one byte beyond GDTR.limit `0187` and raises
  `#GP(0188)`.
- ES selector `0188` is one byte beyond GDTR.limit `0187` and raises
  `#GP(0188)`.

Each cause has a malformed vector-13 gate that escalates to null-error #DF
shutdown and a valid vector-8 task gate that enters the #DF handler. Both
outcomes pass with READY immediate and stalled. The tests check the exact
faulting TSS selectors, event context, gate lookups, no out-of-limit GDT read,
absence of LDT reads for the null-LDTR case, backlink and busy state, null
error push, shutdown quiescence, and exact handler successor.

## Fixture audit

While extending row 13, review found `setup_incoming_ldtr` passed `0187` as
the IDT limit while leaving the GDT limit at the helper's default `007F`.
That meant earlier selector-`0188` task-entry cases were out of bounds but
were not exactly one byte beyond the claimed limit. The helper now sets both
table limits explicitly to `0187`. The focused and full regressions rerun the
incoming CS, SS, DS, ES and LDTR cases using the corrected GDT boundary. The
prior reports for CS/SS and the initial segment/LDT matrices now point to this
corrected run for exact-boundary evidence.

## Verification

- `scripts/preflight.py`: pass.
- Verilator 5.052 `-Wall` runner build: pass; build fingerprint
  `4be799691c05a9a787bbbe06f92c49907b1ec45a2e87439c23049c18413b7f43`.
- Runner binary SHA-256:
  `c7f30c70490f5d50d69d93014049395c1aef4148ba8cd0c2480dce2b9e02d2a4`.
- Focused `Vintel_80286 --iopl-controls`: pass, including DS TI/null-LDTR
  and all DS/ES limit escalation cases.
- Full `scripts/run_sim.sh`: exit 0 with 194 `PASS:` lines and no `FAIL:` or
  `ERROR:` lines.
- Protected-mode replay: manifest result `PASS`, 79 cases in both READY modes.
- Testbench SHA-256:
  `ba4a52f17d4821d1135f695e71e91c795b8fa926a3e4687a799ea255ed858186`.
- Full-run log SHA-256:
  `2b7e43bdbf93c92e42e4febbe47986dcc09c1352d84f3bceba6b711c4768ac37`.
- Protected replay manifest SHA-256:
  `620b58fdc23605bb859a85c5c0e20b2ab74f349b457004c480276d8eacfd1d51`.

Evidence is under
`design/intel_80286/work/ds_es_gdt_limit_double_fault_20261029_19/`. This is a
testbench and fixture correction; RTL is unchanged, so existing synthesis is
still applicable. Current-source connected-core formal, other task-entry
fault phases, authentic software execution on the RTL and whole-CPU acceptance
remain open. The preserved PDR remains active on a stale source snapshot.
