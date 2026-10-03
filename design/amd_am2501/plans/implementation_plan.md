# Implementation plan: Am2501

1. Establish Am2501 identity as binary (not Am9306 BCD) from the original
   description/state diagram. Capture polarity and package variants in spec.
2. Implement four physical-clock flops with synchronous preset priority,
   reduction-AND enable, and modulo-16 count. No fabricated reset.
3. Implement TC as a combinational state/direction decode independent of CE.
4. Prove both two-CE and six-CE variants against the manufacturer's state
   diagram transcribed as an explicit transition table, not RTL arithmetic.
5. Exhaust state, direction, preset, PE, and every enable pattern in simulation.
   Exercise actual look-ahead wiring with two and four devices in both directions.
6. Run lint, formal BMC/prove/cover, simulation, and synthesis for both packages.
