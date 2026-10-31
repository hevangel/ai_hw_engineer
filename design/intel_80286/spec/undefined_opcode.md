# Real-mode invalid-opcode delivery

Implement real-mode interrupt 6 for encodings explicitly classified invalid by
Intel 210498-005 section 5.2, section 9.6.1 and Appendix B's #UD entry (B-8).
The saved CS:IP names the invalid opcode including its first leading prefix;
there is no error code and no instruction retirement. Preserve input registers
and original FLAGS in the six-byte FLAGS/CS/IP frame, then clear live IF/TF.
Use the loaded IDTR and existing real-mode entry/IRET machinery. A handler may
emulate, skip or replace the offending instruction before returning. Native
ordering remains A5; invalid IDT/stack delivery still requires #GP/#SS/#DF work.

The first integration covers Intel's explicit one-byte example `64h`, two-byte
example `0F FF`, invalid register/opcode-extension and register-for-memory
encodings already detected by the core, and real-mode-invalid ARPL, SLDT/STR,
LLDT/LTR, VERR/VERW, LAR/LSL. Do not infer invalidity merely from an unimplemented
instruction: WAIT and ESC are valid encodings, not #UD. The current 80287
slice implements WAIT's active-high BUSY, active-low ERROR# and TS behavior,
plus ESC's EM/TS and prior ERROR# exception gates. A normal ESC still stops
with a development diagnostic because the successful 80287 command and
operand-transfer protocol is not implemented. Native LOCK arbitration and
protected execution remain separate development boundaries. ARPL has a protected-mode execution slice; it
remains #UD only in real mode. Undocumented shift `/6`, other unspecified
aliases, unsupported REP combinations and overlength/segment-boundary
priorities remain explicit gaps.

The F6/F7 `/1` example in Intel's #UD entry is contradicted by the pinned
physical Harris-286 captures: none of the 10,000 records raises vector 6;
normal completions match TEST and the F7 file contains 52 vector-13 events
(33 word-offset-FFFF cases and 19 encodings longer than ten bytes).
Implement `/1` as the TEST-immediate alias, with AF undefined, rather than
turning the manual's example into a false fault. The selected register captures
also include 86 F0-prefixed forms. F0 is consumed as a real-mode prefix, as
specified by Intel B-68; it does not change these register results. Native LOCK
output, arbitration and privilege handling remain separate incomplete work.
A15 records this empirical
chip-family policy and the outstanding other-stepping/historical evidence.

Verification requires exact event vector, saved prefix PC, six-byte frame,
unchanged GPRs except SP, no faulting retirement, no operand/I/O traffic, and
exact handler/IRET/replacement-instruction successors. Exercise both stall
modes, invalid group and memory-only forms, loaded IDTR, and reset cancellation.
Add non-vacuous formal covers and transition invariants, then rerun current
core formal, independent physical/software regressions, lint and synthesis.

Primary manual: [Intel 80286 Programmer's Reference Manual, 210498-005](http://www.bitsavers.org/components/intel/80286/210498-005_80286_Programmers_Reference_Manual_1987.pdf).

## Current verification boundary

Core BMC, induction and every cover pass against the final RTL including
F0 prefix consumption and A15 TEST aliases. The aggregate exact-source audit
passes all 36 tasks (`work/undefined_complete_formal_audit.json`). Simulation,
including 36 directed #UD cases (two through a relocated IDTR) and 71
cycle-by-cycle reset cuts through vector/frame delivery with complete replay,
68,510 selected hardware captures in both bus modes, independent vectors,
original BIOS regressions and eight synthesis targets pass. Four compiled
mutants for vector, saved PC, erroneous retirement and missing TEST alias are
detected; this campaign is included in `run_all.sh` after hardware preparation.
Native LOCK, complete invalid-encoding classification, #GP/#SS/#DF delivery,
broader protected execution and A15 other-stepping/historical evidence remain open.
