# Am2903 implementation plan

1. Transcribe original functions/destination controls and special functions
   into external CSV data before implementing RTL. Independently interpret
   those expressions to generate simulation and formal datapath expectations.
2. Separate the combinational datapath from native RAM/read-latch/Q/sign
   storage. Preserve resolved I/O behavior, LSS/MSS role pin and WE timing.
3. Verify all 505 documented nine-bit words and source/role combinations,
   arithmetic/logical/status boundaries, shift enables/parity, externally
   driven Y/DB, independent WE and CP phases. Mask reserved data behavior.
4. Connect four real slices to the verified Am2910. Execute original Figures
   17/19 unsigned/signed multiply microcode, check exact next microaddresses
   and mathematical products with edge-held Q inputs.
5. Run lint, formal BMC/prove/cover, simulation/historical firmware, synth,
   record all warnings or assumptions and update the index/series ledger.
