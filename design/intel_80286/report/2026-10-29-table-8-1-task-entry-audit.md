# Intel Table 8-1 task-entry coverage audit

**Date:** 2026-10-29 02:38 UTC  
**Source:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1, printed page 8-6 (PDF page 156). Reviewed in Chrome with Playwright
CLI; the current source capture is in
`design/intel_80286/work/incoming_ldtr_escalation_variants_20261029_21/`.

This audit separates first-fault selector/descriptor checks from the narrower
post-transfer double-fault escalation cases. A row with a direct check does
not imply every variant has an escalation test.

| Row | First-fault evidence | #DF escalation evidence and remaining gaps |
| --- | --- | --- |
| 1–3: incoming TSS present, idle, and minimum limit | The 21-configuration direct TSS/task-gate matrix (42 READY executions) checks absent `#NP`, busy `#GP`, short available `#TS`, and not-present-plus-short `#NP` priority with exact selector packets and no task-state writes. | A not-present #DF target TSS already shuts down; new busy, short available, and not-present-plus-short target cases also shut down in both READY modes before task-state writes. See the [TSS preflight report](2026-10-29-incoming-tss-preflight-double-fault.md). |
| 4–5: incoming LDT selector valid and LDT present | Ten invalid incoming-LDTR cases check selector type, TI, GDT limit and presence through task-gate delivery in both READY modes. | All five invalid-LDTR categories now cover malformed-gate #DF shutdown and valid #DF task-gate delivery in both READY modes. The valid-task path uses selector 0078 for the not-present LDT because its #DF TSS occupies selector 0070. See the [incoming-LDTR escalation report](2026-10-29-incoming-ldtr-escalation-variants.md). |
| 6: incoming CS selector valid | Direct matrix checks null, wrong-type and GDT-limit CS selectors as `#TS`. | Null, wrong-type and GDT-limit CS selectors cover invalid-`#TS`-gate shutdown and valid #DF task-gate delivery in both READY modes; see the [CS GDT-limit report](2026-10-29-incoming-cs-gdt-limit-double-fault.md). |
| 7: incoming code descriptor present | Direct matrix checks non-present CS as `#NP`. | Shutdown and valid #DF task-gate delivery are covered in both READY modes. |
| 8: code DPL matches CS RPL | Direct matrix checks CS DPL/RPL mismatch as `#TS(0038)`. | Shutdown and valid #DF task-gate delivery were added in both READY modes; see the [CS DPL/RPL report](2026-10-29-incoming-cs-dpl-double-fault.md). |
| 9: stack selector valid | Direct matrix checks null SS and SS beyond the GDT limit. | Null SS and `#SS(0188)` GDT-limit cases now cover shutdown and valid #DF task-gate delivery in both READY modes; see the [null SS report](2026-10-29-incoming-ss-null-double-fault.md) and [GDT-limit report](2026-10-29-incoming-ss-gdt-limit-double-fault.md). |
| 10: writable data stack descriptor | Direct matrix checks code-type and read-only SS faults as `#GP`. | Read-only data and code-type SS descriptors each cover invalid-`#GP`-gate shutdown and valid #DF task-gate delivery in both READY modes; see the [read-only SS report](2026-10-29-incoming-ss-read-only-double-fault.md) and [code-type report](2026-10-29-incoming-ss-code-type-double-fault.md). |
| 11: stack descriptor present | Direct matrix checks non-present SS as `#SS`. | Shutdown and valid #DF task-gate delivery are covered in both READY modes. |
| 12: stack DPL matches task CPL | Direct matrix checks DPL mismatch and selector-RPL mismatch as `#SS`. | Both DPL and selector-RPL mismatch cover malformed-`#SS`-gate shutdown and valid #DF task-gate delivery in both READY modes; see the [selector-RPL report](2026-10-29-incoming-ss-rpl-double-fault.md). |
| 13: DS/ES selectors valid | Direct matrix checks DS TI with null LDTR, system descriptors, and GDT limits. | DS/ES system descriptors, DS TI/null-LDTR `#GP(005C)`, and DS/ES GDT-limit `#GP(0188)` cover shutdown and valid #DF task-gate delivery in both READY modes; see the [DS/ES validity report](2026-10-29-incoming-ds-es-validity-double-fault.md). |
| 14: DS/ES readable | Direct matrix checks execute-only code through DS and ES as `#GP`. | Both DS and ES execute-only cases cover shutdown and valid #DF task-gate delivery. |
| 15: DS/ES present | Direct matrix checks non-present DS and ES as `#NP`. | Both DS and ES non-present cases cover shutdown and valid #DF task-gate delivery. |
| 16: data-segment DPL satisfies task CPL | Direct matrix checks DS and ES privilege mismatches as `#GP`; the valid incoming-LDT matrix checks all permitted DPL/RPL pairs. | Both DS and ES privilege faults cover shutdown and valid #DF task-gate delivery. |

## Next

Rows 1–16 first-fault and applicable #DF escalation outcomes are now reviewed.
Section 8.3 step 8's incoming-IP validation order is now covered for an
out-of-limit IP against valid CS with either null or valid SS; see the
[validation-order report](2026-10-29-task-switch-ip-validation-order.md).
Continue the remaining task-switch ordering/partial-state phases and broader
CPU acceptance.
Current-source connected-core formal and full POST/boot remain independent
release blockers. The bounded IBM AT BIOS regression now passes on current
source through the ROM-checksum success checkpoint; see
`2026-10-29-historical-software-current-source.md`.

The 02:22 UTC rerun also corrected a fixture-configuration issue: the common
incoming-task helper had set IDTR.limit to `0187` but left GDTR.limit at
`007F`. It now sets both limits to `0187`, and the full run re-executes the
incoming selector cases at the exact advertised GDT boundary. See the
[fixture audit and row-13 report](2026-10-29-incoming-ds-es-validity-double-fault.md).
