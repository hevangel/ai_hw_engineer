# Am2903 test plan

Native pin-driven initialization of RAM, Q and sign compare; external oracle
for every documented word, role and source selector; exhaustive ALU pairs,
shift nibble/boundary/pin combinations and deterministic random states.
Observe all memory through native DB read output after each transition;
check Q via ALU source, sign compare via division Z, and transparent CP/WE.
Four-chip original multiplication firmware must use actual Am2910 repeat
control, exact executed/next addresses, unmapped microstore fatal and complete
8-bit pair coverage plus full-width boundaries/random operands.
