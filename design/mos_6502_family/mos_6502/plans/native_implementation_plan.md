# Native bus implementation plan and record

The [native specification](../spec/spec_native_bus.md) defines the contract
for a separate engine, retaining the existing functional interface.

1. Implement one observable NMOS bus transaction per clock, including
   dummy reads, page corrections and old/new RMW writes. Compare documented
   opcodes to pinned external input/output/bus vectors.
2. Extend the engine to all opcode slots. Specify unstable operation
   parameters and disagreements between independent implementations.
3. Add reset/RDY/IRQ/NMI/SO and jam recovery checks. Use a recovered
   transistor netlist as the independent timing oracle, not a second model
   translated from RTL. Preserve all external sources unchanged.
4. Prove bounded/safety properties with reachable covers, run historical
   Klaus and original KIM software, strict lint and synthesis. Rerun all
   affected gates after timing fixes.
5. Publish measured coverage and unresolved silicon/board gates. Reuse this
   engine in the 6507 and 6510 without claiming their systems work before
   their own real-software and independent-output regressions pass.

Steps 1–4 now pass the measured gates in the
[native report](../report/native_report.md). Step 5 and downstream integration
retain the explicit remaining fidelity requirements.
