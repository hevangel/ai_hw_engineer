# Am26S02 functional specification

## Source

AMD 1974 Data Book preliminary sheet, printed catalog pages 4-33 to 4-38
(PDF pages 366-371): functional description, schematic, logic symbols and
connection diagram on 4-33; definition of functional terms, function
table and loading rules on 4-35. Qualified against the final data in the
[1978 AMD Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf)
(catalog pages 4-50 to 4-53): the function table and pin map are
identical across both printings; the final sheet narrows the pulse range
to 28 ns–∞ (40 ns in the preliminary) and states the timing equations
for the protected-capacitor circuits.

## Part identity

Schottky dual DC-level-sensitive retriggerable, resettable monostable
with PNP inputs (reduced loading: 0.4 Schottky unit loads), the same
16-pin organization as the Am2602/Am26L02, and per the distinctive
characteristics: "retriggerable 0% to 100% duty cycle", "28 ns to ∞
output pulse width range" (final data), "100 kΩ maximum timing resistor
value", pulse-width stability 1.0% (military) / 0.4% (commercial) over
temperature.

First introduced: **1974*** — the 1974 Data Book prints it as
preliminary data, which locates it in that year; the final (non-
preliminary) printing is dated July 1978. No month-level claim is made.

## Interface (16-pin package, pins per the loading rules)

Identical pin map to the Am2602/Am26L02:

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

Unmodeled pins: Cx (pins 1, 15) and Rx/Cx (pins 2, 14); VCC pin 16; GND
pin 8.

## Boolean contract

Function table (identical in both printings): per monostable, the
trigger network is `n = !i0_n_i || i1_i`; triggering occurs on its
rising edge while the clear is inactive:

| C̄D | I1 | Ī0 | Q | Q̄ |
|---|---|---|---|---|
| L | X | X | L | H |
| H | H | X | L | H |
| H | L | ↓ | pulse | pulse |
| H | X | L | L | H |
| H | ↑ | H | pulse | pulse |

The clear description — "A LOW on the clear input forces the Q output
LOW regardless of the Ī0 or I1 inputs" — matches the reset-dominant
contract. A trigger edge consumed under a held clear never fires
afterward. Q pulses HIGH; Q̄ is its complement in every state.

## Timing contract (digital abstraction)

Electrical: 28 ns-to-∞ pulse range (final data), Rx up to 100 kΩ,
clear-recovery time tS specified between an inactive clear and the next
trigger; the protected-capacitor circuits have their own published
timing equations. Digital abstraction identical to the family contract:
trigger sampled on rising edges of the abstraction reference clock
`clk_i`, pulse of `PULSE_CYCLES` rising edges (default 4), retrigger
re-arms, clear is asynchronous and dominates.

## Assumption ledger

- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference
  clocks; the RC laws (including the 1978 protected-capacitor equations)
  are electrical behavior outside the digital contract.
- ASSUMPTION: the digital function is the one published in both the 1974
  preliminary and the 1978 final function tables; no preliminary-to-final
  digital difference exists in the located sources.
- ASSUMPTION: power-up state is the quiescent state (Q low). The
  physical part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed, per the reset-dominant contract.
- Documented as unmodeled electrical behavior: the clear-recovery time
  (tS, "Clear Recovery (inactive) to Trigger") and the 20 ns minimum
  trigger pulse width are timing-restriction boundaries the test
  stimulus respects by construction (settled stimulus, one reference
  cycle minimum); RC networks, PNP input loading (0.4 unit loads) and
  fan-out (40 HIGH / 10 LOW) are documented, not modeled.
