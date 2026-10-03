# Implementation plan

1. Establish the complete AMD architecture and functional transaction boundary
   before RTL; preserve AMD ANA/ANI and unspecified-opcode differences.
2. Implement a combinational ALU and flags, then a multi-step CPU controller
   for all documented instructions, ordered stack/bus effects, stalls,
   multi-byte interrupt injection, delayed EI, HOLD and HALT.
3. Vendor the immutable MIT-licensed independent emulator unmodified. Apply
   the one documented AMD ANA correction in the verification adapter only;
   use it to emit exact post-instruction states and memory/I/O effects.
4. Verify every documented opcode across varied input/flag conditions and
   assert exact next PC and actual next fetched instruction.
5. Run original historical CPU diagnostic programs through `run_all.sh`;
   compare every retirement to independently generated external traces.
6. Add UVM bus sequences/drivers/scoreboard and independent formal ALU/control
   properties; complete lint, proof/cover, simulation and synthesis.
7. Record actual verification and assumption-ledger validation before adding
   a verified index entry or committing this CPU to the draft PR.
