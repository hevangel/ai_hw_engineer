# Implementation plan

1. Implement ROM, SRAM and register decode using factory-mask parameters.
2. Implement ports, reserved select pins and PB7 timer/GPIO ownership.
3. Implement the timer and KIM-specific documented post-expiry read behavior.
4. Generate packed mask-ROM constants from the two archived originals;
   retain bytewise hex references and hashes for all-address comparisons.
5. Instantiate both KIM masks on a shared board bus and verify decode,
   ROM contents, RAM isolation, port/IRQ behavior and timer equations.
6. Add formal invariants/covers, strict lint, dual simulation and synthesis.
7. Exercise real KIM monitor software through the existing CPU; retain all
   CPU/pin-timing limitations in the report and overarching ledger.
