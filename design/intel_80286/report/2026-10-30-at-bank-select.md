# IBM AT type-1 bank selection wiring — 2026-10-30

The [IBM 5170 type-1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 5 (PDF page 3), shows U72 as a `28S42` PROM, with address inputs
A6:A0 from system A23:A17, A7 from `+REFRESH`, and A8 from the `-RAM SEL`/
J18 net. U72 D0–D3 feed the four bank RAS selects, D4–D5 the two CAS
selects and D6 the low-memory select through U64 ALS573. U63 F20 generates
F16 from U72 D4, D5, D7 and `-MEM CS 16`; U64 also latches F16. The latch
enable is `HLDA OR ALE`. U72 D7 additionally supplies `-CS ROM` directly.

The [wiring model](../tb/intel_80286_at_bank_select.sv) exposes the PROM
address and accepts external PROM data; it does not fabricate a decode table
or reset state. The Verilator 5.052 `-Wall --assert` test in
`codex-286-at-bank-select-20261030-02` exercises all 512 address combinations,
all 512 PROM/F16 combinations using synthetic data, latch hold and transparency
through both HLDA and ALE. Yosys `proc; opt; check -assert; stat` passed in
`codex-286-at-bank-select-yosys-20261030-02`. This validates the modeled wiring
only, not the actual PROM contents or bank behavior. The test was added to
`run_sim.sh` after the preceding full simulation, so has only run separately.

The [documented U72 dump](https://minuszerodegrees.net/5170/rom/IBM%205170%20motherboard%20-%20ROM%20information.htm)
is from a type-3 board with part number `55X8041`; the same source identifies
a type-1 board's part as `6323541`. Their content equivalence is unverified,
so the type-3 image is not used as a type-1 oracle. The J18/keyboard shared
net, actual type-1 PROM image, downstream delay line, memory multiplexing,
DRAM and physical timing remain open. Source captures in ignored
`work/at_refresh_source_20261029_01/` are `bank_prom_inputs.png` SHA-256
`4132b54f2051f4f70d43db6a7adce0d9598a42cfed35fee93d99d86e11e25c7d`
and `bank_prom_outputs.png` SHA-256
`d1086e2d492d1bc5b4ba2c23d1b8b9f3487ebc97d55407bbaaa3cff5eb3311dc`.
For comparison, [MAME's pinned 5170 source](https://github.com/mamedev/mame/blob/511e0d59b12f5a8161df1f3c0e03a99613f45d20/src/mame/pc/at.cpp#L840)
lists `55x8041.82s147an.u72` for both its `ibm5170` and `ibm5170a` ROM
sets, with CRC-32 `f2cc4fe6` and SHA-1
`e285468516bd05083155a8a272583deef655315a`. Its reuse across emulator
configurations does not establish the contents of the photographed type-1
part `6323541`; validate that part independently before treating this dump as
the original-board oracle. The dump was not added to this repository.
The checkpoint is [issue comment 6516651586](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516651586).
