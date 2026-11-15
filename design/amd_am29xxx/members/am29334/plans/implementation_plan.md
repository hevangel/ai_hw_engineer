# Am29334 implementation plan

1. Extract the functional contract from the 1988 data book page images
   (pin descriptions, functional description, Figure 2 transparency
   timing) before RTL; write the functional oracle model first.
2. Implement one module: async per-byte RAM writes in a single ordered
   block (documented B-last resolution of the both-sides case),
   combinational read/write address multiplexer driven by the common
   write enables, transparent output latches, three-state outputs.
3. Verify with a lockstep drive oracle: directed byte-enable sweeps over
   address corners, cross-port simultaneous-write cases, transparency
   checks and random full-space drives, with readback windows folded
   into the stream so latch history stays in lockstep.
4. Prove formal BMC/PDR/cover with a formal-only property clock, anyconst
   watched cells shadowed against the RAM (byte-merge and write-order
   invariants) and combinational latch/mux/output contracts.
5. Run synthesis with `check -assert`; record latch-heavy statistics
   (the real device is asynchronous RAM plus transparent latches).
6. Share the module with the Am29434 ECL member (identical documented
   function); record the ECL electrical layer as outside the contract.
