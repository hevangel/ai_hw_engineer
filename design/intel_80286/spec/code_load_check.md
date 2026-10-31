# Ordinary protected code-transfer validation

This component supplies the ordinary-code validation decision for direct far
JMP/CALL. It does not perform a transfer, change CPL/CS/IP, fetch a descriptor,
write the accessed bit, push a frame, or deliver an exception. It is a required
step toward connecting protected CS cache loads to the CPU, whose PE-entry
development stop remains until protected execution is connected.
The separate [CS transaction engine](code_load_transaction.md) now wraps this
decision; architectural transfer/commit and system-descriptor handling remain
outside both components.

Primary contract: Intel 210498-005 Appendix B CALL FAR (B-15/B-16), JMP FAR
(B-56/B-57), table B-3 and sections 7.4/7.5. The complete manual is linked in
the [chip README](../README.md). Pinned
[86Box loadcsjmp_2386](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86seg.c#L747)
independently corroborates table selection, privilege/presence order and CS RPL
normalization. The primary legal code-type enumeration is authoritative; do
not accept a data descriptor because a generic emulator's S-bit branch does.

Inputs are destination selector, current CPL, selected GDT/LDT limit, LDT
validity, descriptor availability and the six defined 286 descriptor bytes,
requested IP, CALL/JMP selection, and the caller's precomputed old-stack
capacity decision. The last input describes the entire four-byte return
frame; it is ignored for JMP. This unit does not compute SS permissions or
stack geometry, which remain mandatory in its caller.

Ordered decision:

1. GDT null selectors 0..3 fault #GP(0). LDT index zero (4..7) is not null.
2. Require a usable selected table and the entire eight-byte descriptor within
   its limit, else #GP(selector & FFFC). No descriptor read is needed on either
   failure. Otherwise request the descriptor and wait until available.
3. S=0 descriptors produce `special_o`, with neither a successful code-cache
   result nor an architectural fault. A required gate/TSS resolver must handle
   them; classification is not acceptance of any system descriptor or a
   completed JMP/CALL. Never write their accessed bit as an ordinary code load.
4. For S=1 require an executable code type. Data descriptors fault #GP(selector).
   Nonconforming code requires RPL<=CPL and DPL=CPL. Conforming code requires
   DPL<=CPL and ignores the requested RPL. Type/privilege failures precede P.
5. Require P=1, else #NP(selector). For CALL, require the provided complete-frame
   stack decision, else #SS(0). Then require requested IP<=code limit, else
   #GP(0). This preserves the primary CALL stack-before-target-limit priority.
6. Only success publishes selector with its RPL set to the unchanged CPL,
   base24, limit16, raw access byte, and accessed-byte write image OR 01.

`checked_o` means classification is complete; `cache_valid_o` alone authorizes
an ordinary code-cache candidate. Metadata is zero when the candidate is not
valid. A caller must distinguish `special_o` from success and from a fault.
No speculative cache/selector publication or memory effects occur here.

Verification must enumerate all access-byte/CPL/RPL/CALL/stack/IP relationships,
table/null boundaries, conforming RPL independence and exact exception/error
priority. Use the primary's enumerated legal types in the independent formal
and simulation references, rather than re-reading the implementation's bit
tests. Include unconstrained BMC/prove/cover and compiled mutant sensitivity.
Neither this component nor a hand-written ring-0 test closes protected-mode
historical software, cache/core integration, gates/tasks or precise delivery.
