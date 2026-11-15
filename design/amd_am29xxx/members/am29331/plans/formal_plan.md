# Am29331 formal plan

Reference model: `formal/table_oracle.svh` is generated from
`references/instructions.csv` (AMD Tables 1/2) and cross-checked by
`scripts/generate_oracle.py --check-table`. The property layer recomputes
the condition multiplexer, incrementer, multiway assembly and TOS slot
independently of the RTL decode cases.

Assumptions: an anyconst watched stack slot is constrained below 33; all
register state starts unconstrained (every value is a legal hardware
state, including overflowed pointers — the undefined TOS reads simply
compare against symbolic data); no initial-state assumptions are needed.

Assertions, checked every cycle:
- Y enable and value against the CSV row for the effective instruction,
  including reset-to-zero and class-11 forced-continue rows.
- D enable and value (SP or POP-D TOS), INTA level and enables,
  A-FULL = SP ≥ 28, EQUAL = enabled·!reset·match, and the ERROR mismatch
  expression.
- Per-edge state: address register from the interrupt multiplexer, IRAR
  from the address multiplexer, counter load/decrement/TOS-swap,
  comparator register and enable, stack-word writes per CSV stack action,
  and pointer arithmetic per stack action with reset-to-zero and
  hold-freeze cases.
- Interrupt sequence: acceptance latches the push flag; the following
  cycle pushes IRAR at the resulting pointer with the concurrent
  instruction's stack field suppressed (documented model of the
  datasheet-undefined overlap).

Covers: all 64 opcodes; interrupt accept and push; trap (FC·C̄IN·INTR);
FC without INTR; hold; slave; pointer boundaries 27/28/33/63; underflow
pop; CALL TOS exchange; POP D TOS output; SET with comparator match;
RESET SP; each multiway set; DJMP_S loop exit with counter one; forced
stall.

Engines: bmc (smtbmc z3, depth 16), prove (abc pdr, unbounded), cover
(smtbmc z3).
