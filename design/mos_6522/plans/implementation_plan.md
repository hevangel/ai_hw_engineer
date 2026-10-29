# Implementation plan

1. Implement the complete register/port/interrupt surface from MOS tables.
2. Implement T1 one-shot/free-run/PB7 and T2 interval/PB6/shared serial divider.
3. Implement all PCR handshake/edge modes, latching and no-handshake ORA.
4. Implement all eight SR modes with MSB-first pin streams and IRQ ownership.
5. Verify using independent deadline equations and byte streams, formal
   register/state invariants, reachable covers, both simulators and synthesis.
6. Resolve source discrepancies against physical-chip traces and authentic
   device software before claiming NMOS pin fidelity or system sign-off.
