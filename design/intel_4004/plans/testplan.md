# Test Plan: intel_4004

## Overview

A deterministic, self-checking testbench (`tb/tb_intel_4004.sv`) simulates a
complete MCS-4 microsystem — CPU DUT plus behavioral 4001 ROM (with I/O
port) and 4002 RAM models derived from their public bus protocols — and
compares the CPU's architectural state against an independent instruction-set
simulator at every instruction boundary.

A UVM environment is deliberately not used: the DUT has one clocked protocol
with no CPU-style register interface, so a procedural bench with a reference
model gives strictly stronger checking per line of code (the same rationale
accepted for the Intel 8259 design).

## Reference Model

The ISS in the testbench is written from `spec/spec.md` independently of the
RTL structure: it steps one instruction per call over the same ROM image and
maintains its own PC, stack, ACC, CY, index registers, SRC pointer, CMD, and
its own copy of RAM/ROM-port state. At every `sync` boundary the TB compares
all of it, including hierarchical reads of DUT internals.

## Verification Goals

- Every one of the 46 instructions executes and matches the model.
- Bus protocol: address multiplexing A1-A3, M1/M2 fetch sampling, X2/X3 I/O
  windows, `sync`, `cm_rom`, `cm_ram` bank decode, `data_oe` windows.
- Directed scenarios:
  - reset state and first fetch from PC 0;
  - ADD/SUB/ADM/SBM with and without carry/borrow (all corner values);
  - DAA on ACC 0-15 × CY 0/1; TCS both values; KBP all 16 inputs;
  - IAC/DAC/CLB/CLC/CMC/CMA/STC/RAL/RAR/TCC including carry rotations;
  - LD/XCH/INC/LDM/FIM over all 16 registers;
  - JCN all 16 condition codes against forced ACC/CY/TEST combinations,
    including the never-jump and always-jump codes;
  - JUN/JMS/BBL with 3-deep nesting and a 4th JMS overflowing the stack,
    then BBL unwinding;
  - ISZ loop (taken and skip paths);
  - FIN indirect fetch (pointer pair ≠ 0 and = 0), JIN;
  - SRC + WRM/RDM/WR0-3/RD0-3/WMP across RAM banks 0-3 (via DCL) and a
    second RAM bank to prove `cm_ram` switching; WRR/RDR ROM port loopback;
  - page-boundary straddle: two-word branch and FIN placed so the second
    word sits at word 255/256 boundary, checking the post-increment page;
  - undefined opcodes (1111 1110 / 1111 1111) behaving as NOPs, and WPM
    driving the ACC half-byte on the bus with `cm_rom` asserted.
- Fixed-seed pseudorandom stress: an LFSR-generated program of straight-line
  NOP-safe code (jumps only to a fixed exit loop) run for thousands of
  instructions with per-boundary model comparison.

## Pass Criteria

- Zero mismatches on any boundary comparison; all directed checks pass;
  both the directed program and the stress program complete with the model
  and DUT converging on identical final state; RAM/ROM model contents equal
  the ISS shadow copies.

## Runtime

Approximately 20-30k clock periods at 10 ns — seconds in xezim.
