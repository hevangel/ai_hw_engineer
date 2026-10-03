# Am9300 functional specification

## Sources

Technical contract: AMD's [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
printed pages 2-33 to 2-38, especially description/symbol on 2-33 and Tables
I-III on 2-37. Local source provenance: [source cache](../../../references/amd/README.md).
The matching [National 9300 datasheet](https://radio-hobby.org/uploads/datasheet/39/9300/9300.pdf)
independently corroborates the direct clear, positive clock, and JK behavior.

## Reconstruction boundary

This is the complete binary digital function of the fixed four-bit part.
The clock is the physical CP input; no host clock or edge detector is added.
The active-low asynchronous reset `rst_n` maps to the actual MR pin. Analog
voltages, propagation delays, setup/hold violations, loading, and reset
recovery/removal are outside this zero-delay synthesizable model. Inputs
must satisfy the real device's timing requirements. Power-up is unspecified
until MR is asserted; no invented initialization or synchronous reset.

## Pins

| RTL pin | Historical pin | Meaning |
|---|---|---|
| `cp_i` | CP, 10 | Rising-edge clock |
| `rst_n` | MR (complemented), 1 | Asynchronous clear when low |
| `pe_n_i` | PE (complemented), 9 | Low: parallel load; high: serial shift |
| `j_i` | J, 2 | Active-high serial J |
| `k_n_i` | K (complemented), 3 | Physical active-low K pin level |
| `p_i[3:0]` | P3-P0, 7-4 | Parallel data, bit i maps to Pi |
| `q_o[3:0]` | Q3-Q0, 12-15 | Four true outputs |
| `q3_n_o` | Q3 (complemented), 11 | Complement of Q3 |

## State transition

When MR is low, Q = 0 regardless of CP or any data/control input; Q3-bar = 1.
Releasing MR does not load or shift. Otherwise only a rising CP changes Q.
If PE is low, Qi takes Pi, and serial inputs are ignored.
If PE is high, Q3 takes old Q2, Q2 takes old Q1, Q1 takes old Q0. Q0 follows
Table I, expressed in physical pin levels:

| J | K-bar | Next Q0 |
|---:|---:|---|
| 0 | 0 | 0 |
| 0 | 1 | Old Q0 (hold first stage) |
| 1 | 0 | Complement old Q0 (toggle first stage) |
| 1 | 1 | 1 |

Hold applies to the first stage only: the later three stages still shift.
Tying J and K-bar together gives an ordinary serial D input. Q3-bar always
complements Q3; it is not a gated output. There is no output-enable pin.

## Assumption ledger

No undocumented binary behavior is assumed. The zero-delay/timing boundary
above is an explicit abstraction, not a claim about physical silicon timing.
