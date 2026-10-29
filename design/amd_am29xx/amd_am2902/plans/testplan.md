# Test plan

Exhaust all P/G/Cn combinations, including simultaneous propagate/generate.
Expected C1..C3 use a sequential recurrence; expected group generation uses
the same recurrence with Cn=0 and propagation uses carry dependency.

Four actual Am2901 ALUs plus one Am2902 must match full signed/unsigned
16-bit ADD/SUBR/SUBS, result, carry and overflow across boundary patterns,
all single-bit generate/propagate chains, and deterministic random pairs.
Do not substitute a self-written ALU for the already verified chip module.

Five Am2902 instances form a two-level 64-bit network. Test arbitrary group
P/G signals against a sixteen-stage ripple reference and actual nibble P/G
derived from 64-bit operands against full-word arithmetic. Include carries
through all sixteen groups, alternating carry kills and independent generation.
