# Revision-0 analog boundary

The three analog ICs are instantiated at B3, H13, and K13 in
`apple_ii_rev0_peripherals.sv`. Their physical-pin contracts and limitations
are in [the package specification](../../../design/apple_ii_chips/spec/analog.md).

The RC values and channel routing are preserved from the board manifest:

| Circuit | Components | Value / connection |
|---|---|---|
| Flash charge | R12 + R13, Cap15 | 12 kΩ + 3.3 MΩ, 0.1 µF |
| Flash discharge | R13, Cap15, B3 pin 7 | 3.3 MΩ, 0.1 µF |
| Paddle 0 | R20, Cap8, H13 timing A | 100 Ω series, 22 nF |
| Paddle 1 | R21, Cap5, H13 timing D | 100 Ω series, 22 nF |
| Paddle 2 | R22, Cap6, H13 timing C | 100 Ω series, 22 nF |
| Paddle 3 | R23, Cap7, H13 timing B | 100 Ω series, 22 nF |
| Cassette AC coupling | Cap10, R17 | 0.1 µF, 12 kΩ |
| Cassette positive feedback | R15, R16 | 220 kΩ, 12 kΩ |

ASSUMPTION: timing capacitors start discharged, supply rails are ideal,
555 discharge transistor and 558 capacitor sinks are ideal switches,
and unloaded capacitor ramps use analytic exponentials. Default updates
are 100 ns for paddles and 10 µs for flash. Quantization limits edge timing.
The cassette model uses a 100 ns step and a reduced input RC network.
TTL input bias converts released NE558 open collectors to high explicitly.
ASSUMPTION: the NE558's otherwise unresettable latches start inactive; that
chosen state is explicit and does not introduce a reset wire on H13 pin 13.

The crystal/Q1/Q2 oscillator remains a supplied 14.318 MHz digital boundary.
Speaker Q4 and composite-video Q3 output stages remain observable digital
signals; output voltage, current, and load waveforms are not reconstructed.
The RC reductions omit supply decoupling, jack attenuation, bias currents,
leakage, tolerance, parasitics, and transistor nonlinearities. Therefore this
model is a functional mixed-signal reconstruction, not an exact analog replica.
