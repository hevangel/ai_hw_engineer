# Commodore 64 implementation plan

1. Survey the existing chip designs (6510 on the native 6502 engine, 6526,
   6567/6569, 6581) and their interfaces. Done.
2. Add the missing 906114-01 PLA as its own verified design. Done
   (`design/commodore_906114`).
3. Board RTL: dot-clock phase generator, CPU/VIC bus sharing, three PLA
   evaluations, read mux, $0000/$0001 write-through, keyboard matrix,
   joysticks, IEC inverters, TOD, IRQ/NMI. Done (`src/c64_board.sv`).
4. Storage model with ROM loading and host observation ports. Done.
5. Firmware fetch with pinned hashes. Done.
6. Host harness: line protocol, raster assembly, audio mix, traces,
   checkpoints, FST capture. Done.
7. Independent oracle against unchanged VICE x64sc; tune the one free
   parameter (power-on CPU/VIC phase) and record it. Done: PAL
   cycle-exact, NTSC functional.
8. Original-ROM software regression. Done.
9. Web panel, backend test, screenshot. Done (Surfer viewer not available
   in the build container; see README).
10. Synthesis with storage blackboxed. Done.
11. Open: NTSC badline-stall discrepancy, SID analog stage, cartridges,
    1541 drive and IEC devices, datasette.
