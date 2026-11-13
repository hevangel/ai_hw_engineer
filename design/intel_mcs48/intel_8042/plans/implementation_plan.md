# Intel 8042 implementation plan

Issue: https://github.com/hevangel/ai_hw_engineer/issues/256

## Steps

1. Sources: Intel UPI-41A User's Manual and 8742 data sheet for the
   architecture; the PCjs-archived 1503033 listing for the IBM firmware and
   an independent disassembly; MAME for the dump hash. Done.
2. Reference model `scripts/upi42_iss.py`, written only from the manual,
   with every unstated rule tagged ASSUMPTION Ux. Cross-check its decoder
   against the independent disassembly of the IBM firmware. Done.
3. RTL `src/upi42_core.sv`: a two-state sequencer (fetch, second cycle) plus
   an interrupt-vector state; the effects of each instruction are applied in
   its last machine cycle. `src/intel_8042.sv` adds the 2K ROM. Done.
4. Lockstep bench `tb/lockstep_tb.cpp` and `scripts/upi42_trace.py`: the
   same stimulus script drives both; full architectural state and all 128
   RAM bytes are compared on every retire, plus every host read. Done.
5. Directed tests from the manual's examples and corner cases, random
   programs, and the IBM firmware. Done.
6. Formal: unbounded proof of sequencing, interrupt and host-flag
   properties for any program; covers for both vectors, RETR, stack wrap
   and OUT DBB. Done.
7. Synthesis with Yosys. Done.
8. Integration into `system/ibm_pc_at_5170` (milestone M2 of issue #254):
   board decode of ports 60h/64h, P2 reset and A20 lines, keyboard clock and
   data, IRQ1 from P24, and the firmware choice. Next.

## Open items

- A verified 1503033 dump would replace the partial rebuild. Without it the
  self-test cannot pass on the real image.
- DMA handshake and the 8243 expander are not needed by the AT and are not
  modeled.
