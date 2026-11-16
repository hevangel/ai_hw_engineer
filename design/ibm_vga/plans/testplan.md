# IBM PS/2 Display Adapter: test plan

All gates are in `scripts/run_all.sh` (nonzero exit on any failure).

| Stage | What | Oracle | Script |
|---|---|---|---|
| Lint | `verilator --lint-only -Wall` on the top and each of the 10 sub-modules alone | Verilator | `run_lint.sh` |
| ROM | download, size, SHA-256/SHA-1/CRC32, MAME `ibm-vga.bin` equality after the 8 KB rotation, 55 AA 30 header, checksum, sign-on, table shape | 86Box and MAME hash lists | `get_rom.py` |
| Directed | 27 tests with literal expectations from HITR/VGAXGA (register access and masks, card enable/setup, decode aliases, Protect, attribute flip-flop and 3C1, DAC state machine incl. cross-direction, write modes 0-3, read modes, odd/even, chain 4, memory maps, frame timing of every dot of two frames, planar/256-colour/text pixels, colour select and plane enable, PEL mask, overscan and Screen Off, double scan, split screen and panning compatibility, cursor off, switch sense for the ROM's 19 table values, video status mux, interrupt, status bits, RESET DRV, sequencer reset and dot clock) | the documents; the model must meet every expectation; the RTL trace (observed values at every expectation point included) must equal the model's | `directed_tests.py` |
| Random | 32 seeds x 600 operations: every port (also undecoded, aliased, AEN high), DAC sequences, memory in every window, chain 4/odd-even, 512-character fonts, 256-colour, refresh, RESET DRV, disable/setup, monitor load; full dump of registers, DAC and all 256 KB at the end | model vs RTL | `gen_random_test.py` |
| Coverage | every documented bit of every register written 0 and 1, every DAC component bit, every write/read mode, map, chain mode, readable port, DAC path, sense value, status mux, CRTC/attribute feature, skew, delay, panning value; every BIOS run | model counters | `report_coverage.py` |
| BIOS geometry | all 28 non-empty VIDEO_PARMS entries programmed as SET_REGS does; registers vs measured dot stream; the 22 display entries vs Figure 2-4/2-5 resolutions and HITR Figures 99-104 timing | IBM documents | `bios_modes.py` |
| Static I/O audit | every IN/OUT site of the ROM with DX tracking and helper call-site resolution; every reachable port decoded or a documented system/other-card port | ROM + spec decode (model `io_port`) | `rom_io_audit.py` |
| ROM execution | Unicorn runs the POST (colour, mono, no display) and INT 10h modes 3, 12h, 13h against the model; the bus trace with timing is replayed on model (every read value an expectation) and RTL (identical trace); pictures vs images rebuilt from the ROM font/tables and the BIOS's DAC writes | the ROM itself | `rom_exec.py` |
| Clock ratio | directed, 2 seeds, 4 entries, mode 13h run again with clk at 29.0 and 47.3 MHz and phase-accumulator enables | model traces | `run_sim.sh` |
| Mutation | 20 planted RTL faults, each must give a behavioral difference | the suite | `run_mutation.sh` |
| Formal | DAC, graphics controller, CRTC (h and v), card top: prove + cover; 5 planted faults must break a proof | SBY | `run_formal.sh` |
| Synthesis | Yosys `synth -flatten`, `check -assert`, no latches (RAM/ROM black boxes) | Yosys | `run_synth.sh` |
