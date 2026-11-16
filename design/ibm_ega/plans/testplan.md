# IBM EGA test plan

The simulation checks compare the RTL with the reference model
`scripts/ega_model.py`, written from IBM's technical reference (TR, August
2, 1984) and the spec contract, not from the RTL. Both run the same
script; `tb/ega_tb.cpp` drives the slot pins (address, data, -IOR/-IOW,
-MEMR/-MEMW, AEN, -DACK0, RESET DRV), the oscillator enables, switches,
jumpers, feature and light-pen inputs. The traces must match line for
line: every read value (or Z when the card does not drive), every IRQ 2
level/enable change, debug dumps of all registers and of plane memory, and
the complete dot stream (six colour bits, both retraces, blank, display
enable, driver enable) as run lengths.

| Check | Source of truth | Script |
|---|---|---|
| 39 directed tests: power-on state, switch sense, the BIOS POST switch/feature read, decode and 400h aliases, AEN, P3 at 2XX, readable vs write-only registers, attribute flip-flop, sequencer register widths and reset, RESET DRV, write modes 0-3 with rotate, set/reset, AND/OR/XOR, bit mask, map mask, read modes 0/1, read map select 0-7, colour compare/don't care, odd/even and chain with page bit and A16, memory maps and RAM enable, DACK0, extended memory bit, GC positions, ROM reads, frame timing in a tiny geometry, planar pixels, plane enable, shift register mode, shift load, text glyphs, 9-dot and line graphics, blink and background intensity, cursor shapes and skew, underline, panning (8- and 9-dot), palette address source, graphics blink, split screen, preset row scan, word mode, CMS0/SRS, count by two, dot clock /2, sequencer halt and clock selects, vertical interrupt, Input Status 1 bits and video status mux, light pen, sync polarity, driver disable, P1 | Literal values derived from TR (cited per test); the model must meet every one; RTL trace equal | `directed_tests.py`, `run_sim.sh` |
| 32 random seeds x 600 operations | Model | `gen_random_test.py`, `run_sim.sh` |
| Coverage gate over directed + random + BIOS runs: every register written; all 770 documented register-bit values written as 0 and 1; write modes 0-3, functions, set/reset; read modes, read map select 0-7; memory maps 0-3 read and written in both odd/even settings; chain with A16 and with the page bit; all readable ports, light-pen and write-only CRTC reads; undecoded writes and reads; DACK0; switch sense for every clock select and level; video status mux 0-3; text and graphics attribute modes and bits; cursor and underline rows; shift register and shift load; 8/9 dots with and without /2; every skew, cursor skew and retrace delay; panning 1-15; line compare, frames, vertical retrace and interrupt, light-pen latch, start-odd, count by two, HRTC/2, word mode, both character maps and maps 0-3; GC positions 0-3; all 23 BIOS table entries | Model counters | `report_coverage.py --require` |
| BIOS VIDEO_PARMS geometry, all 23 entries | Registers (TR p.25-44, E8); TR mode tables p.5-7 (resolution); TR display figures p.6-7 (rates within 2%) | `bios_modes.py`, `run_sim.sh` |
| BIOS replay, modes 3, 3* (Enhanced Color Display) and 7: VIDEO_SETUP, switch sense, feature bits, CH_GEN/DO_MAP2 font load through the ROM decode, mode 7 9-dot patches, SET_REGS, BLANK, PAL_ON, a test screen and cursor | Screen rebuilt from the ROM font and table (not the model); INFO_3 per listing lines 584-596 | `bios_replay.py`, `run_sim.sh` |
| Mutation check: 14 planted faults (write path, read path, CRTC timing, attribute path, I/O decode) must each produce a trace difference | Bench and model | `run_mutation.sh` |

The script format is documented at the top of `tb/ega_tb.cpp`.

Not covered by simulation: bus operations concurrent with dots (the bench
keeps them apart, as in the model's atomic time model), CPU wait states
(not modeled, E26), the feature connector, and the analog output.
