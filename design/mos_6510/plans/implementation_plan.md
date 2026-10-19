# 6510 implementation plan

1. Pin manufacturer and independent emulator evidence. Record reset,
   unbonded-port and external RAM bus discrepancies before implementation.
2. Implement a separate synthesizable port block with eight internal DDR/
   data bits, six physical pins and a qualified deterministic charge model.
3. Wrap the native CPU: internal address 0000/0001 mux, internal write data,
   AEC driver enables and disabled data driver on processor-port writes.
4. Exhaust port combinations; test actual CPU register/RMW accesses, exact
   PCs and AEC/RDY bus handoff. Run formal BMC/prove/reachable covers.
5. Execute historical software on this wrapper in both simulators; retain
   the full shared native CPU flow. Run strict lint/synthesis, publish
   measured results and unresolved silicon/C64 gates, then proceed to 6526.
