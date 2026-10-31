# Formal plan

Initial reset is assumed for the first falling edge; later inputs are arbitrary.
Prove local transition rules for the registers and timer, IRQ/read enable
equations, reset state, and arbitrary-address RAM write/retention using anyconst.
Cover RAM write/read, timer expiry with IRQ, masked timer expiry, PA7 IRQ and
both flags set. These properties prove the documented digital contract;
they cannot establish its physical-chip equivalence.
