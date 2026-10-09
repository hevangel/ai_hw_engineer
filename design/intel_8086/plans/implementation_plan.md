# Intel 8086 implementation plan

Written before RTL. Keep the design confined to the CPU and its verification environment.

1. **First functional milestone:** 16-bit register/ALU datapath, segmented 20-bit address generation, variable-length fetch/decode, all 8086 ModR/M addressing forms, byte aliases, data movement, arithmetic/logical operations, stack operations, conditional and unconditional jumps. Unsupported forms stop explicitly. Verify against physical-chip vectors, formal properties, stalled-bus UVM tests and Intel's historical startup example.
2. **Complete documented execution:** decimal adjustments, near/far CALL/RET, software interrupts/IRET, string/REP operations, shifts/rotates, multiply/divide including original 8086 divide-error semantics, port I/O, WAIT and ESC. Expand external vector coverage as each family lands. Run original historical application binaries, preserving their bytes and licensing, before architectural sign-off.
3. **Asynchronous control:** INTR acknowledge/vectoring, NMI edge capture, trap flag, interrupt shadows after STI/MOV SS/POP SS, HLT wakeup, HOLD/HLDA, LOCK and interrupted REP restart. Add exact saved-IP and next-instruction tests, plus reset during each transaction phase.
4. **Native BIU and pins:** six-byte instruction queue, word transfers and odd-address splitting, minimum/maximum-mode control, bus phases/READY timing and arbitration. Separately test prefetch-sensitive and self-modifying historical code. Do not silently redefine the current functional interface as a native one.

The initial PR is a reviewable implementation of milestone 1. Remaining milestones are explicit scope, not placeholder branches or unresolved code TODOs. No board or virtual-platform system is part of this plan.
