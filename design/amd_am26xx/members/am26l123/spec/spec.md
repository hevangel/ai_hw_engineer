# Am26L123 functional specification

## Source

[1979 AMD Linear and Interface Data Book](../../../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
monostable selection guide, printed page 1-13 (PDF page 18): the
Am26L123 entry reads "Low-Power version 26123, tpw = 120 ns to ∞" with
the same Dual/Retriggerable/Resettable flags as the Am26123. No dedicated
Am26L123 datasheet page exists in the located 1977–1979 AMD data books;
the functional contract is therefore the Am26123 truth table (1974 Data
Book, catalog pages 4-87 to 4-92, truth table page 4-91) with the
low-power electrical envelope from the selection guide. This
composition is recorded as an assumption below rather than silently
substituted.

## Part identity

Low-power dual retriggerable resettable monostable multivibrator,
pin-compatible with the Am26123 (16-pin, A/B/CLEAR per monostable),
pulse range 120 ns to ∞.

First introduced: **1979*** — the earliest located dated AMD
documentation naming the part is the 1979 Linear and Interface Data
Book; the 1977 and 1978 data books do not list it. The bound is retained
rather than guessed.

## Interface (16-pin package, Am26123 pin map)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `m1_a_n_i` | 1A, pin 1 | in | Monostable 1 trigger input, active low |
| `m1_b_i` | 1B, pin 2 | in | Monostable 1 trigger input, active high |
| `m1_clr_n_i` | 1CLEAR, pin 3 | in | Monostable 1 direct clear, active low |
| `m1_q_o` | 1Q, pin 5 | out | Monostable 1 true output; HIGH during the cycle |
| `m1_q_n_o` | 1Q̄, pin 4 | out | Monostable 1 complementary output |
| `m2_a_n_i` | 2A, pin 9 | in | Monostable 2 trigger input, active low |
| `m2_b_i` | 2B, pin 10 | in | Monostable 2 trigger input, active high |
| `m2_clr_n_i` | 2CLEAR, pin 11 | in | Monostable 2 direct clear, active low |
| `m2_q_o` | 2Q, pin 13 | out | Monostable 2 true output; HIGH during the cycle |
| `m2_q_n_o` | 2Q̄, pin 12 | out | Monostable 2 complementary output |
| `clk_i` | — | in | Abstraction timing reference (not a device pin) |

Unmodeled pins: 1CEXT (14), 1REXT/CEXT (15), 2CEXT (6), 2REXT/CEXT (7);
VCC pin 16; GND pin 8.

## Boolean contract

The Am26123 truth table (catalog page 4-91), per monostable: trigger
network `n = !a_n_i && b_i`, triggering on its rising edge (A falling
with B high; B rising with A low) while the clear is inactive; CLEAR low
resets to the Q-LOW quiescent state regardless of A and B; a trigger
edge consumed under a held clear never fires afterward. Q pulses HIGH;
Q̄ is its complement in every state.

## Timing contract (digital abstraction)

Electrical: 120 ns-to-∞ pulse range per the selection guide; external RC
on the CEXT/REXT pins. Digital abstraction identical to the family
contract: trigger sampled on rising edges of the abstraction reference
clock `clk_i`, pulse of `PULSE_CYCLES` rising edges (default 4),
retrigger re-arms, clear is asynchronous and dominates.

## Assumption ledger

- ASSUMPTION (composition): with no dedicated Am26L123 datasheet in the
  located sources, the digital function is taken from the Am26123
  truth table because the 1979 selection guide (the binding evidence for
  this member) defines the part as the low-power version of the 26123
  with identical Dual/Retriggerable/Resettable behavior flags. The
  distinct electrical envelope (120 ns minimum pulse, low-power
  process) is documented here and not modeled.
- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference
  clocks.
- ASSUMPTION: power-up state is the quiescent state (Q low). The
  physical part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed, per the truth table's Clear-low row dominating.
- Documented as unmodeled electrical behavior: RC pin networks and the
  low-power timing figures.
