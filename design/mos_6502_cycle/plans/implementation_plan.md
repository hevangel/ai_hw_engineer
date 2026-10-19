# 6502 completion plan

1. Replace the subset decoder with all 151 documented NMOS opcode/mode pairs.
2. Implement shared cycle states for addressing, dummy accesses, RMW, stack,
   jumps, branches and interrupt/reset entry. Preserve the existing bus API.
3. Implement NMOS decimal arithmetic and flags from external references.
4. Add hash-pinned SingleStepTests vectors with every bus cycle and final state;
   add Klaus functional software and externally grounded arithmetic tests.
5. Verify physical interrupt/reset/RDY/SO behavior and formal invariants/covers.
6. Replace H7's external CPU in an authored-CPU motherboard wrapper and execute
   the unchanged historical Monitor keyboard/display and cassette regressions.
7. Run lint, formal, simulation and synthesis; update chip index, README and
   verification report. Retain explicit unsupported undocumented-opcode policy.
