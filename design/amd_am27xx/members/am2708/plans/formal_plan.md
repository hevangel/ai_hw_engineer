# Am2708 formal verification plan

## Overview

Formal verification of the Am2708 implementation focusing on correctness of timing, control logic, and memory operations. This verification ensures the device behaves correctly according to JEDEC specifications and datasheet requirements.

## Formal verification goals

### Core correctness
- State machine behavior for all command modes (read/program/erase)
- Timing constraint compliance
- Control signal timing analysis and validation
- Memory write operation correctness
- Ready signal generation and timing

### Memory operations
- Address decoding and memory mapping
- Data integrity during all operations
- Error condition detection
- Boundary condition testing

### Programming sequence
- JEDEC command set compliance
- Automatic programming algorithm correctness
- Verify/program cycle timing
- Programming completion detection

## Verification approach

### BMC (Bounded Model Checking)
- State transitions for common operations
- Control signal timing analysis
- Error condition coverage

### Prove (Theorem Proving)
- State machine invariants
- Timing constraint proofs
- Memory operation correctness

### Coverage
- Command decoding coverage
- Timing boundary coverage
- Memory access coverage
- Error condition coverage

## SV assertions

Core assertion areas for Am2708:
- Command mode state machine correctness
- Timing constraint validation
- Memory write operation integrity
- Ready signal timing
- Programming sequence verification