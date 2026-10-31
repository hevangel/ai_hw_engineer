# SCAS restart source audit — 2026-10-28

## Finding

The protected SCAS restart discrepancy is real in the cited Intel documents,
but the previous link pointed to the wrong LOADALL page. The scanned
15-page Intel LOADALL memo's page 14 says a fault handler must adjust SI to
restart SCAS. It says the DF flag and operand size determine the SI step, and
that repeated SCAS requires adding two to CX. Page 13 contains implementation
notes about undefined opcodes and does not discuss SCAS. The page-14 visual
capture is `.playwright-cli/loadall-page14-scas.png`.

Intel's 80286/80287 Programmer's Reference Manual, SCAS entry B-100, describes
the ordinary operand as ES:DI and says SCAS advances DI. That explains normal
instruction behavior but does not establish which index the exception handler
must repair after a protected fault.

## Evidence and scope

- Inspected the original scanned LOADALL memo in the existing Playwright CLI
  browser session. Page 14 visibly names SI in the SCAS restart paragraph.
- Inspected page 13 as a control: it is implementation notes and contains no
  SCAS restart rule.
- Searched the local 80286 work, report, and scripts trees for SCAS-specific
  traces. The available hits are opcode constants and BIOS disassembly; no
  captured protected SCAS fault was found.
- Corrected the page references in
  `spec/protected_mode_integration.md`. The source discrepancy remains an
  unresolved release blocker; this audit makes no RTL or expected-state change.

## Required follow-up

Obtain an independent 80286 fault trace, Intel erratum, or another primary
source that explains whether the LOADALL memo's SI rule is intentional
processor behavior or a source error. Until then, do not implement protected
SCAS fault repair by assuming the ordinary DI rule or by copying behavior from
a later x86 processor.

## Follow-up source search — 2026-10-28

Using Playwright CLI, inspected the Bitsavers Intel 80286 directory index. It
contains the 1983/1985/1987 programmer and operating-system manuals and the
1983 hardware reference, but no separately listed 80286 errata or SCAS fault
trace. This archive check found no new primary evidence and does not change the
finding above. The index is at
[bitsavers.org/components/intel/80286](https://bitsavers.org/components/intel/80286/).
