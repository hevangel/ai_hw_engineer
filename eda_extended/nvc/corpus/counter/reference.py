#!/usr/bin/env python3
"""Independent cycle model of the counter corpus case (not derived from the VHDL).

Reproduces the testbench schedule: 2 reset ticks, 18 enabled ticks, 2 disabled
ticks, then 1 reset tick. Each line is sampled 1 ns after a rising clock edge;
the clock rises at 5 ns, 15 ns, 25 ns, ... (period 10 ns).
"""
width, count, rst, en = 4, 0, 1, 0
tick_no = 0


def tick(n):
    global count, tick_no
    for _ in range(n):
        tick_no += 1
        edge_ns = 5 + 10 * (tick_no - 1)
        # The stimulus changes after the sampling point, so the DUT sees the
        # values driven before this edge.
        if rst:
            count = 0
        elif en:
            count = (count + 1) % (1 << width)
        print(f"t={edge_ns + 1} rst={rst} en={en} q={count}")


tick(2)
rst, en = 0, 1
tick(18)
en = 0
tick(2)
rst = 1
tick(1)
print("COUNTER DONE")
