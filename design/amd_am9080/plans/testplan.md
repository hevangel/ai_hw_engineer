# Test plan

- Immutable external C oracle, with only the manufacturer-specified AMD
  ANA/ANI AC adaptation in a separately documented wrapper.
- Exhaustive ALU values/flags including subtract auxiliary carry, DAA and all
  rotation cases; cover AMD ANA distinction explicitly.
- All 244 documented opcodes, every condition outcome, register/memory
  destination, stack wrap, direct-address wrap, PSW and next-PC checks.
- Instruction tests verify the exact next opcode actually fetched; no padding
  is allowed to absorb an incorrect PC.
- Original TST8080.COM (Microcosm Associates, 1980), 8080PRE.COM and additional
  historical code as appropriate; no patched instruction bytes. BDOS is a
  documented harness service. Compare complete retirement state and bus writes.
- Manufacturer handbook 15-2 ISR skeleton (PUSH PSW/B/D/H, POP H/D/B/PSW,
  EI/RET): execute the actual instruction sequence with a pending interrupt
  during EI to validate delayed recognition and restored return context.
- UVM sequences drive transaction responses, READY stalls, HOLD, external
  interrupt byte streams, HALT exit, EI/DI boundaries and reset retention.
- All unused opcodes and injected-XTHL fault contract; no alias guarantees.
- Watchdogs, exact case/opcode counts and pass markers reject incomplete runs.
