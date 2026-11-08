#!/usr/bin/env python3
"""Independent model of the records_generics case: Manhattan distances, total, inverter chains."""
pts = [(0, 0), (3, 4), (-2, 5), (7, -1)]
total = 0
for i in range(len(pts)):
    for j in range(i + 1, len(pts)):
        d = abs(pts[i][0] - pts[j][0]) + abs(pts[i][1] - pts[j][1])
        total += d
        print(f"d({i},{j})={d}")
print(f"total={total}")
d = 1
print(f"inv3={d ^ 1} inv4={d}")
