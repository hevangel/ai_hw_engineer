# 6502 progress report

Status: early implementation, not sign-off. Reset vector, immediate loads, absolute store, absolute jump, and NOP pass a focused exact-fetch regression. Verilator lint and Yosys generic synthesis/check pass. The remainder of the instruction set, authentic software, and formal proof are pending. See `spec/spec.md` for the assumption ledger.

The memory/branch milestone adds six memory-load opcodes, two BIT opcodes,
eight branches, and seven flag controls (29 opcodes total). Directed tests
cover 1,536 memory loads, 2,048 BIT cases, and 131,072 branch cases, including
all signed offsets, all N/V/C/Z combinations, page boundaries, and 16-bit
wraparound. Each branch verifies the next PC and executes a target instruction.
Expectations are taken from the external MOS/Synertek manual; this test is not
an independent full ISS. The original smoke test and integrated Apple II
keyboard echo test also pass with Verilator 5.052.

The echo ROM is a small synthetic test owned by this project, not historical
Apple firmware. `run_all.sh` remains a failing sign-off gate until actual
historical software is implemented. Bus timing, the full instruction set,
interrupts, independent-oracle differential testing, and formal proof remain
open. No full-machine compatibility claim is made.
