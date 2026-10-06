# Apple IIe MMU test plan

## Simulation (tb/tb_top.sv, self-checking + independent reference model)

1. **Reset state** — `rst_n` and the MPON bus sequence (three $01xx accesses then $FFFC) both produce: bank 2, read ROM, write enabled, aux off, ALTZP off, slot ROMs in $C100-$C7FF, internal $C3, window closed.
2. **Switch matrix** — write every $C000-$C00B and $C054-$C057 address; read flags back through $C011-$C018 bit 7; confirm each pair toggles its flag and leaves the others unchanged.
3. **Language-card prewrite** — Table 4-6 sequences: even-address access write-protects; two consecutive odd reads enable; an odd write preserves the current state and never enables (so the dance must be two odd reads); write state survives bank switches made by odd reads; $C011/$C012 readback tracks.
4. **Mapping matrix** — for each range ($0000-$01FF, $0200-$03FF, $0400-$07FF, $0800-$1FFF, $2000-$3FFF, $4000-$BFFF, $C000-$CFFF, $D000-$DFFF, $E000-$FFFF) crossed with relevant switch states and read/write: expected array select (ramen_n/en80_n), ROM enables, CXXXOUT, the $D000-$DFFF bank remap on RA4, and row/column RA values per Table 7-9.
5. **C800 window** — open via internal $C300 access, serve $C800-$CFFF internally, close via $CFFF; verify slot/internal selection before and after.
6. **DMA and INH** — DMA' low forces rw245 toward MD and leaves mapping active; INH' low drops RAM, ROM and aux selects.
7. **Historical sequences** (TRM Appendix I Monitor listing): the reset-time switch initialization, the AUXMOVE-style main/aux copy dance (RAMRD/RAMWRT set and restore around each byte), and the RESETRET slot-3 ROM probe dance (SETSLOTC3ROM, probe, SETINTC3ROM fallback); reference-model agreement on every cycle.

## Formal (formal/apple_iie_mmu.sby)

- BMC depth 32: mapping agreement for an anyconst address, array mutual exclusion, no RAM in $Cxxx, MD7/KBD' enable and value equations, prewrite state machine, MPON reset effect.
- Prove (unbounded, abc pdr): same property set.
- Cover: each mapping class, both language-card banks, write-enable via double read, 80STORE/HIRES overrides, C800 window open/close, MPON sequence.

## Coverage

xezim code coverage on the self-checking bench; uncovered items must be explained in `report/coverage_report.md`.

## Acceptance

lint clean (documented waivers only); formal bmc/prove/cover pass; both simulators pass all checks with reference-model agreement on every checked cycle; synthesis passes.
