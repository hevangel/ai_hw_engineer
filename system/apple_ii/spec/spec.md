# Original Apple II system specification

Target: the original 1977 Apple II, not later II+ or IIe extensions. The [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf) anchors the memory and I/O map.

Initial intended map: `$0000-$BFFF` RAM (configured to 48 KiB), `$C000-$C0FF` motherboard I/O including keyboard and display soft switches, `$C100-$CFFF` expansion slots, `$D000-$FFFF` firmware ROM. Text page 1 occupies `$0400-$07FF`; its physical row mapping must follow the manual. The keyboard latch at `$C000` and strobe clear at `$C010` need cycle-accurate read side effects.

ASSUMPTION: a 48 KiB RAM configuration is used as the first integration target. Original machines shipped with multiple RAM configurations; this choice is for the first platform build and does not define all Apple II variants.

No Apple ROM binary is included. Firmware provenance and redistribution rights must be established before adding one; the system test can accept a user-supplied ROM path in the meantime.

## Physical-package reference platform

The main reconstruction target is revision 0 with three 16 KiB rows of 4116s.
`apple_ii_rev0_digital.sv` is generated from the normalized pin manifest,
instantiating 79 digital packages. `apple_ii_rev0_reference.sv` connects H7's
physical NMOS CPU pins and the B3/H13/K13 support packages for a total of 83.
The initial behavioral memory/keyboard wrapper remains an early CPU regression.

Connectivity provenance, missing-power and RDY corrections, and identical
48 KiB memory-selection straps are in [board/README.md](../board/README.md).
The original Monitor image is hash-pinned and downloaded to ignored build
output. Its six socket images populate the ROM space for the reference test;
this configuration does not assert that every original shipped board had six
populated ROMs. [Dependency notes](../board/DEPENDENCIES.md) identify ownership
and the reference solver/netlist's different licenses.

## Additional assumption ledger

- ASSUMPTION: digital package delays are 5 ns and DRAM output delay is 20 ns
  for event ordering. These uniform values are not characterized timing data.
- ASSUMPTION: digital supply pins use power-good tokens, including negative
  supplies; analog packages use real ideal voltage rails.
- ASSUMPTION: selected startup values initialize unresettable timing counters,
  keyboard strobe, and NE558 latches. No artificial motherboard reset is added.
- ASSUMPTION: open TTL keyboard input and released NE558 collectors read high
  through explicit boundary bias models. General chip models retain X/Z.
- ASSUMPTION: the transistor solver's two-state boundary samples unknown read
  bits high and counts them; the Monitor test rejects unknown opcodes.
- ASSUMPTION: EPROM font bits 5..1 represent the original five glyph columns.
  Address/pin mapping is tested; original-dump content comparison is pending.

Analog reductions and integration steps are documented in
[analog.md](analog.md). Exact electrical fidelity, full schematic audit,
visible video/cassette validation, and the authored 6502 remain acceptance
requirements. The full suite runs historical software and returns nonzero
while those requirements remain outstanding.

## Integrated bring-up regression

`tb/echo.hex` is project-authored test software, loaded at `$D000` with the
reset vector pointing there. It repeatedly executes:

```asm
poll: LDA $C000
      BPL poll
      STA $0400
      LDA $C010
      JMP poll
```

`tb/tb_echo.sv` checks each opcode-fetch PC, injects A and Z, verifies the
high-bit text codes in page 1, and confirms that CPU reads acknowledge the
keyboard strobe. It neither renders video nor exercises authentic firmware.
