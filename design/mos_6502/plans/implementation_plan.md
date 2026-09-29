# 6502 implementation plan

1. **Bus and reset foundation (in progress):** register state, vector fetch, instruction fetch, diagnostic fault, six initial opcodes, exact-PC smoke test.
2. **Core completion:** addressing modes, ALU and decimal flag, stack, branches, interrupts, read-modify-write cycles, undocumented behavior policy. Derive instruction expectations from the MOS manual and an external emulator or manufacturer trace, never from RTL.
3. **Bus accuracy:** document every cycle, dummy read/write and page crossing from the MOS hardware manual; model Apple II soft-switch side effects correctly.
4. **Verification:** independent oracle, formal invariants with reset assumptions and cover mode, opcode and cycle tests without landing padding, real historical software regression.
5. **Apple II:** wire 48 KiB RAM, keyboard and display soft switches, text video, ROM, and later graphics/storage in `system/apple_ii/`. Start with original 1977 Apple II, then document any II+ behavior separately.

Sign-off is blocked until actual Apple II firmware executes and its trace matches an independent reference. Current code is an implementation seed.
