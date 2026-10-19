# MOS 6510 sampled digital contract

The 6510 extends the NMOS CPU with an on-chip processor port at 0000/0001
and an address-enable input for bus sharing. This contract precedes RTL.

## Sources and discrepancies

- MOS [November 1982 preliminary 6510 datasheet](http://www.6502.org/documents/datasheets/mos/mos_6510_mpu.pdf):
  register addresses, bit-programmable direction, AEC tristates address,
  R/W and data. Its generic eight-pin description must be read alongside
  the actual 6510 package drawing, which bonds P0–P5; other variants differ.
- [VICE c64pla.c](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/c64/c64pla.c),
  [c64mem.c](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/c64/c64mem.c),
  [c64.h](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/c64/c64.h):
  reset DDR/data to zero, unbonded-port charge behavior, CPU-port writes
  leave external RAM receiving the VIC/open-bus data, 350,000-cycle 6510
  falloff base with randomized variation. This is an independent emulator,
  not a physical capture and not code to copy into RTL.
- [MAME m6510.cpp](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/cpu/m6502/m6510.cpp)
  disagrees on reset (DDR/data/drive FF) and forwards writes to external
  memory before updating the port. Preserve these disagreements; default
  behavior follows the explicitly documented VICE C64 profile, pending
  physical/reference-machine confirmation.
- The [shared native CPU contract](../../mos_6502/spec/spec_native_bus.md)
  supplies ISA and control-pin references. The 6510 retains IRQ/NMI and
  decimal arithmetic; its package lacks SO.

## Digital interface

One `clk` completes a native cycle. Inputs are `rst_n`, `rdy_i`, `irq_n`,
`nmi_n`, `aec_i`, external data and six resolved port pins. Outputs expose
raw logical address/data/write direction with explicit address/RW/data
output-enable signals. Low output-enable means high impedance in the board
resolver; do not use an inactive raw value as a driven external bus.

AEC gates package drivers; it does not itself stop the CPU sequencer.
The board must provide RDY ahead of bus theft. Writes still advance under
RDY low. The integrated port remains internal to CPU accesses even while
the external package bus is disabled. DMA accesses use external RAM at
0000/0001 and do not access the processor port.

0000 reads/writes all eight DDR bits; 0001 writes the data latch and reads
output latch bits for outputs, resolved pin values for inputs. Only low
six bits are physically bonded. IRQ/NMI, reset and RDY follow the native
engine. Port writes use the CPU's internal write data while the external
data driver is disabled; the board resolves external RAM write data.

## Explicit assumptions and sampled charge profile

- ASSUMPTION: DDR and data latch reset to 00, following the pinned VICE
  profile. The preliminary manufacturer text does not specify these values;
  MAME differs. Validate against a real machine before final sign-off.
- ASSUMPTION: the unbonded bits 6/7 retain their last driven values when
  switched to inputs, then fall to zero after `PORT_FALLOFF_CYCLES` clocks,
  default 350000. This deterministic, configurable sampled approximation
  excludes VICE's random variation, temperature and die variation.
- ASSUMPTION: no undocumented SO event occurs because the package lacks SO.
- AEC/RDY setup and hold windows, oscillator/PHI2 output timing, electrical
  contention and SX64/8500 revision-specific falloff are separate gates.

## Verification gates

Exhaust DDR/data combinations and all 64 physical input values, separately
check upper-bit charge/release/decay and reset, prove register/direction/
driver invariants with non-vacuous covers, run strict lint and synthesis.
Check actual CPU program accesses including RMW old/new port writes, AEC
and RDY combinations, exact PC/next opcode, and historical software.
The complete flow must include the native independent-oracle/historical
suite plus original monitor firmware on the actual 6510 wrapper. Actual
C64 KERNAL/BASIC and board timing remain C64 integration requirements.
