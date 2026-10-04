# Am2501 functional specification

## Source

AMD [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
printed pages 2-55 to 2-60 (PDF pages 76-81). Description, TC equation,
package diagrams: 2-55. State diagram and mode table: 2-59. Cascading: 2-60.
The Am2501 is the binary variant of Am9306; Am9306's BCD sequence is not
the Am2501 contract. The original physical CD pin is complemented in the
symbol; its HIGH voltage level selects counting UP per the description.

## Digital contract

Fixed four-bit binary counter, rising-edge CP, synchronous active-low
parallel enable PE, active-high count enables CE. The 24-pin part exposes
six CEs; the 16-pin part exposes two. `CE_INPUTS` selects 6 (default) or 2.
This parameter represents documented packages, not an arbitrary-width counter.

| RTL port | Device signal | Meaning |
|---|---|---|
| `cp_i` | CP | Positive-edge clock |
| `cd_n_i` | CD-bar | Physical HIGH: up; LOW: down |
| `pe_n_i` | PE-bar | LOW: synchronously load P |
| `ce_i[CE_INPUTS-1:0]` | CE pins | All must be HIGH to count |
| `p_i[3:0]` | P3-P0 | Parallel preset |
| `q_o[3:0]` | Q3-Q0 | Counter state |
| `tc_o` | TC | Combinational active-high terminal count |

At rising CP:

1. If PE is low: load P, regardless of CE and CD.
2. Otherwise, if all CEs are high: count +1 when CD-bar is high, -1 when
   low, modulo 16. All 16 preset values are legal.
3. Otherwise: hold Q. Falling CP and changes away from a rising CP hold Q.

TC is HIGH at Q=15 when counting up, or Q=0 when counting down. It is a
combinational direction/state decode, independent of PE and CE. It remains
available while counting is inhibited so cascaded look-ahead works.

The part has no reset pin. Power-up is unspecified until a synchronous
preset. Do not add a reset or claim a deterministic power-on state.

## Timing boundary and legal stimulus

This is a zero-delay binary functional reconstruction. The original
master/slave device restricts changes of CD to CP HIGH, and requires CP HIGH
when PE rises or a CE falls while the other CEs are HIGH. All inputs must
meet original setup/hold requirements. The tests change controls during
CP HIGH, settle them, then fall and rise CP. No behavior is promised for
violating those timing restrictions; electrical delays and loading are out
of scope. No undocumented binary semantics are assumed.
