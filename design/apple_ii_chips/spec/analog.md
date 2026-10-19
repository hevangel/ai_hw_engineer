# Analog support device contracts

These are functional mixed-signal models with physical pin numbers. Voltage
inputs are `real` values in volts; digital outputs distinguish driven zero,
driven one, and open-collector Z. They do not claim transistor or SPICE fidelity.
The supply and control inputs remain part of each device's behavior.

## NE555

Pin 1 ground, 2 trigger, 3 output, 4 reset, 5 control voltage, 6 threshold,
7 discharge, 8 supply. Reset has priority; trigger below half the control
voltage sets the latch; threshold above control clears it. Pin 7 sinks when
output is low. A negative control input sentinel selects the internal 2/3
supply reference when physical pin 5 is unconnected.

Source: [TI NE555](https://www.ti.com/lit/ds/symlink/ne555.pdf).

## NE558

The four channels are A: output 1/timing 2/trigger 3;
B: trigger 6/timing 7/output 8; C: output 9/timing 10/trigger 11;
D: trigger 14/timing 15/output 16. Pin 4 control, 5 supply, 12 ground,
13 reset. Triggers act only on a falling edge after being high. Reset
disables triggering and grounds the outputs. Outputs normally sink current;
active pulses release their open collectors. The timing threshold is
approximately 0.63 times supply, giving approximately RC delay.

Source: [Philips NE558](https://ardent-tool.com/datasheets/NE558.pdf),
especially page 2 notes on reset, trigger rearming, and open collectors.

`timing_sink` exposes the electrical discharge state at the four timing pins
to the external capacitor solver. It is a simulator coupling interface,
not an extra motherboard wire. Reasserting trigger while the latch is already
set does not restart the capacitor ramp.

## LM741 / board MA741

Pin 2 inverting and 3 noninverting input, 4 negative supply, 6 output,
7 positive supply, 1/5 null, 8 no connection. A dominant-pole voltage-gain
model with output swing limiting and slew limiting approximates the device.
Defaults: DC gain 200000, gain bandwidth 1 MHz, slew 0.5 V/us.
Source: [TI LM741](https://www.ti.com/lit/ds/symlink/lm741.pdf).
The motherboard transcription's MA741 marking is represented by the 741
functional model; equality of vintage-device analog parameters is unverified.

## Assumption ledger

- ASSUMPTION: NE555 reset threshold is 0.7 V; trigger and threshold use ideal
  comparators. Leakage, loading, and comparator delay are omitted.
- ASSUMPTION: NE558 digital trigger/reset thresholds are ideal TTL crossings;
  control pin left uncoupled to an external voltage uses 0.63 times supply.
  Output Z requires an explicit board pull-up/floating-TTL approximation.
- ASSUMPTION: NE558 timing-capacitor sink is ideal when inactive. The solver
  exposes this as a state rather than silently computing a pulse duration.
- ASSUMPTION: 741 uses the datasheet's typical modern parameters, zero offset,
  1 V output headroom, ideal supply rails, and no bias/current-loading model.
  These are not characterized vintage cassette-amplifier specifications.
- ASSUMPTION: analog solvers start capacitors discharged. The chosen initial
  condition and integration step must be recorded by each board harness.
- Null pins, noise, supply ramp, parasitics, and temperature remain unmodeled.
  Functional tests cannot certify analog fidelity.
