# Space Invaders virtual-platform verification report

## Result

`scripts/run_all.sh` passes end to end from a clean tree in
`ai-hw-engineer:latest` (Verilator 5.052, Yosys 0.69):

1. **Lint**: `verilator --lint-only -Wall` clean on the board RTL
   (`space_invaders.sv`, `si_memory.sv`, `si_shift.sv`) with the
   `intel_8080` core.
2. **Board testbench** (`tb/tb_top.sv`): PASS. Shift-register unit test
   matching the hardware page example (writes 00→AA→FF, all eight offsets,
   results FF FF FE FD FA F5 EA D5); boot of the original ROM with both
   ISR vectors entered through their RST injections; ~2 interrupts served
   per 60 Hz frame (207 interrupts / 108 frames in the reference run);
   watchdog never fires; a coin inserts a BCD credit at 20EBh.
3. **Real-software regression** (`scripts/test_software.py`): PASS.
   - *Exact independent-oracle checkpoint*: at an exact instruction
     boundary (30 000 instructions, mid-boot before the ROM's first EI, so
     interrupt timing cannot contribute), the RTL board and the
     superzazu-8080 board twin agree on every CPU register, the flags
     byte, the shift register and all 16 384 bytes of the decoded memory
     image. The RTL harness reaches the boundary deterministically by
     stalling the bus (`freeze`: the core's wait state preserves all
     architectural state, and the final registered write settles).
   - *Attract mode*: 12 M cycles run cleanly — ~360 frames, ~712
     interrupts, splash screens and score table cycling, watchdog silent,
     no CPU fault or halt.
   - *Coin*: press+release on IN1 bit 0 → credit 01 (BCD).
   - *One-player start*: IN1 bit 2 → NewGame consumes the credit, the
     playfield and rack initialize.
   - *Play*: sweeping right while pulsing fire scores (10 points in 12
     shots in the reference run; stationary fire only erodes the player's
     own shields — that is genuine 1978 game behavior, not a defect).
   - *Oracle plays too*: the independent superzazu board twin runs the
     same script with real-T-cycle interrupt cadence and also scores.
4. **Backend API** (`scripts/test_backend.py`): PASS — request validation,
   run/pause serialization, the 7 168-byte screen payload, input-port
   bounds, FST capture versioning and the `/waveform.fst` endpoint.
5. **Synthesis** (`scripts/run_synth.sh`): PASS with the `si_memory`
   storage model blackboxed (external-interface boundary, as in ibm_pc
   and altair_8800).

## Defects found and fixed during verification

- **VRAM decode boundary bug** (the big one): the work-RAM/VRAM split
  tested address bits `[12:11]`, classifying 2400h–27FFh as work RAM
  because 2400h sets bit 10, not bit 11. ClearScreen then zeroed the
  stack and work RAM through the alias; RETs popped 0000h and the machine
  soft-rebooted in a loop. Fixed to `[12:10]==000`; caught by single-
  stepping the boot and dumping stack RAM.
- **Shift-register data race**: the board pulsed the shifter's write
  enable one cycle after the OUT transfer while feeding `bus_wdata`
  combinationally, so the shifter sampled the *next* transfer's data.
  Every sprite drawn through the shifter was garbage — the alien rack
  never appeared and shots never connected. Fixed by registering the
  captured byte with the request. Caught by rendering VRAM and comparing
  against the independent oracle's screen (the rack was present there).
- **VRAM bit order** (escaped defect, found by the repository owner
  reviewing the panel): the screen renderer drew each VRAM byte MSB-first,
  mirroring every glyph (`SCORE` rendered as `2COKE`). The hardware shifts
  bytes LSB-first; no automated stage gates glyph polarity (the oracle
  comparison is byte-level), so the failure note
  [failure_notes/2026-10-23-spaceinvaders-vram-bit-order.md](../../failure_notes/2026-10-23-spaceinvaders-vram-bit-order.md)
  records the lesson. Fixed to LSB-first; the committed screenshot shows
  the corrected screen.
- **Watchdog window**: 8 frames (my first guess) re-tripped during the
  ROM's multi-second boot/splash phases that legitimately run un-fed, and
  even 96 frames tripped inside the attract loop's `TwoSecDelay` (~120
  frames un-fed). Widened to 256 frames (~4.3 s) with the schematic RC
  unpinned; the game feeds it many times per frame in play.
- **Interrupt vector re-clock**: the vector flip-flop now re-clocks at
  each event (mid-screen/vblank) instead of holding a stale vector when
  an earlier request was still unacknowledged.
- **Exact-boundary checkpoint race**: stopping via HOLD lets one in-flight
  instruction plus prefetch complete before the freeze, so pc overshot
  the boundary by one instruction (and more for multi-byte instructions).
  Solved with the bus `freeze` input: the core's documented wait state
  parks it mid-transfer with everything preserved, giving byte-exact
  agreement with the oracle.
- **run_all ordering**: the testbench ran before `fetch_roms.py`, so a
  clean tree booted an empty ROM (0xFF = RST 38h loop) and never entered
  the ISRs. The fetch now runs first.
- **Missing `+rom` in the panel server** (escaped defect): the web panel's
  simulator process was launched without the ROM plusarg, so `$readmemh`
  never ran and the panel machine executed an all-FF ROM — the RST 38h
  trap loop, whose descending stack wrote garbage into work RAM (the
  "score" cells included). The regression suite never caught it because
  `test_software.py` passes `+rom` explicitly and the original backend
  test's checks were weak enough to pass on a dead machine. Found by
  rendering the board's memory window during the screenshot bring-up
  (ClearScreen's code at 1A5Ch read back as FFh). Fixed in the server,
  and `test_backend.py` now asserts the ROM signature is visible through
  the panel API so the trap cannot recur silently.
- The regression initially asserted score>0 with *stationary* autofire;
  the disassembly (fire-bounce flag, shield-hit status 03) and probing
  shot coordinates showed stationary fire chews the player's own shields.
  The gate now sweeps while firing, matching how the game is actually
  played; the oracle plays the same script.

## Known limits

- Functional reconstruction per the 8080 design's bus contract: one clock
  is one implementation step (not a native T-state). Interrupt cadence is
  counted in those steps (33 280 per frame), so the CPU executes more
  instructions per frame than real 2 MHz hardware; gameplay logic is
  frame-driven and runs correctly, but original per-instruction timing is
  not modelled. This is also why the oracle comparison uses a pre-EI
  checkpoint for byte-exactness and behavioral agreement for play.
- Sound is the port-latch bits mapped to short WebAudio tones; the
  discrete analog circuit, UFO loop hum and the four-note fleet march
  envelopes are not modeled. Sound-port writes are all captured and
  observable.
- The cocktail-screen-flip VRAM address remap (port 5 bit 5) is not
  modelled: this is the upright cabinet; two-player cocktail mode is out
  of scope. Two-player upright games work (both control sets are wired).
- Watchdog timeout (96 frames) is a model choice: the schematic's RC
  value is not cycle-documented in the sources used.
- Video/CPU bus arbitration, CRT effects, and the port-0 bit-7 demux
  quirk (never read by game code) are out of scope.
- The copyrighted ROM set lives only in ignored `work/`, fetched from the
  pinned PCjs archive revision with git-blob verification and CRC-32
  cross-checks against the canonical MAME driver values
  (734f5ad8 / 6bfaca4a / 0ccead96 / 14e538b0).
- The embedded Surfer 0.7.0 viewer bundled in the Docker image crashes at
  startup in the automation browser used for screenshots (documented on
  the Altair panel as well); the FST capture and endpoint are verified by
  the backend test, and captures download correctly.

## Provenance

Reference documents and their origins are in
[spec/reference/README.md](spec/reference/README.md); the assumption
ledger is in [spec/spec.md](spec/spec.md). The 1978 introduction is a
year-level claim (Taito Japan; Midway licensed release the same year).
