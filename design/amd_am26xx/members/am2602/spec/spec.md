# Am2602 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-21 to 4-26 (PDF pages 354-359): functional
description, logic diagram and connection diagram on 4-21; electrical and
switching characteristics on 4-22/4-23; operation rules and truth table
(Table I) with loading rules (Table II) on 4-24/4-25. The same sheet
documents the Am9602 (tpw = 60 ns to ∞, no Δtpw guarantee); this
specification reconstructs the Am2602 member only.

## Part identity

Dual DC-level-sensitive retriggerable, resettable monostable multivibrator
in a 16-pin package: two independent one-shots, each with two active-low
trigger inputs and one active-low asynchronous direct clear, true and
complementary outputs. "Retriggerable 0 to 100% duty cycle", "50 ns to ∞
output pulse width range"; the Am2602 is a selected Am9602 with a
guaranteed pulse-width change of less than 1% over 0 °C to +75 °C
(electrical, no digital consequence).

First introduced: **1974*** — earliest located dated AMD documentation is
the 1974 Data Book itself; the Am9602 variant belongs to AMD's early
9600-series interface parts and availability may precede the book. The
bound is retained rather than guessed (no month-level claim).

## Interface (16-pin package, pins per Table II)

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

Unmodeled pins: Cx (pins 1, 15) and Cx·Rx (pins 2, 14) are the external
timing connections per monostable; VCC pin 16; GND pin 8.

## Boolean contract

Per monostable, per Table I (the trigger inputs are one active-low pin Ī0
and one active-high pin I1, combined by the datasheet's single-bubble OR
gate):

| Ī0 | I1 | C̄D | Operation |
|---|---|---|---|
| H→L | L | H | Trigger |
| H | L→H | H | Trigger |
| X | X | L | Reset |

The per-monostable trigger network is `n = !i0_n_i || i1_i`; triggering
occurs on its rising edge while the clear is inactive — the Table I rows
are Ī0 falling with I1 low, and I1 rising with Ī0 high. While C̄D is low
the monostable resets and ignores trigger edges; an edge that occurs
during a held clear never fires afterward. Q pulses HIGH; Q̄ is its
complement in every state.

## Timing contract (digital abstraction)

Electrical: output pulse width T = 0.32·Rx·Cx·(1 + 3.7/Rx) ns for
Cx > 1000 pF (TpW = 0.32·Cx·Rx·(1 + 0.7/Rx); operation rules), Rx from
5 kΩ to 50 kΩ commercial / 5 kΩ to 25 kΩ military, giving the documented
50 ns-to-∞ range. Digital abstraction as in the family: the
reconstruction samples the trigger network on every rising edge of the
abstraction reference clock `clk_i`, triggers on a detected rising edge,
and counts `PULSE_CYCLES` rising edges (positive elaboration parameter,
default 4) before returning to quiescence. A trigger edge detected while
the cycle is running re-arms the full width (retriggerable 0-100% duty
cycle). The direct clear is asynchronous: low terminates the cycle
immediately and holds quiescence; a trigger edge is recognized only when
the clear is inactive at both the current and the previous `clk_i` edge.
No reset pin exists on the physical part; the reconstruction presents the
quiescent state from elaboration as a modeling assumption.

## Assumption ledger

- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference
  clocks; the continuous RC law and its temperature/voltage variations
  are electrical behavior outside the digital contract.
- ASSUMPTION: the analog retrigger-inhibit tail (a retrigger within a
  propagation-related window after the initial trigger, operation rule
  note) is not modeled; retriggering at the resolution of `clk_i` always
  re-arms the full width.
- ASSUMPTION: power-up state is the quiescent state (Q low). The physical
  part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed (never fires after the clear releases), per the truth table's
  Reset rows dominating.
- Documented as unmodeled electrical behavior: RC pin networks, minimum
  output pulse width (tpw(min)), retriggerable window tw = tpw + tpd+,
  loading rules and fan-out (16 HIGH / 8 LOW unit loads per output).
