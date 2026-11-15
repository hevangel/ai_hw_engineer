# Am2600 functional specification

## Source

AMD [1974 Data Book](../../../../../references/1974_AMD_Data_Book.pdf),
printed catalog pages 4-15 to 4-20 (PDF pages 348-353): functional
description, logic diagrams and connection diagram on 4-15; electrical and
switching characteristics on 4-16/4-17; operation rules on 4-17/4-18;
loading rules and truth tables (Table I, Table II) on 4-19. The same sheet
documents the Am9600 (no pulse-width guarantee) and the Am9601 (no clears,
pin 5 NC, no I4). This specification reconstructs the Am2600 member only;
the Am2600 is a selected Am9600 with a guaranteed pulse-width change of
less than 1% over 0 °C to +75 °C, which is an electrical guarantee with no
digital consequence.

## Part identity

Single DC-level-sensitive retriggerable monostable multivibrator in a
14-pin package. Five trigger inputs (two active-low, three active-high),
two asynchronous active-low direct clears, true (Q) and complementary (Q̄)
outputs, external RC timing pins. Historically the monostable of AMD's
early 9600 interface family; the datasheet binds it to MIL-STD-883
reliability screening for hybrid assemblers.

First introduced: **1974*** — the earliest located dated AMD documentation
is the 1974 Data Book itself. The Am9601 variant carries an AMD part
number of the early 1970s 93xx/96xx MSI generation, so public availability
may precede the book; the bound is retained rather than guessed (no
month-level claim).

## Interface (14-pin package, pins per Table II)

| RTL port | Device pin | Direction | Meaning |
|---|---|---|---|
| `i0_n_i` | Ī0, pin 1 | in | Active-low trigger input |
| `i1_n_i` | Ī1, pin 2 | in | Active-low trigger input |
| `i2_i` | I2, pin 3 | in | Active-high trigger input |
| `i3_i` | I3, pin 4 | in | Active-high trigger input |
| `i4_i` | I4, pin 5 | in | Active-high trigger input (NC on Am9601) |
| `co0_n_i` | C̄O0, pin 9 | in | Asynchronous direct clear 0, active low |
| `co1_n_i` | C̄O1, pin 10 | in | Asynchronous direct clear 1, active low |
| `q_o` | Q, pin 6 | out | True output; HIGH during the timing cycle |
| `q_n_o` | Q̄, pin 8 | out | Complementary output; LOW during the cycle |
| `clk_i` | — | in | Abstraction timing reference (not a device pin) |

Unmodeled pins: Cx (pin 11) and Cx·Rx (pin 13) are the external timing
capacitor/resistor connections; NC pin 12; VCC pin 14; GND pin 7. The
external RC network is electrical and is documented below, not modeled.

## Boolean contract

Trigger network per Table I and the DEFINITION OF TERMS section:

```
n_trig = (!i0_n_i || !i1_n_i) && i2_i && i3_i && i4_i
clear_active = !co0_n_i || !co1_n_i
```

Table I (H = HIGH, L = LOW, X = don't care, arrows are transitions):

| Ī0 | Ī1 | I2 | I3 | I4 | C̄O0 | C̄O1 | Operation |
|---|---|---|---|---|---|---|---|
| H→L | H | H | H | H | H | H | Trigger |
| H | H→L | H | H | H | H | H | Trigger |
| L | X | L→H | H | H | H | H | Trigger |
| X | L | L→H | H | H | H | H | Trigger |
| L | X | H | L→H | H | H | H | Trigger |
| X | L | H | L→H | H | H | H | Trigger |
| L | X | H | H | L→H | H | H | Trigger |
| X | L | H | H | L→H | H | H | Trigger |
| X | X | X | X | X | L | X | Reset |
| X | X | X | X | X | X | L | Reset |

The trigger network output must rise FALSE→TRUE to trigger; while either
clear is LOW, triggering is inhibited and a held clear terminates any
cycle ("any timing cycle can be terminated or any new cycle inhibited
until the low reset input is removed; trigger inputs will not produce
spikes in the output when a reset is held low"). Q pulses HIGH; Q̄ is its
complement in every state.

## Timing contract (digital abstraction)

Electrical: output pulse width T = 0.32·Rx·Cx·(1 + 3.7/Rx) ns with Rx in
kΩ and Cx in pF for Cx > 10 pF (operation rule 3), Rx from 5 kΩ to 50 kΩ
commercial / 5 kΩ to 25 kΩ military, Cx from 0 upward, giving the
documented 50 ns to ∞ pulse-width range with tpw(min) 45 ns typ at
Rx = 5 kΩ, Cx = 0 pF. Retriggering during a cycle restarts the full pulse
(triggering "occurs independent of the state of the monostable"); the
retrigger window extends beyond the pulse by a propagation delay
(operation rule 8) and the analog retrigger-inhibit tail described in the
operation note is below one reference cycle in the abstraction.

Digital abstraction: the reconstruction has no RC network. It samples
`n_trig` on every rising edge of the abstraction reference clock `clk_i`
and triggers on a detected rising edge. The pulse lasts `PULSE_CYCLES`
rising edges of `clk_i` (elaboration-time positive parameter, default 4).
A trigger edge detected while the cycle is running re-arms the counter to
the full width (retriggerable 0-100% duty cycle). `q_o` is HIGH and
`q_n_o` LOW exactly while the cycle runs. The direct clears are
asynchronous: either clear LOW terminates the cycle immediately and holds
the quiescent state. A trigger edge is recognized only when the clears are
inactive at both the current and the previous `clk_i` edge, so an edge
that occurs during a held clear never fires afterward, matching the
documented inhibit-while-clear behavior. There is no reset pin and no
guaranteed power-on state on the physical part; the reconstruction
presents the quiescent state (Q low) from elaboration as a modeling
assumption.

## Assumption ledger

- ASSUMPTION: pulse width is quantized to `PULSE_CYCLES` reference clocks;
  the continuous 0.32·Rx·Cx·(1+3.7/Rx) law and its temperature/voltage
  variations are electrical behavior outside the digital contract.
- ASSUMPTION: the analog retrigger-inhibit tail noted in operation rule 8
  (a retrigger within a propagation-related window after the initial
  trigger) is not modeled; retriggering at the resolution of `clk_i`
  always re-arms the full width.
- ASSUMPTION: power-up state is the quiescent state (Q low). The physical
  part specifies no power-up state and has no reset pin.
- ASSUMPTION: an input edge occurring while a clear is held low is
  consumed (never fires after the clear releases), per the operation-rule
  wording "any new cycle inhibited until the low reset input is removed".
- Documented as unmodeled electrical behavior: RC pin network, the
  maximum-allowable wiring capacitance limit (CSTRAY, switching
  characteristics table), input clamp levels, output short-circuit
  current, fan-out (16 HIGH / 8 LOW unit loads).
