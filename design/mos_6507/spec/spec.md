# MOS 6507 sampled digital contract

The 6507 is the 28-pin, 8 KiB-address version of the NMOS 6502. This design
reuses the native NMOS sequencer and changes the package-visible signals.
Specify the digital contract before implementation; oscillator/electrical
behavior is a separate fidelity gate.

## Sources and history

- MOS [6500 family datasheet, November 1985](http://www.6502.org/documents/datasheets/mos/mos_6500_mpu_nov_1985.pdf),
  section "Features of 6507": thirteen address bits, RDY, eight data bits,
  on-chip clock and no external interrupt inputs.
- [Visual6502's photographed 6507D/6502D comparison](http://blog.visual6502.org/2010/09/6502-vs-6507.html):
  the 6507 metal layer ties IRQ/NMI pads to VCC. They are not merely left
  as floating, unbonded inputs.
- The [historical summary](https://en.wikipedia.org/wiki/MOS_Technology_6507)
  reports introduction in **1975**. An exact manufacturer launch notice has
  not been verified, so retain that historical attribution and uncertainty.
  Technical behavior is derived from manufacturer and die evidence above.
- The [shared native 6502 specification](../../mos_6502_family/mos_6502/spec/spec_native_bus.md)
  pins instruction and transistor-timing references and remaining limits.

## Interface

`clk` completes one native bus cycle, `rst_n` synchronously requests reset,
`rdy_i` holds read cycles. `bus_addr[12:0]` is the only physical address
bus; `bus_data_i/o[7:0]` and `bus_we` carry data and write direction.
The internal logical address, architectural registers and fetch/fault/jam
outputs are explicit verification/debug signals, not additional package pins.

The core retains its 16-bit PC and effective addresses. The wrapper drops
A15:A13 only at the physical bus. Thus addresses alias every 2000 hex bytes,
reset FFFC/FFFD reaches 1FFC/1FFD, and BRK FFFE/FFFF reaches 1FFE/1FFF.
Software BRK/RTI and status I remain implemented despite absent IRQ/NMI pins.
IRQ, NMI and SO are held inactive internally. Decimal arithmetic remains
enabled. Undocumented operations retain the explicitly qualified EE profile.

## Reset, RDY and assumptions

The common NMOS reset sequence preserves A/X/Y and decrements the stack
pointer through three stack reads; power-on values are not guaranteed.
RDY does not inhibit write cycles. The shared engine's die-derived address
carry and interrupt-latch timing qualifications continue to apply.

- ASSUMPTION: this sampled wrapper uses the shared NMOS engine for revisions
  other than the photographed D die; validate revision-specific behavior
  before claiming every physical 6507 matches it.
- ASSUMPTION: SO is inactive since it is absent from the package. This is
  a digital behavior choice; its internal metal tie has not been established
  by the cited IRQ/NMI photographs.
- Clock oscillator, PHI2 output duty cycle, analog delays and electrical
  setup/hold constraints are not implemented by this cycle-level interface.

## Required verification

Run formal mapping/tied-pin properties with reachable covers, strict lint,
exact logical-PC/next-opcode and physical bus simulation, synthesis and
the original KIM monitor on this actual 13-bit interface in two simulators.
The full shared native CPU gates remain a prerequisite, including the
external instruction corpus, recovered die timing and historical Klaus test.
KIM execution validates real NMOS software on the reduced bus; it does not
establish Atari TIA/RIOT/cartridge compatibility. That requires actual Atari
software and independent raster/audio timing at the system gate.
