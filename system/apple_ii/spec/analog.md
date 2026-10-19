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
| Cassette output divider | R19 from J13 pin 8, R18 to ground | 12 kΩ series, 100 Ω shunt |

ASSUMPTION: timing capacitors start discharged, supply rails are ideal,
555 discharge transistor and 558 capacitor sinks are ideal switches,
and unloaded capacitor ramps use analytic exponentials. Default updates
are 100 ns for paddles and 10 µs for flash. Quantization limits edge timing.
The cassette model uses a 100 ns step and a reduced input RC network.
TTL input bias converts released NE558 open collectors to high explicitly.
ASSUMPTION: the NE558's otherwise unresettable latches start inactive; that
chosen state is explicit and does not introduce a reset wire on H13 pin 13.

The crystal/Q1/Q2 oscillator remains a supplied 14.318 MHz digital boundary.
Q3 and Q4 now have explicit reduced output-network models, described below.
Enable them with `ENABLE_ANALOG_OUTPUTS=1` on either CPU wrapper; default
digital regressions leave their validity flags false to avoid analog-step cost.
The cassette output jack uses the actual R18/R19 resistive divider and an
optional resistive load (zero means open circuit). ASSUMPTION: the digital
J13 output is represented by ideal 0.2 V low and 4.0 V high levels with zero
source resistance. Those chosen levels are configurable, not measured chip
characteristics. The open-circuit swing is 31.405 mV peak-to-peak; a 1 kΩ load
reduces it to 28.571 mV. An unknown J13 level makes the separate validity
output false; its voltage placeholder must never be interpreted as a sample.
Frequency-dependent recorder impedance, nonlinear output drive and cable capacitance remain
unmodeled. The cassette input still starts at Cap10, rather than a recorder.

The RC reductions omit supply decoupling, input jack attenuation, bias currents,
leakage, tolerance, parasitics, and transistor nonlinearities. Therefore this
model is a functional mixed-signal reconstruction, not an exact analog replica.

## Output network implementation contract

The output reconstruction uses the imported physical nets, cross-checked against
Red Book sheets S-10/S-11. The latter has a known supply error: R9 goes to +5 V,
confirmed by [Willegal's copper audit](https://www.willegal.net/appleii/appleii-pcb.htm).
The burst tank is **L1 27 µH in parallel with Cap2 47 pF and CT3 5–50 pF**,
driven by B12 pin 12 through R5 1 kΩ; it is not an RC-only filter.
R6 2.7 kΩ, R7 1.5 kΩ and R8 2 kΩ sum tank, B10 pin 5 video and C13 pin 8
sync into Q3's base. R9 is 10 Ω at the collector. Q3's emitter drives the
200 Ω R11 level pot, then R10 27 Ω into the video jack, with configurable load.

ASSUMPTION: Q3 is a reduced NPN with configurable beta, fixed Vbe and saturation
voltage; TTL voltage sources have no output resistance. CT3 defaults to the
nominal 3.579545 MHz resonance value, and coil resistance defaults to 10 Ω.
These are simulation settings, not measurements of an original board. Solve
the tank with trapezoidal integration at 2 ns, including finite base loading.
Validate DC levels, tank frequency/decay, load and pot effects independently.
Gayler Fig.4-4 records nominal open-circuit sync/black/white levels 0/.5/2 V
for a later board; use that as a plausibility check, not revision-0 calibration.

The speaker network is J13 pin 5 -> Cap11 100 nF -> R24 47 kΩ -> Q4 base,
with CR1's anode grounded. Q4's grounded emitter and collector through R25
27 Ω sink the speaker connector. Cap12 100 nF shunts that connector; the
other speaker lead is +5 V. ASSUMPTION: reduced Darlington beta/Vbe/Vce_sat,
ideal constant-drop diode, and configurable series RL speaker (8 Ω/200 µH
by default; inductance is unsourced and must be replaced by measured data).
Solve the loaded network at 100 ns. Check pulse decay, both edge polarities,
steady-state AC coupling, current/energy decay and integration convergence.
A voltage at the connector is an electrical result, not acoustic pressure.

Output models retain a false validity flag after any unknown driven level:
unknown excitation makes stored energy indeterminate. The explicit `analog_initialize` simulator control reinitializes stored energy
to zero. It is not connected to CPU RES or any other motherboard wire. Unknown
startup signals defer initial conditions until the first known drive; later
unknown drive invalidates stored energy until explicitly reinitialized. ASSUMPTION: initial tank/speaker energy is zero.
A wrapper parameter enables output sampling explicitly; disabled outputs have
false validity and zero placeholders. This allows long digital regressions
without hundreds of millions of additional analog time steps.

## Floating data bus contract

Gayler's *Apple II Circuit Description*, pp.47 and 81, describes B6/B7
releasing the system data bus during an I/O read, after driving video data
in the preceding phase. Don Lancaster's *Enhancing Your Apple II and IIe*,
Vol.2, Enhancement 13, pp.196–198, identifies stray bus capacitance as the
sample-and-hold that preserves that video byte for reads of C020, C030 and
other undriven I/O locations. This behavior is required by historical
Vaporlock software. Source: [Lancaster scan](https://dokumen.pub/enhancing-your-apple-ii-and-iie-volume-2-1st-ed-9780672224256-0672224259.html).

Model charge retention on the eight actual system data nets D0..D7 using
weak resolved feedback. No address decoder, video fetch or RAM shortcut is
added. Every strong package driver can replace retained charge. A strong X
or opposing strong drivers invalidates the retained bit; another known drive
restores it. Uncharged bits start Z. CPU RES does not clear board charge.
Partial I/O reads replace only the driven bits (e.g. D7 for C060..C067).

ASSUMPTION: negligible leakage during a CPU half-cycle, zero charging delay,
and no decay between drives. Weak digital strength represents passive charge,
not a physical pull-up or a new chip. This is a functional sample-and-hold,
not a calibrated capacitance/leakage model. `RETAIN_DATA_BUS=0` provides the
previous ideal-Z boundary for diagnostic comparison. Validate against real
video cycles, partial game reads, CPU writes, contention, and original ROM.

## Copper power and unused output contract

The independently traced Osmond layout includes H14 pin 6 (unused inverted
74LS251 output) on its ground signal and drawn ground trace. Preserve that
connection, although the imported KiCad transcription marks it unconnected.
ASSUMPTION: ideal zero-impedance rails dominate package output drive via
SystemVerilog supply strength. The redundant output's short-circuit current,
device heating and rail perturbation are not represented. Do not turn that
physical connection into an all-board digital X due to equal-strength rails.
The two A2 grounded-input NAND outputs are separate physical soft-5 nets,
even though both have the same steady-state logical high.
