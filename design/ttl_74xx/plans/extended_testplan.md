# Extended 74-series verification plan

Every implemented part receives strict Verilator lint, xezim self-checking
simulation and Yosys synthesis with structural assertions. Large memory models
stop after coarse memory inference to preserve arrays; they do not claim mapped
gate-level synthesis. No warning suppression is introduced to obtain a pass.

ROMs use nonzero synthetic masks and read every location, including deselection.
Single-clock FIFOs fill to capacity, reject overflow/underflow, drain, wrap,
reset with data outstanding and run 4,000 mixed transactions against an independent
queue. Dual-clock bidirectional FIFOs retain their separate directed tests;
those tests do not constitute asynchronous CDC correctness proof.

74595 checks all 256 words MSB-first, independent shift and storage clocks,
output disable while shifting, asynchronous shift clear preserving storage,
and simultaneous clocks capturing the previous shift register.
74574 gains independent unbounded register/output-enable proof and covers.
The previous five family formal contracts and original 74181 suites remain.

Missing implementations must remain visible as pending. The full completion gate
fails until that list is empty. This is distinct from implemented-subset tool
verification and from manufacturer pin-table conformance review.
