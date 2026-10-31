# 80286 selector-register execution

Status: the protected-mode SLDT, STR, LLDT and LTR slice passes focused
register/memory, descriptor, flags, retirement and READY-stall checks.
Reachable CPL1, CPL2 and CPL3 LLDT/LTR attempts now raise and deliver #GP(0)
before operand or descriptor access; the same-level handler repairs the saved
IP and returns through IRET. LDT-backed data-segment loading is connected.
This is a bounded selector slice, not complete protected mode. The expanded
[privilege matrix report](../report/2026-10-27-lldt-ltr-privilege.md) records
the exact test and source hashes.

## Sources

- Intel, *80286 and 80287 Programmer's Reference Manual*, order 210498-005,
  sections 7.2.3, 7.4.1, 9.4, 10.2.2, 10.3, 10.4.2, 11.3 and Appendix B:
  [1987 manual PDF](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf).
- Intel, *iAPX 286 Programmer's Reference*, order 210498-001, protected-mode
  initialization example (including LAR on a TSS selector) and LLDT guidance:
  [1983 manual PDF](https://bitsavers.org/components/intel/80286/210498-001_iAPX_286_Programmers_Reference_1983.pdf).

The implementation follows the 286 manuals. Later 386+ behavior is not used as
the architectural authority.

## Supported operations

| Encoding | Implemented behavior |
|---|---|
| `0F 00 /0` SLDT | Stores the visible LDTR selector to a register or 16-bit memory operand. |
| `0F 00 /1` STR | Stores the visible TR selector to a register or 16-bit memory operand. |
| `0F 00 /2` LLDT | CPL 0 only. Loads a GDT LDT descriptor; a null GDT selector invalidates LDTR without a table read. |
| `0F 00 /3` LTR | CPL 0 only. Loads an available 286 TSS descriptor from the GDT, sets its busy type bit in memory, then commits TR. It does not switch tasks and does not clear the old TSS busy bit. |
| `0F 00 /4` VERR | Sets ZF if the selected descriptor is a readable code/data segment visible at CPL/RPL. |
| `0F 00 /5` VERW | Sets ZF if the selected descriptor is writable data visible at CPL/RPL. |
| `0F 02 /r` LAR | On success, loads the descriptor access byte into the destination high byte, clears its low byte, and sets ZF. Accepts code/data and defined 286 system/gate types 1–7. |
| `0F 03 /r` LSL | On success, loads the 16-bit segment, TSS or LDT limit and sets ZF. Gate descriptors are ineligible. |

At CPL greater than zero, LLDT and LTR fault with #GP(0) before using the
source selector and before any memory operand transfer or GDT descriptor
lookup. The reachable regression enters CPL3 through a real outer IRET, tries both
register and memory forms, and delivers the fault through a same-level ring-3
vector-13 gate. It checks the exact error frame and repaired IRET successor,
absence of operand/descriptor/TSS traffic, and unchanged LDTR/TR state via
SLDT/STR. This does not imply support for privilege-changing exception entry.

SLDT and STR preserve FLAGS and retire after their destination transfer.
LLDT/LTR preserve FLAGS and commit visible selector plus cached base/limit only
after validation; LTR waits for the busy-byte write to complete before TR is
committed. LTR's hidden base/limit cache is retained for a future task-switch
implementation, but no current instruction consumes it.

LLDT and LTR reject TI=1 and selectors whose descriptor is outside the GDT
limit before issuing descriptor reads. The complete 8-byte descriptor must fit
within the limit. LLDT requires a present system LDT descriptor (S=0, type 2).
LTR requires a present available 286 TSS descriptor (S=0, type 1); an already
busy TSS is rejected. Wrong type/table/bounds produce a #GP packet using the
selector with RPL cleared. An absent otherwise-correct descriptor produces a
#NP packet. The fixture checks that rejected descriptors are not written and
that a TI-set selector with index zero is not mistaken for a null selector.

Descriptor reads are issued as six bytes followed by two bytes. The 286 fields
used by this slice occupy the first six bytes. LTR writes only the access byte
at descriptor offset 5, changing the available TSS type to busy. LDT-based
ordinary data-segment loads now select the cached LDTR base and limit through
the existing segment-load engine; the directed program loads DS from the LDT
and confirms a subsequent data read reaches the LDT segment's base.

The null-selector rule follows the 286 selector definition: index zero with
TI=0. A null LLDT operation invalidates the LDTR cache; a later TI=1 segment
reference produces a #GP(selector) packet without reading the LDT.

VERR, VERW, LAR and LSL read an `r/m16` selector from a register or memory.
TI selects the GDT or the valid cached LDT; the complete eight-byte descriptor
must fit within that table's limit. A null GDT selector, an invalid LDTR, or a
descriptor outside the selected table limit clears ZF without a descriptor
read. An in-range descriptor whose type or visibility is ineligible also
clears ZF, without raising #GP/#NP for the selector. VERR accepts readable
code/data, VERW accepts writable data, LAR accepts code/data and 286 system
types 1–7 (TSS, LDT and gate descriptors), and LSL accepts code/data plus TSS
and LDT types 1–3. For nonconforming descriptors, visibility requires DPL to
be at least both CPL and selector RPL; conforming code follows the manual's
conforming-code visibility rule. The presence bit does not reject these
queries. LAR includes that bit in the returned access byte. A failed LAR/LSL
preserves its destination; VERR/VERW and all query forms change no other flags
than ZF.

A reachable CPL3 regression now executes register and DS:[0020] memory-source
VERR, VERW, LAR and LSL after entering user code through a real outer IRET. Its
160 runs cover GDT and LDT selectors, DPL3 eligibility, DPL0 visibility denial,
read-only VERR/VERW differences, DPL0 conforming-code visibility, and all seven
286 system/gate types. At CPL3, LAR accepts types 1–7; LSL accepts available and
busy TSS plus LDT types 1–3 but rejects gates; VERR/VERW reject system
descriptors. A DPL0 TSS fails LAR/LSL visibility. Register and DS:[0020]
memory-source TSS and call-gate queries are included. A visible P=0 writable
data descriptor succeeds in all four queries; LAR returns its P=0 access bit.
Null GDT selectors and complete descriptors beyond GDT/LDT limits clear ZF
without descriptor reads; memory-source cases still confirm the selector
operand read. The test checks exact ZF and LAR/LSL destination behavior,
descriptor-byte reads where allowed, no descriptor writes, and exact successor
flow in both READY modes. Broader CPL/RPL combinations and fault/stepping
coverage remain outside this matrix.
Intel 210498-005 §11.3 (printed pages 11-3–11-4) was visually reviewed in the
scanned manual with Playwright CLI for these rules.

A separate reachable-CPL1/CPL2 matrix adds 768 register-source query
executions. It reaches each privilege level through outer IRET, then covers
writable data, readable nonconforming code and readable conforming code for
every DPL/RPL pair, all four query instructions and both READY policies. The
test checks descriptor read ordering, no writes, exact ZF-only behavior,
LAR/LSL results or failure preservation, and exact successor flow. The focused
[CPL1/CPL2 report](../report/2026-10-28-selector-query-ring12.md) records the
source, command and build identities. This matrix does not yet cover system
descriptor query types, LDT selectors or query fault priorities at CPL1/CPL2.

## Deliberate limits

- Real-mode `0F 00`, `0F 02` and `0F 03` remain #UD.
- Selector #GP(selector) and #NP(selector) faults from LLDT/LTR validation
  pass the tested same-level ring-0 delivery, handler repair and IRET path.
  Nonzero-CPL LLDT/LTR #GP(0) faults also pass ring-3 same-level delivery,
  handler repair and IRET. Privilege-changing gates, other protected vectors
  and nested-fault escalation remain outside that bounded path.
- `0F 00 /6` and `/7` remain invalid. Real-mode `0F 00`, `0F 02` and `0F 03`
  remain #UD.
- LLDT/LTR privilege checks are exercised at CPL1, CPL2 and CPL3 for register
  and memory operands, in both READY modes. Broader privileged/trusted
  instruction checks and remaining selector fault priorities remain open.
- Task switches, TR-driven task state, TSS stack selection, backlink/NT rules,
  nested exceptions, and complete GDT/LDT fault handling remain open.
- **ASSUMPTION A17:** the model resets visible LDTR/TR selectors to zero and
  their hidden caches to invalid, zeroed state. The cited Intel reset material
  does not specify these values; this deterministic reset is a model policy,
  not a claim about silicon.

## Verification

`--selector-exec` covers SLDT/STR/LLDT/LTR execution, ten selector exception
deliveries, eight reachable CPL3 LLDT/LTR privilege faults, two null-LDTR
recoveries, the directed VERR/VERW/LAR/LSL matrix, 160 reachable CPL3 queries,
and 768 reachable CPL1/CPL2 queries in both READY modes.
The CPL3 cases check register and memory forms, #GP(0) frames, no operand or
descriptor/TSS access, unchanged LDTR/TR, and IRET to exact successors. The
query matrix checks GDT/LDT selection, table bounds,
null selectors, descriptor types 0–7 where applicable, DPL/RPL rules, memory
sources, ZF and destination preservation, result bytes, bus order and stalled
transfers. The current exact-source run and manifest are recorded in the
active [80286 audit plan](../../../plans/286/2026-10-26-audit-and-revised-plan.md).
