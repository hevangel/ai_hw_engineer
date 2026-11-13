# Am26123 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-87 to 4-92 (PDF pages 412-417): functional
description, logic diagram, schematic and connection diagram on 4-87;
truth table and loading rules on 4-91. The same sheet documents the
Am54/74123 (no output latch, no Δtpw guarantee); this specification
reconstructs the Am26123 member only. The 1979 Linear and Interface Data
Book monostable selection guide (page 1-13) lists the Am26123 with
"tpw = 45 ns to ∞, with guaranteed < 1% change over temperature range;
output stability latch improves noise immunity".

## Part identity

Dual retriggerable resettable monostable multivibrator, pin-compatible
with the Am54/74123, with two improvements per the datasheet: ±1%
pulse-width stability over 0 °C to +70 °C and an output latch offering
"immunity to spurious output changes in the quiescent state due to
coupling of external noise at the timing capacitor nodes" — an
electrical property with no digital consequence.

First introduced: **1974*** — earliest located dated AMD documentation is
the 1974 Data Book itself; the bound is retained rather than guessed.

## Interface (16-pin package, 74123-compatible, pins per the loading rules)

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

Unmodeled pins: 1CEXT (14), 1REXT/CEXT (15), 2CEXT (6), 2REXT/CEXT (7)
external timing connections; VCC pin 16; GND pin 8.

## Boolean contract

Truth table (catalog page 4-91), per monostable:

| Clear | A | B | Q | Q̄ |
|---|---|---|---|---|
| L | X | X | L | H |
| H | H | X | L | H |
| H | L | ↑ | pulse | pulse |
| H | X | L | L | H |
| H | ↓ | H | pulse | pulse |

"An active-LOW A input and an active-HIGH B input are logically coupled
in an AND gate on the trigger input of each device": the trigger network
is `n = !a_n_i && b_i`, triggering on its rising edge (A falling with B
high; B rising with A low) while the clear is inactive. "A LOW on the
clear input resets the monostable to the normal Q LOW quiescent state
regardless of the A and B inputs"; a trigger edge consumed under a held
clear never fires afterward. Q pulses HIGH; Q̄ is its complement in every
state.

## Timing contract (digital abstraction)

Electrical: 45 ns-to-∞ pulse range, external RC timing on the
CEXT/REXT pins with the datasheet's T equations, guaranteed Δtpw < 1%
over temperature. Digital abstraction identical to the family contract:
trigger sampled on rising edges of the abstraction reference clock
`clk_i`, pulse of `PULSE_CYCLES` rising edges (default 4), retrigger
re-arms, clear is asynchronous and dominates.

## Assumption ledger

- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference
  clocks; the RC timing laws and the output latch behavior are
  electrical properties outside the digital contract.
- ASSUMPTION: power-up state is the quiescent state (Q low). The
  physical part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed, per the truth table's Clear-low row dominating.
- Documented as unmodeled electrical behavior: RC pin networks, minimum
  pulse width, the Schottky TTL unit-load table (1 unit per input, 2 per
  clear, 20/10 fan-out per output).
