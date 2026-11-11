# Am9512 implementation plan

## Scope

Implement a synthesizable SystemVerilog functional reconstruction of the AMD
Am9512: all 16 documented commands, 32/64-bit floating-point arithmetic,
stack operations, status, programmed I/O, DMA-friendly PAUSE handshake, RESET,
ERR, END and SVREQ.

Out of scope: original microcode and microcycle counts, analog/electrical
timing, the internal 17-bit stack word, and unspecified silicon behavior.

## Milestones

1. **Source extraction and specification.** Extract the Am9512 chapter from the
   1980 AMD Am9500 guide, cross-check the command codes against the individual
   command bit diagrams, and write the format, status, stack and assumption
   ledger in `spec/spec.md`. Record the 1979 introduction evidence and the
   IEEE-754 differences.
2. **Command constants.** Encode the 16 opcodes in `references/commands.csv`
   and generate `src/amd_am9512_commands.svh`; add a check mode so the table
   and RTL cannot drift.
3. **Stack and bus transport.** Implement the 128-bit byte stack, push/pop
   rotation, command issue, PAUSE, END, ERR, SVREQ, EACK/SVACK, RESET and
   status read behavior in `src/amd_am9512.sv`.
4. **Parameterized FPU.** Implement unpack/pack, alignment, add/subtract,
   multiply, divide, normalization and round-to-nearest-even in
   `src/amd_am9512_fpu.sv`; instantiate it for 24-bit and 53-bit significands.
5. **Divider.** Add a sequential restoring divider that supplies the guard,
   round and sticky bits needed for division.
6. **Directed and random verification.** Generate vectors with the independent
   Python model (`scripts/gen_vectors.py`) and replay them through the top-level
   bus (`tb/tb_top.cpp`). Include zero, signs, cancellation, carry,
   overflow/underflow, rounding ties, stack operations and status.
7. **Formal transport proof.** Prove the reset state, command-completion stack
   and status movement, state/status bit invariants and PAUSE behavior with the
   FPU abstracted; cover command completion, error flags and reset during a
   command.
8. **Synthesis and report.** Run generic four-LUT synthesis and record the
   exact commands, vector count, formal results and known limits.

## Current status

Milestones 1-8 are implemented for the scope above. The complete flow
(`scripts/run_all.sh`) passes: command-table check, formal bmc/prove/cover,
347-vector simulation and generic synthesis. The original execution-time table,
analog timing and physical silicon remain outside the contract. The
overflow/underflow result encoding is a documented reconstruction assumption;
the 1980 chapter specifies the status flags but not the returned finite value.

## Files

- `src/amd_am9512.sv` — top-level stack, bus, status and command sequencing.
- `src/amd_am9512_fpu.sv` — parameterized single/double floating-point unit.
- `src/amd_am9512_divider.sv` — sequential restoring divider.
- `src/amd_am9512_commands.svh` — generated opcodes.
- `tb/tb_top.cpp` — vector replay and interface checks.
- `scripts/gen_vectors.py` — independent reference model and vector generator.
- `formal/` — transport proof, abstract FPU model and documented stack model.