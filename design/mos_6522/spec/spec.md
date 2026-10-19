# MOS 6522 VIA specification

## Evidence and intended target

Target: the NMOS MOS 6522, including all 16 registers, timers, port input
latches, handshake modes, shift modes and interrupt sources. This is a
progressive reconstruction toward the full historical devices and systems;
passing the digital checks below does not waive unresolved pin timing.

Primary sources:

- [MOS preliminary datasheet, November 1977](https://www.6502.org/documents/datasheets/mos/mos_6522_preliminary_nov_1977.pdf).
- [Production MOS datasheet, catalog pages 2-50 onwards](https://datasheet4u.com/pdf/1115291/6522.pdf).
- Independent reference: [MAME 6522via.cpp](https://github.com/mamedev/mame/blob/master/src/devices/machine/6522via.cpp),
  particularly `get_counter1_value`, `t2_underflow_delay`, `shift_in`,
  `shift_out`, and register read/write dispatch. No code is copied.

## Bus and ports

Native phase-two clock `clk`; transfers commit at its falling edge.
Select requires CS1 high and CS2 low. Data output enable requires high
phase, selected, R/W high and reset released. Reset is sampled low and must
span a whole clock. Split output and enable signals replace physical inouts.
PA inputs are resolved pin levels even for outputs. PB combines ORB on
output bits and external inputs on input bits. Timer 1 can override PB7 and
enable its output irrespective of DDRB7. Board logic supplies pull-ups and
combines asserted open-drain IRQs.

ACR0/1 enable input latching. An active CA1/CB1 event captures the port;
the sample remains frozen while its flag is set. ORA address F accesses the
same data without clearing flags or causing a handshake. Address 1 accesses
PA with handshake; address 0 acknowledges PB flags on read or write, but
only a write drives the PB handshake output.

## Register map

| Hex | Read | Write |
|---:|---|---|
| 0 | PB input/latch | ORB |
| 1 | PA input/latch, handshake | ORA, handshake |
| 2 | DDRB | DDRB |
| 3 | DDRA | DDRA |
| 4 | T1 counter low, clear T1 flag | T1 latch low |
| 5 | T1 counter high | T1 latch high and load full counter, clear T1 flag |
| 6 | T1 latch low | T1 latch low |
| 7 | T1 latch high | T1 latch high, clear T1 flag; no reload |
| 8 | T2 counter low, clear T2 flag | T2 low latch |
| 9 | T2 counter high | T2 high and load low latch, clear T2 flag |
| A | SR, clear SR flag/start | SR, clear SR flag/start |
| B | ACR | ACR |
| C | PCR | PCR |
| D | IFR; bit7 is enabled-interrupt OR | Ones clear corresponding flags; bit7 ignored |
| E | IER, bit7=1 (see discrepancy) | Bit7=1: set mask; bit7=0: clear mask |
| F | PA input/latch, no handshake | ORA, no handshake |

## Control and interrupts

PCR0 and PCR4 select rising CA1/CB1 when 1, falling when 0. Each PCR
three-bit CA2/CB2 field selects 0:falling input, 1:independent falling input,
2:rising input, 3:independent rising input, 4:handshake output, 5:one-clock
pulse output, 6:forced low, 7:forced high. Independent input flags clear
only through IFR. CA1/CB1 acknowledge handshake mode; pulse mode recovers
on the next clock. New events win over a same-edge acknowledgment.

IFR bits 0..6 are CA2,CA1,SR,CB2,CB1,T2,T1. Sources latch regardless of
enable. Only enabled flags drive IRQ. Reading IFR never clears flags.

## Timers and serial

T1 load N expires after N+2 falling-edge ticks in the current sampled
model. It traverses N..0,FFFF,reload with period N+2. ACR6 enables recurring
events; one-shot mode emits one event until a new load. ACR7 enables PB7:
load drives it low, initial expiry drives high, free-run expiries toggle it.
Updating the latches affects subsequent reloads without changing the running
counter. T2 similarly has N+2 initial delay, then one-shot IRQ suppression
and continuing counter operation. ACR5 selects sampled falling PB6 pulses,
where expiry is the N+1th pulse after loading.

ACR4:2 selects 0:disabled, 1:T2 input, 2:phi2 input, 3:external input,
4:continuous T2 output, 5:T2 output, 6:phi2 output, 7:external output.
Shift input consumes CB2 on rising CB1; output presents old SR7 on falling
CB1 and rotates SR7 into SR0. Internal CB1 toggles every system clock in
phi2 modes, every T2-low-latch+2 clocks in T2 modes. Finite internal modes
park after eight bits; external modes keep shifting and flag every eight;
mode4 repeats indefinitely without SR interrupts. In T2 shift modes the
low counter reloads through FF and the high byte borrows on low underflow.
Timer and shifter operation share that low counter when clocked by phi2.

## Assumption/discrepancy ledger; required follow-up

- ASSUMPTION: flags and asynchronous inputs are sampled at falling edges.
  MOS's timer diagram labels N+1.5 cycles; MAME schedules N+2. The current
  counter/IRQ contract is evaluated at falling edges. Half-cycle IRQ onset,
  synchronizer latency and NMOS shift-register lost-edge errata remain
  **unverified**. Do not mark native pin timing complete until compared
  with independent physical traces and real software.
- ASSUMPTION: IER bit7 reads 1, following MAME and common physical VIA
  behavior. Both located MOS sheets say 0. Physical-chip evidence remains
  required to resolve this contradiction, not merely self-authored tests.
- ASSUMPTION: T1 reloads through FFFF even in one-shot mode, with repeat
  IRQs suppressed, as MAME's counter getter specifies. MOS's prose says it
  continues decrementing. Independent capture remains required.
- ASSUMPTION: enabling a port latch captures the current input; thereafter
  it is transparent until the CA1/CB1 flag sets and frozen until cleared.
  The MOS input-latch description takes precedence over MAME's recapture on
  repeated active edges. Validate against a physical NMOS part.
- ASSUMPTION: control registers/flags reset to zero; counters, latches and
  SR deterministically reset to zero although MOS does not specify those
  contents. Software must initialize timers/SR.
- ASSUMPTION: simultaneous sampled event and acknowledgment retains the
  event; timer reload overrides old expiry. Mode changes preserve counters;
  serial transfer state resets when its mode changes. Mid-transfer mode
  changes and SR reaccess phase behavior require independent validation.
- T2's serial clock divider remains active while the finite shifter is
  parked. PB6 counting and T2 shift output are tested separately; their
  mixed-mode clock ownership remains a compatibility gate.

These are open fidelity requirements, not accepted substitutes for the
full device. No historical-software/system sign-off is claimed yet.
