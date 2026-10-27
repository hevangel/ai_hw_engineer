# Commodore 906114-01 PLA specification

## Sources and provenance

- Unchanged VICE source, [svn-mirror commit d928b850](https://github.com/VICE-Team/svn-mirror/tree/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src):
  `c64/c64mem.c`, `c64/c64meminit.c` (the 32 memory configurations, read
  tables and write hooks) and `vicii/vicii.c` (Ultimax VIC ROMH window).
  `scripts/fetch_reference.py` downloads them to `work/vice/` and checks
  the SHA-256 values recorded in the script.
- Input pin order and output bit meanings follow MAME's `read_pla` and
  `PLA_OUT_*` in [c64.cpp at 41a494b6](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/mame/commodore/c64.cpp).
  MAME's fuse-map dump of the part is not used, so the model is
  independent of the emulator whose bit order it borrows.

## Interface

| Pin | Signal | Meaning |
|---|---|---|
| I0 | `cas_i` | VIC CAS strobe; high = idle (no DRAM or color-RAM access) |
| I1-I3 | `loram_i`, `hiram_i`, `charen_i` | 6510 port bits P0-P2 |
| I4 | `va14_i` | CIA2 PA0 level (/VA14); high in VIC banks 0 and 2 |
| I5-I8 | `a15_i`..`a12_i` | CPU address |
| I9 | `ba_i` | VIC BA (low = VIC wants the bus) |
| I10 | `aec_i` | inverted AEC; high = VIC owns the bus |
| I11 | `rw_i` | high = read |
| I12-I13 | `exrom_i`, `game_i` | expansion port, pulled up |
| I14-I15 | `va13_i`, `va12_i` | VIC address |

Outputs are active low: `casram_n_o`, `basic_n_o`, `kernal_n_o`,
`charom_n_o`, `grw_n_o`, `io_n_o`, `roml_n_o`, `romh_n_o`.

## Behavior

The 29 product terms are in `src/commodore_906114.sv`, grouped as BASIC
(p0), KERNAL (p1-p2), character ROM for the CPU (p3-p5) and the VIC at
$1000/$9000 (p6-p7), GR/W (p8), I/O (p9-p18), ROML (p19-p20), ROMH
(p21-p23) and the Ultimax unmapped windows (p24-p28). CASRAM is
`cas | p[7:0] | p[28:9]`: DRAM is deselected whenever a ROM, I/O or
unmapped term matches, and always when CAS is idle. ROMs and ROML/ROMH
in 8K/16K modes answer reads only, so writes fall through to DRAM; Ultimax
ROML/ROMH and I/O answer both.

## ASSUMPTION ledger

1. **I/O reads require BA high.** VICE does not model BA. The I/O read
   terms include BA so that a CPU read held by RDY (BA low) does not
   select I/O; all 136 such words are checked to give only CASRAM
   deselected. Writes are not BA-gated (the 6510 does not stop on writes).
2. **CAS idle.** VICE has no CAS input. With CAS high, every word must
   equal the CAS-low word with CASRAM and GR/W forced high.
3. **No physical term order.** The 82S100 has 48 term slots; only the
   logic function is claimed, not the slot assignment or the 82S100's
   propagation delay.
4. **Cartridge terms are verified against VICE tables only;** no
   cartridge hardware is attached in the system model.
