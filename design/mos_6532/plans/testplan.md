# Test plan

- All 128 RAM addresses, complementary patterns, reset retention and chip selects.
- Every DDR value on both ports with conflicting output/input levels; PA must
  read actual pins and PB must read output latch bits. All 128 register aliases.
- All four divisors and all 256 timer loads; compare the complete countdown
  to a time-based equation, check N*P+1 expiry and /1 underflow.
- Timer/PA7 acknowledgment independence, read-side enable changes, reloading,
  timer read coincident with expiry, post-ack prescaler restoration, /1 wrap.
- Both PA7 polarities, masked capture, output-mode capture, simultaneous
  acknowledgment/new edge, simultaneous flags, reset masking and bus gating.
- Run the same self-checking bench in Verilator and xezim. Assertions run in
  BMC and unbounded proof, with reachable covers separately required.
