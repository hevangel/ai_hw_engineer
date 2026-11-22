# Am29332 32-bit ALU/shift register

AMD's Am29332 (introduced 1986; documented in the 1987 *Am29332 Instruction
Manual*, AMD doc 07995A) is the 32-bit non-cascadable ALU at the center of
the Am29300 microprogrammable family. It pairs two 32-bit input ports and
one 32-bit output port with a 64-in/32-out funnel shifter, a 32-bit priority
encoder, a variable-width mask generator, byte even-parity check/generate,
and a master/slave diagnostic mode, and it carries dedicated hardware for
two-bit-at-a-time modified-Booth multiplication and one-bit-at-a-time
nonrestoring division over an internal 32-bit Q register. A 32-bit status
register (flags, link, multiply/divide state, position/width registers,
read-only relational conditions, and BCD nibble carries) makes every
microcycle's state interruptible. Variable-length BCD arithmetic runs in two
cycles (binary op storing nibble carries, then SUM-CORR/DIFF-CORR). The
datasheet in the 1988 *Am29C300/29300 Data Book* gives the pin-level BOROW /
RS / HOLD / M/m / SLAVE semantics; the part has no reset pin and is brought
up through LDSTAT.

## Implementation

`src/amd_am29332.sv` models all 124 defined opcodes (opcodes 1E/1F/4C/4D are
undefined; the model passes B and changes nothing — spec ledger): data
movement, logical, add/subtract/INCR/DECR with the BOROW carry/borrow
polarity, BCD correction steps, prioritize, single- and double-precision
one-bit shifts, the modified-Booth multiply steps, the signed/unsigned/
multiprecision divide steps with correction steps, N-bit shifts/rotates, bit
manipulation, aligned and non-aligned field logical operations, and
PASS-MASK; status/Q registers clock on CP and freeze on HOLD; parity,
slave-mode pin muxing and the MSERR comparators are modeled with the
pad-split `*_ext` convention used across this series (no tri-state
resolution inside the DUT).

## Verification

- `scripts/generate_oracle.py` is the external functional oracle. Its
  `--check-table` guard asserts the manual's printed worked examples —
  the Appendix B multiply trace (65h × 48h = 1C68h), the Appendix B divide
  trace (75h / 02h → Q=3Ah rem 01h), Appendix A BCD examples 1-13 with
  nibble-carry expectations, and the Chapter 2 field-operation example
  boxes — against the model. Algorithm sequences (signed/unsigned
  multiply and divide at byte widths 1/2/4) are additionally checked
  against independent arithmetic assertions (true product / true
  truncating quotient and remainder), never against the model itself.
- Lockstep simulation drives 17,537 vectors (105,202 output checks, 0
  failures): every defined opcode at every byte width, all worked examples,
  algorithm sequences with register feedback, HOLD windows, macro/micro
  carry-link selection, BOROW polarity, status-source selects, slave-mode
  compare and parity directed cases, and seeded random sweeps with
  PASS-STAT/PASS-Q readbacks after every instruction row.
- SymbiYosys: bmc depth 8 (smtbmc z3) PASS; prove (abc pdr, `setundef
  -zero`) PASS; cover PASS (all class reachability points hit).
- Yosys synthesis `check -assert` PASS (~16.9k cells).

See `spec/spec.md` for the full contract and assumption ledger, and
`report/final_report.md` for the run log.
