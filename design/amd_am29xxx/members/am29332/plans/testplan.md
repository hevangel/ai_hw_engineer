# Am29332 test plan

## Lockstep simulation (primary gate)

Driver (`tb/tb_am29332_driver.cpp`) walks the generated vector file
(`vectors/oracle.svh`). Each vector: drive inputs, sample the combinational
outputs (Y when driven, PY, C/Z/N/V/L per the RS/HOLD/SLAVE mux, PERR),
check against the vector, then clock and check the PASS-STAT / PASS-Q
readback rows that follow every instruction row (pin the status register and
Q register exactly).

Coverage (all from `generate_oracle.py`, seeded and reproducible):

1. Every defined opcode (124) at every byte width where meaningful.
2. Worked examples: Appendix B multiply/divide traces; Appendix A BCD
   examples 1–13 as two-row add/correct and sub/correct sequences; Chapter 2
   field-op examples (exact A/B/Y transcriptions); PRIOR-A example.
3. Algorithm sequences at byte widths 1, 2, 4: 16×16, 32×32 signed and
   unsigned multiplies (UMULFIRST/UMULSTEP×n/UMULLAST; SMUL equivalents),
   8/16/32-bit unsigned and signed divides (UDIVFIRST/STEP×(n−1)/LAST +
   REMCORR/QUOCORR), multiprecision BCD add/subtract chains (ADDC/SUBC with
   SUM-CORR/DIFF-CORR), MPDIVSTEP1/2/3 multiprecision divide chains.
4. Directed edges: zero/all-ones operands; every position −32..31 and width
   0..32 corner for one shift and one field op per family; status-source
   selects (I8/I7) for field ops; macro vs micro carry/link selection;
   BOROW on subtract class; PRIOR all-zero and MSB-set inputs; LOADQ/PASS-Q
   round-trips; LDSTAT with all four byte widths including read-only-bit
   protection; SETBIT/RSTBIT-STAT on read-only bits; HOLD windows freezing
   status and Q; undefined opcodes 1E/1F/4C/4D.
5. Diagnostics: parity-checked A/B with correct and injected-wrong parity
   (PERR), slave mode with matching and mismatching external Y/flags
   (MSERR), OE-Y high (Y undriven).
6. Randomized: seeded operand/position/width sweeps per class (thousands of
   rows) with model-computed expectations.

## Formal (SymbiYosys)

- `bmc` depth ~20 and `prove` (abc pdr): sequential contract on internal
  signals — status/Q hold under HOLD; read-only status bits never written
  (LDSTAT / SETBIT/RSTBIT-STAT / PRIOR with anyconst fields); relational
  bits 13/14/15 and bit 23 always equal their combinational definitions;
  LOADQ's Q-next contract; PASS-STAT/PASS-Q Y passthrough; flag update
  is unchanged when an instruction does not generate it (sampled class).
- `cover`: reachability of each instruction class, HOLD freeze, LDSTAT write
  path, PRIOR side effect, slave-mode compare path.
- Tri-state/slave-compare nets excluded from formal reasoning (documented
  scope; covered by simulation instead).

## Lint and synthesis

`verilator --lint-only -Wall` ( waivers only for intentional constructs );
`yosys -p "read -formal; prep; check -assert"` with a synth script
equivalent to the other members' `run_synth.sh`.
