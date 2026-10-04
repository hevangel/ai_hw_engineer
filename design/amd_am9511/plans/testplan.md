# Am9511 verification plan

- Manufacturer-derived truth tables and an external C emulator are independent
  evidence. Disagreements are investigated against primary source descriptions;
  do not force RTL to agree with a demonstrably wrong emulator.
- Exhaust all 16-bit single-operand values, all eight-bit signed operand pairs
  for binary arithmetic, signed extrema and randomized full 16/32-bit pairs.
  Check the exact result, overflow, borrow/carry and legal-result mask.
- Native floating tests span every exponent and normalization boundary,
  cancellation, ties, rounding, division zero, exponent wrapping and conversions.
- Derived functions: independent high-precision oracle, directed domain and
  singularity cases, documented accuracy ranges, random arguments, preserved
  stack entries and destructive-location masks.
- Exercise every legal command with both service-request settings; full stack
  readback must assert byte order, survivor positions and rotation. Reset during
  transfer/execution must preserve data and abort pending computation.
- Busy status access, queued access, held read/write, acknowledgments and bus
  enable must be verified through the actual host pin interface.
- Run actual manufacturer historical software. Preserve external source and
  make the regression part of run_all.sh. Any CPU-based fixture needs an
  independent CPU model and exact instruction PC checks.
- Formal prove transport/stack invariants and arithmetic properties; use covers
  to demonstrate execution, stalls, stack rotation and acknowledgments. Numeric
  transcendental bounds are simulation obligations, not a false formal claim.
