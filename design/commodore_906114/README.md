# Commodore 906114-01 PLA

The 906114-01 is the Signetics 82S100 field-programmable logic array that
Commodore programmed as the Commodore 64's address decoder (board position
U17). From the 6510 processor port bits LORAM/HIRAM/CHAREN, the expansion
port's /EXROM and /GAME, the CPU or VIC-II address, the VIC's BA/AEC and the
CAS strobe, it selects DRAM, the BASIC, KERNAL and character ROMs, the I/O
area, the color-RAM write strobe and the cartridge ROML/ROMH windows. It is
the reason the C64 can bank 64 KiB of RAM under three ROMs and I/O.

**First introduced: 1982\* (fitted to the 1982 Commodore 64; chip-level
launch unconfirmed).** The date is the system's: MAME's
[c64.cpp at a pinned commit](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/mame/commodore/c64.cpp)
lists the original NTSC and PAL Commodore 64 machines as 1982 and their
ROM sets carry the `906114-01` dump (CRC 54c89351). No separately dated
Commodore document for the programmed part was located.

This design models the combinational decoder as 29 product terms on the
board's active levels. All 65,536 input words are checked against a map
derived from unchanged VICE source (32,632 words VICE defines, plus the
32,768 CAS-idle and 136 BA-low I/O-read words VICE does not model, checked
against the stated rules); nine seeded defects are detected; formal BMC and
twelve covers pass; both Verilator and Icarus agree; Yosys maps it to 142
cells. It drives the [Commodore 64 system](../../system/commodore_64/),
where original BASIC/KERNAL boot cycle-exact against VICE x64sc.

```sh
sh design/commodore_906114/scripts/run_all.sh   # lint, formal, sim, mutants, synth
```

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification report](report/final_report.md)
