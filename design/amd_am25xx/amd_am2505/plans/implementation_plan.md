# Implementation plan: Am2505

1. Pin the full slice contract to AMD's operation table and application
   note; distinguish Booth overlaps/carry from standalone signed multiply.
2. Normalize physical logic polarity. Decode mutually exclusive 1X/2X,
   shift the overlap bit, complement for subtraction, and add K/Cn.
3. Expose the true four-bit carry separately from signed extension sums.
4. Prove low sums and carry for all physical inputs, and signed extension
   sums when the manufacturer-required X4=X3 wiring is present. Use a
   coefficient-based signed mathematical oracle independent of RTL gates.
5. Exhaust standalone pin inputs, then wire AMD's two-row 8x4 array and
   compare against independent signed multiply/add for all X/Y patterns,
   signed constant corners, and both voltage polarities.
6. Lint, formal BMC/prove/cover, simulate and synthesize; report only observed results.
