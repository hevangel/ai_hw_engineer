# Am2910 implementation plan

1. Transcribe manufacturer Table I before RTL, with address source, stack
   action and counter action selected independently. Reject the downloaded
   Am2900ME Am2910 model as an oracle: CJV, RFCT, CRTN and LOOP differ from
   the manufacturer table; its RLD timing also changes combinational tests.
2. Implement one native-pin module with edge-triggered PC, counter, depth
   and five-word stack. Separate Y value from output-enable.
3. Generate transitions from the external CSV, covering every opcode and pin
   combination, all depths, counter boundaries, stack overwrite/underflow.
   Observe all state through native instructions rather than force DUT state.
4. Execute original Figure 4 flows, check exact executed and next addresses,
   poison unused microstore words, and exercise N+1 count loops.
5. Run clean lint, formal BMC/prove/cover, simulation, synth/check, then record
   actual results and update the chip index and series ledger.
