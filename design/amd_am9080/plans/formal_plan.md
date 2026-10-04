# Formal plan

Derive ALU equations from the independently authored pinned C oracle and AMD
ANA correction; exhaustively prove combinational flags/results and covers.
CPU control proves stable transfer/architecture under READY stalls, bus
suppression in HOLD/fault, reset effects, retired-pulse boundaries and legal
bus-space decode. Covers reach read/write/I/O, HOLD, wait, HALT and interrupts.
Control proofs do not substitute for full instruction/real-software checks.
