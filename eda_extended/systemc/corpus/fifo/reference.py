#!/usr/bin/env python3
"""Independent discrete-event model of the bounded-FIFO corpus case.

Capacity 4. The producer writes items 0..7 back to back and blocks while the FIFO
is full; a read frees a slot in the update phase, so the blocked write completes in
the following delta of the same nanosecond. The consumer starts at 20 ns and reads
one item every 10 ns. Within one nanosecond the read is printed before the write
that it unblocks.
"""
CAPACITY, ITEMS, START, PERIOD = 4, 8, 20, 10

occupied = 0
next_write = 0
lines = []

# t = 0: the producer fills the FIFO.
while next_write < ITEMS and occupied < CAPACITY:
    lines.append(f"t=0 wrote={next_write}")
    occupied += 1
    next_write += 1

for k in range(ITEMS):
    t = START + PERIOD * k
    lines.append(f"t={t} read={k}")
    occupied -= 1
    if next_write < ITEMS and occupied < CAPACITY:
        lines.append(f"t={t} wrote={next_write}")
        occupied += 1
        next_write += 1
lines.append("FIFO DONE")
print("\n".join(lines))
