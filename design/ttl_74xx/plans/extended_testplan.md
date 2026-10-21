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

## Source-reviewed continuation checks

Universal drivers exercise opposite LE polarities, native capture-edge polarity,
transparency at both clock levels, independent transfer directions and output
isolation while storage operates. Wide transceivers check independent sections,
clock enables, pipeline stages, registered output enables and stored/real-time
selection. GTL translators enumerate their digital control/data tables.
Passive switches use independent graph references for every select state and
strong-driver/weak-bias resolution. The 4059 compares exact divide periods with TI
preset examples and checks LE release with CP stopped. The 742414 enumerates all
512 combinations of addresses, supply classification and control inputs.

Formal continuation tasks cover universal-driver fixed register/transparent
modes and passive-switch transfer/conflict/isolation. Their current-source hashes
must match before a report publishes passing evidence.
