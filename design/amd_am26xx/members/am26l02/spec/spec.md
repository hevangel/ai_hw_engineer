# Am26L02 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-27 to 4-32 (PDF pages 360-365): functional
description, logic diagram and connection diagram on 4-27; switching
table and truth table on 4-30; loading rules (Table I) on 4-31. The same
sheet documents the Am96L02; this specification reconstructs the Am26L02
member only. The 1979 Linear and Interface Data Book monostable selection
guide (page 1-13) lists the Am26L02 as "Low-Power version 2602, tpw =
100 ns to ∞".

## Part identity

Dual DC-level-sensitive retriggerable, resettable monostable
multivibrator, one-fourth the power of the equivalent Am2602/9602, with
the same 16-pin organization, trigger polarity, clear behavior and
outputs. "One-fourth the power of the equivalent Am2602/9602 dual single
shots", "50 ns typical propagation delay", "fan-out of 3 with standard
TTL circuits", "guaranteed pulse width variation versus temperature"
(1% over 0 °C to +75 °C for the Am26L02 grade).

First introduced: **1974*** — earliest located dated AMD documentation is
the 1974 Data Book itself; the bound is retained rather than guessed.

## Interface (16-pin package, pins per Table I)

Identical pin map to the Am2602 (verified against the Table I loading
rules):

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `m1_i0_n_i` | Ī0, pin 5 | in | Monostable 1 trigger input, active low |
| `m1_i1_i` | I1, pin 4 | in | Monostable 1 trigger input, active high |
| `m1_cd_n_i` | C̄D, pin 3 | in | Monostable 1 asynchronous direct clear, active low |
| `m1_q_o` | Q, pin 6 | out | Monostable 1 true output; HIGH during the cycle |
| `m1_q_n_o` | Q̄, pin 7 | out | Monostable 1 complementary output |
| `m2_i0_n_i` | Ī0, pin 11 | in | Monostable 2 trigger input, active low |
| `m2_i1_i` | I1, pin 12 | in | Monostable 2 trigger input, active high |
| `m2_cd_n_i` | C̄D, pin 13 | in | Monostable 2 asynchronous direct clear, active low |
| `m2_q_o` | Q, pin 10 | out | Monostable 2 true output; HIGH during the cycle |
| `m2_q_n_o` | Q̄, pin 9 | out | Monostable 2 complementary output |
| `clk_i` | — | in | Abstraction timing reference (not a device pin) |

Unmodeled pins: Cx (pins 1, 15) and Cx·Rx (pins 2, 14) external timing
connections; VCC pin 16; GND pin 8.

## Boolean contract

The truth table (catalog page 4-30) is identical to the Am2602's: per
monostable, the trigger network is `n = !i0_n_i || i1_i`; triggering
occurs on its rising edge while the clear is inactive (Ī0 falling with
I1 low; I1 rising with Ī0 high). C̄D low resets regardless of the other
inputs and a trigger edge consumed under a held clear never fires
afterward. Q pulses HIGH; Q̄ is its complement in every state.

## Timing contract (digital abstraction)

Electrical: T = 0.33·Rx·Cx·(1 + 3.2/Rx) with Rx from 20 kΩ to 200 kΩ
(operation rules; recommended fixed values 120 kΩ commercial / 39 kΩ
military), a 100 ns-to-∞ pulse range per the 1979 selection guide, and
the same retriggerable window structure as the Am2602. Digital
abstraction identical to the family contract: trigger sampled on rising
edges of the abstraction reference clock `clk_i`, pulse of
`PULSE_CYCLES` rising edges (default 4), retrigger re-arms, clear is
asynchronous and dominates.

## Assumption ledger

- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference
  clocks; the RC law and the low-power timing figures are electrical
  behavior outside the digital contract.
- ASSUMPTION: the digital function equals the Am2602's, per the
  identical published truth tables (catalog pages 4-25 and 4-30) and the
  1979 selection guide's "Low-Power version 2602" entry; the L02's
  distinct electrical envelope (Rx range, T coefficients, tpw minimum)
  is documented here and not modeled.
- ASSUMPTION: power-up state is the quiescent state (Q low). The
  physical part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed, per the truth table's Reset row dominating.
- Documented as unmodeled electrical behavior: RC pin networks,
  fan-out of 3 (93L00 unit loads) / 6 (9300 unit loads), response and
  propagation figures.
