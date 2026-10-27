# Implementation plan: WDC W65C816S

1. Spec and assumption ledger from the datasheet ([spec](../spec/spec.md)).
2. One `always_comb` microsequencer: decoder (addressing mode and operation
   class per opcode), per-step bus request, next-state values; one
   `always_ff` commits them at `ce`.
3. Independent-oracle gate: `scripts/fetch_cpu_tests.py` streams the
   pinned SingleStepTests files into `work/cpu/vectors.txt`;
   `tb/cpu_vector_test.cpp` replays every case and compares every cycle and
   the final registers and memory.
4. Run the full 5,080,400-case set; fix every mismatch in the RTL.
5. Integrate in the Ricoh 5A22 and run real software in `system/snes`.
