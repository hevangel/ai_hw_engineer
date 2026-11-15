# Implementation Plan — AMD Am9518

## Deliverable

A synthesizable SystemVerilog reconstruction of the Am9518 Data Ciphering
Processor per `spec/spec.md`, verified against an independent DES oracle and
AMD's own published interface-test vector.

## Module plan (src/)

- `amd_am9518_pkg.sv` — package: command opcodes, mode-field widths and
  encodings, status-bit positions, pipeline timing constants (8 in / 5 flag /
  18 algorithm / 5 flag / 8 out).
- `des_core.sv` — one-block DES engine: 64-bit block input, 56-bit key image
  (PC-1 output), direction select; 18-cycle execution (IP load, 16 rounds of
  expansion/S-box/P at one round per clock, FP store); ready/handshake.
  Uses the standard FIPS 46 tables expressed as packed lookup data.
- `amd_am9518_top.sv` — the chip: master/slave/auxiliary port interfaces
  (strobe synchronizers, address latch, byte FIFOs), command processor,
  status/mode registers, parity checker, mode chaining logic (ECB/CBC/CFB)
  and IV/key registers.

All internal signals `logic`, `always_ff`/`always_comb` only, active-low
external strobes sampled into synchronized positives, single CLK, no
latches, no delays. `` `ifdef FORMAL `` assertions inline where cheap.

## Key design decisions

1. **Synchronous strobes** (A3): MDS/MAS/SDS/ASTB pass through 2-FF
   synchronizers; actions run on rising edges at the next CLK rising edge.
2. **Input/Output registers as 8-byte shift FIFOs**: input pushes MSB-first
   bytes, full at 8 bytes (1 byte in CFB), write-while-full ignored; output
   pops on read strobes, empty read leaves the bus tri-stated.
3. **Command processor FSM**: decode → (transfer 8 bytes) → (optional
   internal cipher) → done. One active command at a time; a new command
   write aborts any in-flight transfer, performs the reset-equivalent state
   clear of command context (p. 2-466 "aborting any command"), then decodes.
4. **Key schedule inside `des_core`**: PC-1 applied once at load; per-round
   halves rotate left by the FIPS table; decrypt mode consumes the generated
   subkeys in reverse order (standard DES property).
5. **Chaining**: separate IVE/IVD registers; ECB bypasses; CBC XOR + update;
   CFB runs the algorithm unit per byte on the 64-bit chaining register.
6. **Timing pipeline** honors the datasheet window: `ALG_CYCLES=18`,
   flag delays of 5, input 8 clocks, output 8 clocks.

## Verification hooks

- `` `ifdef FORMAL ``: strobe-synchronizer stability, one-hot register
  select, FIFO overflow protection, parity checker relation, reset blackout
  window.
- All state registers have a defined reset value; only key/IV registers
  intentionally retain state (A2).

## Steps

1. Package + DES core, lint clean, unit-checked inside the harness before
   the chip-level tests run (the harness tests ECB through the full chip
   path; the core is exercised through Load-Key + Start + data, and via
   Encrypt-with-Master-Key which isolates the algorithm unit).
2. Top-level ports and register file; multiplexed-control master port
   protocol; status/mode.
3. Command processor; key/IV loads (clear + encrypted); parity.
4. Session data paths: ECB, CBC, CFB over master and slave ports per
   Figure 6; Direct Control Mode pin behavior.
5. Testbench harness (C++/Verilator) + generated vectors; formal
   properties; synthesis scripts; docs.
