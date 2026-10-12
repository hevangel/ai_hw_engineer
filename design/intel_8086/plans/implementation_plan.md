# Intel 8086 implementation plan

The specification and this plan were established before RTL. Keep the product confined to the chip and its verification environment.

1. Implement the segmented register/ALU datapath, effective addressing, byte aliases, data movement, stacks and branches. Establish independent physical-chip expectations, exact-PC tests and a historical manufacturer startup regression.
2. Complete decimal adjustment, calls/returns, software interrupts, strings/REP, shifts/rotates, multiply/divide, I/O and WAIT/ESC. Expand the physical corpus and run an unchanged historical application.
3. Complete NMI/INTR/trap selection, interrupt inhibition, HLT wakeup, interruptible WAIT/REP, HOLD and LOCK. Test saved CS:IP and actual following instructions, including original microcode quirks.
4. Integrate the six-byte queue and native minimum/maximum-mode BIU. Verify READY, lanes, I/O, INTA, QS, arbitration, odd-word ownership, reset phases and stale-prefetch behavior. Run the complete instruction corpus and unchanged historical application through both native modes.
5. Audit the manufacturer datasheet and external source against an explicit encoding/requirements ledger. Run strict lint, formal BMC/prove/cover, UVM, all independent corpora, directed controls, real software and synthesis on the final revision. Update the chip/index documentation and PR for human review.

The requested full-chip completion continues the existing feature branch and PR, without a system or board build. Any unmet documented requirement remains a gap; finite test agreement must not be presented as a mathematical guarantee of every state or original transistor timing. Final completion evidence is in the [report](../report/final_report.md).
