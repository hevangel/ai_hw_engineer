# Implementation plan — PDP-1 Am29xx

Status: core machine implemented and oracle-verified; Spacewar! and the
display-break path remain open. Issue
[#184](https://github.com/hevangel/ai_engineer/issues/184).

## Milestones

1. **Sourced contract** — done. F-15B (1961) and F-16 (Sept 1961) pinned; the
   selected profile excludes PDP-1D extensions, 16-channel breaks and the
   display-list revision. Assumption ledger written into the specification.
2. **Control store and assembler** — done. `scripts/ucasm.py` generates the
   control-word struct, the 4096-word ROM and a listing from
   `src/microcode/pdp1_uc.uc`; the generator is the single source of truth for
   the field layout.
3. **Datapath** — done. Five Am2901 slices, 18-bit architectural boundary with
   zeroed guard bits, end-around-carry repair, glue overflow, external shift
   network with per-register edge capture.
4. **Sequencer and memory** — done. Am2910 with a registered control word,
   dispatch ROMs for opcode/device/shift subcode, 4096×18 memory with a host
   load port.
5. **I/O** — done for the console, typewriter, reader/punch, Type 30 point
   plot, check status and ESM/LSM; sequence break implemented but unexercised
   by authentic software.
6. **Oracle** — done. SIMH PDP-1 built in a pinned Ubuntu container and driven
   through `show cpu history`; the RTL trace is compared instruction by
   instruction.
7. **Web panel and waveform** — done: registers, switches, tape/keyboard
   queues, display canvas, typewriter, FST capture and Surfer embedding.
8. **Authentic software** — open. Spacewar! 4.1 (`sw41f.rim`) is archived with
   provenance; running it needs the paper-tape read-in path and display break
   timing that the current build does not yet provide.
9. **Formal properties** — open. The glue contracts (guard bits, EAC loop,
   overflow, shift fill) are written down but not yet in an SBY task.

## Design decisions and why

- **Guard bits and a fix-up micro-op.** The slices' carry pins cannot expose
  the carry out of bit 17 inside a 20-bit chain, so the microcode adds the
  end-around carry back in a loop that runs at most twice. The alternative —
  a 19-bit adder with a real EAC path — would not be five Am2901 slices.
- **External shift network.** A 20-bit slice shift misplaces the fill bit by
  the two guard positions in one direction. The fill is glue, exactly as the
  original machine's discrete shift gates were.
- **Registered control word.** Feeding the ROM from the sequencer's Y output
  would close a combinational loop through the control store; registering the
  word breaks it and matches a real microcode pipeline register.
- **Indirect addressing keeps the opcode.** Only IR[12:0] comes from the
  indirect word; the opcode stays with the original instruction. Discovery:
  the `jmp i` regression failed until this was fixed.
- **Two edge latches.** Every combined AC/IO shift needs both registers'
  pre-shift edges before either shifts; one latch cannot serve both phases.

## Open work, in order

1. Paper-tape read-in mode and the RIM loader, so `sw41f.rim` boots.
2. Display frame timing and the sequence-break entry/exit path that Spacewar!
   uses (`lsm`/`tyi` in the break handler).
3. SBY tasks for the guard-bit, EAC, overflow and shift contracts.
4. Re-run the full oracle suite over the authentic programs once they boot.
