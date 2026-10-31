# Protected DS/ES/SS descriptor validation

Status: component implemented/verified; CPU integration is pending.
The current CPU still uses real mode. This checker implements the validation
decision for ordinary MOV/POP DS/ES/SS and LES/LDS loads, not CS transfers,
task-switch validation, descriptor bus sequencing or exception delivery.

Sources: Intel 210498-005 sections 6.2-6.6, 7.3-7.4 and Appendix B MOV/POP;
[pinned 86Box loadseg_2386](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L391)
for independent type/privilege/presence order; and
[pinned PCjs 286 descriptor format](https://github.com/jeffpar/pcjs/blob/1a91d38eb12e5fdf91116b21ad9ef1935710a496/machines/pcx86/modules/v2/segx86.js#L176).
PCjs's data-load implementation explicitly leaves further access-right checks
open, so it is not the privilege oracle. The formal reference must use the
external 86Box type lists, not a restatement of RTL bit tests.

## Interface and decision order

Inputs are selector, CPL, stack-versus-data target, selected-table byte limit,
LDT validity, descriptor-available flag and the six architectural bytes of a
286 descriptor. Descriptor bytes 6/7 are not interpreted by this component;
the caller still fetches the complete eight-byte entry. Outputs identify the
relative table offset, whether a descriptor is needed, whether a decision is
complete, cache validity/fields, and a fault vector/error code.

1. GDT index zero (selector 0..3) is null regardless of RPL. DS/ES accept it as
   an unusable cache without reading a descriptor; SS raises #GP(0).
   LDT index zero (selector 4..7) is not null.
2. A nonnull LDT selector requires a valid LDT. The entire descriptor, through
   `(selector & FFF8)+7`, must fit the selected table's inclusive limit. Failure
   raises #GP(selector & FFFC), without requesting a descriptor read.
3. If the table check passes, request descriptor data. Until it is available,
   no validation result, fault or usable cache is presented.
4. SS requires writable data, RPL=CPL and DPL=CPL. DS/ES allow all data types
   and readable code. Data/readable nonconforming code require RPL<=DPL and
   CPL<=DPL; readable conforming code does not apply those comparisons.
   A type/privilege failure raises #GP(selector & FFFC) before testing presence.
5. An otherwise valid absent SS descriptor raises #SS(selector & FFFC);
   absent DS/ES raises #NP(selector & FFFC).
6. Successful nonnull validation presents 24-bit base, 16-bit limit and raw
   access byte. A separate output gives access-byte OR 01 for the caller's
   accessed-bit update. It does not authorize a cache commit before that
   transaction completes. Failure/null/wait outputs do not present usable
   cache metadata; their zero payload is only a deterministic interface value.

The checker performs no memory writes and preserves no architectural state.
It cannot establish native accessed-bit write timing, descriptor atomicity,
faulting bus behavior, null-cache hidden-bit contents or complete PE operation.
Those remain caller/native integration gates in protected_execution.md.

## Required verification

Use strict lint, standalone synthesis/check, and unconstrained combinational
BMC/prove/cover against a reference derived independently from the external
artifact. Check every access byte, CPL/RPL pair, both targets, GDT/LDT choice,
null/table-invalid/wait states and inclusive table boundaries, including FFF8.
Directed examples must distinguish conforming code from nonconforming code,
privilege/type faults from not-present faults, and null GDT from LDT index zero.
Check little-endian fields with arbitrary bases/limits and explicit accessed
images. Mutation tests must reject privilege, presence-priority, null-selector
and table-limit defects after successful compilation. Passing this component
does not close protected-mode CPU or historical-software sign-off.
