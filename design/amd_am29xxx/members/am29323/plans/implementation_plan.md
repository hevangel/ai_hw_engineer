# Am29323 implementation plan

1. Transcribe the contract before RTL: Tables 1–3 and the X/Y/P
   data-format figures from the 1985 handbook page images; take the
   SHIFT AND ACCUMULATE semantics and the 67-bit overflow layout from
   the 1988 CMOS book's explicit statement.
2. Implement one module: dual input registers per bus with feedthrough,
   exact mixed-mode product, accumulator with the three documented
   operations, FA word-slice geometry, RND, temporary and instruction
   registers, output multiplexer with DISABLE, byte parity, HARDERR.
3. Generate a lockstep drive oracle (directed sweeps over every
   accumulator command × slice selection × TC mode × product corner,
   mixed-mode accumulate/shift-accumulate flows, the multiprecision
   64 × 64 sequence, random full-space drives) with readback windows the
   model also steps through.
4. Prove formal BMC/PDR/cover against an independently recomputed
   reference (command decode, slices, accumulator, output contract) with
   per-register capture-discipline assertions and command/slice covers.
5. Run synthesis with `check -assert`; record results and limits; share
   the module with the Am29C323 CMOS member per the series rules.
