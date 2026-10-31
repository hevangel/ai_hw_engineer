# 2A03 / 2A07 implementation plan

1. Source the register map, APU timing tables, DMA cycle behaviour and the
   disabled decimal adder from NESdev (Visual 2A03-derived) before RTL;
   record every model choice in the spec's assumption ledger.
2. Reuse the verified [native NMOS 6502](../../mos_6502_family/mos_6502/README.md) with
   `DECIMAL_ENABLE=0`; do not modify the shared core (the C64 work depends
   on it). All 2A03-specific behaviour lives in the wrapper.
3. Build the APU as one module per unit: length table, envelope, pulse
   (ones'/two's-complement sweep negate), triangle, noise (region table),
   DMC (rate table, memory reader, IRQ), frame sequencer (4/5-step, delayed
   `$4017` reset, IRQ window). Add the OAM/DMC DMA engine that halts the
   CPU through RDY with get/put cycle alignment, then the `$4015` internal
   read, `$4016`/`$4017` enables and OUT0-2.
4. Separate the reset button (`rst_n`) from power-on (`por_n`): the APU keeps
   channel registers and the frame mode across a reset.
5. Verification:
   - Independent oracle: SingleStepTests `nes6502` vectors through the
     wrapper (cases touching APU registers excluded and counted).
   - Directed testbench in both regions: OAM DMA 513/514 cycles, frame IRQ
     cycle, pulse duty, length counters, triangle, noise LFSR, DMC fetch
     count and IRQ, controller strobes.
   - Formal (SBY/Yosys): get/put phase alternation, DMA halt protocol,
     per-unit invariants, reachable covers for OAM put, DMC get, writes under
     RDY, `$4015` reads and strobes.
   - Real software in [system/nes](../../../system/nes/): nestest trace and
     blargg CPU, APU, APU-reset and PAL APU test ROMs.
6. Strict lint for both regions and a Yosys synthesis check. Publish
   measured results and open gaps in the report.
