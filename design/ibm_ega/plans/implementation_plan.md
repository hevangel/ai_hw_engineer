# IBM EGA implementation plan

1. **Sources first.** Secure IBM's EGA technical reference (August 2,
   1984), its logic diagrams and BIOS listing; the VGA/XGA technical
   reference only as the basis of assumptions. Fetch the BIOS ROM 6277356
   with `scripts/get_rom.py`: pinned 86Box commit, hashes, MAME
   cross-check (the EPROM-order image is MAME's `6277356.u44`), listing
   bytes. Record everything TR leaves open as a numbered assumption.
2. **Reference model before RTL.** `scripts/ega_model.py` from TR and the
   spec contract: decode, register file and access rules, the processor
   write path (rotate, set/reset, function, bit mask, map mask, write modes,
   odd/even, chain, memory maps) and read path (latches, read modes, colour
   compare), the CRTC counters, the two-character display pipeline, the
   attribute controller and the dot stream. Directed tests
   (`directed_tests.py`) with literal expectations derived by hand must
   pass on the model alone.
3. **RTL, one module per device.** `ega_crtc`, `ega_sequencer`,
   `ega_graphics_ctrl` (twice), `ega_attribute_ctrl`, the card's
   `ega_io_decode` and `ega_ext_regs`, the `ega_display_fetch` pipeline,
   `ega_plane_ram` (four) and `ega_rom` (inverted address, chip-order
   image), wired in `ibm_ega`. One clock, clock enables for the oscillators,
   synchronous `rst_n`, separate RESET DRV. Lint with `-Wall`, no waivers.
4. **Lockstep bench.** `tb/ega_tb.cpp` runs the model's script on the
   pins and writes the same trace (reads, IRQ, dumps, the complete dot
   stream). Directed tests, 32 random seeds (`gen_random_test.py`) and a
   coverage gate (`report_coverage.py`).
5. **Real software.** Every VIDEO_PARMS entry programmed as SET_REGS does,
   geometry measured against the registers, TR's resolutions and TR's
   display rates (`bios_modes.py`); the POST switch/feature reads, the
   font load and mode set replayed for modes 3, 3* and 7 and the screen
   checked against one rebuilt from the ROM font (`bios_replay.py`).
6. **Formal, mutation, synthesis, run_all.** SBY proofs and covers for the
   graphics controller, the CRTC and the card top; 14 planted faults;
   Yosys `synth` with RAM/ROM black-boxed, `check -assert`, no latches;
   `run_all.sh` from a clean work directory.
7. **Documentation and tracking.** README, spec, plans, report, design
   index; GitHub issues #270 (chip set) and #271 (card).

The VGA design that follows can reuse `ega_crtc` (extend to the VGA
register widths), `ega_graphics_ctrl` (merge the two chips into four
planes), the attribute pipeline and the lockstep bench and model structure.
