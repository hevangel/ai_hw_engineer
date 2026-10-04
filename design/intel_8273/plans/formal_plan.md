# Formal plan

Prove command parameter indices, result counts, Tx bit/stuffing state bounds,
Rx byte/tail state bounds, DPLL range, read bus exclusivity and held data under
backpressure. Initial reset is assumed; later bus and serial inputs are arbitrary.
Use separate deterministic covers for Tx completion, successful Rx and error
completion to avoid constraining the safety proofs. Check cover reachability.
