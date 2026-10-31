# Real-mode segment-overrun and vector-limit faults

Implement real-mode interrupt 13 for operands extending beyond their 64 KiB
segment, including word operands at FFFF in DS/ES/CS/SS and existing complete
multiword/table-image prechecks. Preserve the faulting instruction's first
prefix CS:IP and input registers/FLAGS; do not retire it. No error code is
pushed in real mode. Deliver through the existing six-byte real-mode frame,
clear live IF/TF, and permit an actual handler and IRET to resume at an exact
tested successor. Protected-mode #SS(12)/selector error codes do not apply.

For strings, retain completed-element memory/register effects and remaining
CX, save the original prefixed instruction IP, and fault before the next
invalid element. A failing INS destination must not consume input.

ASSUMPTION A16: for the current Harris-backed fidelity target, instructions
longer than ten bytes raise interrupt 13. Intel Appendix C originally
specified 6; pinned SingleStepTests/80286 revision
`37c73caf53dcd22d3dd369ff09305d13d117a4fe` README explicitly documents this
286 erratum, and F7.1 contains 19 such vector-13 captures. Do not request an
eleventh instruction byte once the size violation is established. Additional
operand bytes need not be fetched once ModR/M determines an overlength
encoding; this functional boundary does not specify native prefetch timing.
Additional
stepping and actual historical overlength-software validation remain open.

If a real-mode vector lies outside the loaded IDTR limit, redirect to real-mode
interrupt 8, without accessing the rejected vector or retiring the triggering
instruction. Save the original instruction IP for INT/INTO; asynchronous
interrupts retain their ready-to-execute return IP and one acknowledgement.
Do not import protected-mode double-fault pairs or error codes. A limit that
also excludes vector 8 remains a development diagnostic until its native
shutdown/escalation behavior is established. Nonzero IDTR-base handling follows
the existing functional policy; native relocation evidence remains open.

Instruction fetch across CS:FFFF, tiny-stack shutdown, exceptional ENTER/LEAVE
partial effects and protected-mode fault delivery remain explicit gaps. Keep
their development stops rather than inventing #GP/#SS/shutdown behavior.

Sources: Intel 210498-005 table 2-4, table 5-2 and sections 5.1/5.2.2/5.2.3
(pages 2-26, 5-3..5-7), Appendix C; the primary manual is linked from the
[README](../README.md). The [pinned capture README](https://github.com/SingleStepTests/80286/blob/37c73caf53dcd22d3dd369ff09305d13d117a4fe/README.md)
documents the overlength erratum. Require exact vectors/frames/PCs, no operand
or I/O effects before fault, retained REP progress, real-handler IRET recovery,
current BMC/prove/cover, independent/physical/software replay and synthesis.
