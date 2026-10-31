#!/usr/bin/env python3
"""Prove the replacement oracle equals the documented 74x679 rule on every vector.

Documented rule (spec/chips/ttl_74x679.md):
    match = (A1..Ak all 0) & (A(k+1)..A12 all 1),  k = P
    y     = g_n ? 1 : ~match
"""

mismatches = 0
for v in range(1 << 17):
    g_n = (v >> 16) & 1
    p = (v >> 12) & 0xF
    a = v & 0xFFF                      # bit0 == A1 ... bit11 == A12

    # Documented per-bit rule
    match = 1
    for i in range(1, 13):
        bit = (a >> (i - 1)) & 1
        need = 0 if i <= p else 1
        if bit != need:
            match = 0
            break
    rule_y = 1 if g_n else (1 - match)

    # Replacement mask rule
    low = 0xFFF if p >= 12 else ((1 << p) - 1)
    mask_match = ((a & low) == 0) and ((a & ~low) == (0xFFF & ~low))
    mask_y = 1 if g_n else (0 if mask_match else 1)

    if rule_y != mask_y:
        mismatches += 1
        if mismatches < 5:
            print(f"diff v={v} p={p} a={a:012b} rule={rule_y} mask={mask_y}")

print(f"vectors=131072  rule_vs_mask_mismatches={mismatches}")
