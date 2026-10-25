# Altair 8800 virtual-platform verification report

## Result

`scripts/run_all.sh` passes end to end in `ai-hw-engineer:latest`
(Verilator 5.052, Yosys 0.69):

1. **Lint**: `verilator --lint-only -Wall` clean on `src/altair_8800.sv` and
   `src/altair_ram.sv` with the `intel_8080` core.
2. **Board testbench** (`tb/tb_top.sv`): PASS. Covers the Operator's Manual
   add program (12+34=46 at address 0x82) deposited through the real panel
   path, DEPOSIT/DEPOSIT NEXT display semantics, RESET → PC=0, STOP → HLDA
   lamp, PROTECT/UNPROTECT, single-step M1 semantics (one retired
   instruction per actuation), the 88-SIO status-bit/data contract with an
   `IN 00/ANI 01/JNZ; IN 01; OUT 01` echo loop, sense-switch input at port
   FFh and the HLTA lamp on HALT.
3. **Real-software regression** (`scripts/test_software.py`): PASS. The
   20-byte MITS SIO bootstrap is deposited through panel commands, the
   original 4K BASIC 3.2 tape (SHA-256 verified) is fed through the 88-SIO
   at ports 0/1, and the machine boots to the OK prompt after the
   documented startup dialog (`MEMORY SIZE` CR, `TERMINAL WIDTH` CR,
   `WANT SIN/RND/SQR` N). BASIC reports `13261 BYTES FREE` with the default
   16 KiB RAM, prints `BASIC VERSION 3.2 [4K VERSION]`, and answers
   `PRINT 2+2` → `4`, `PRINT 3/8` → `.375`, a `FOR/NEXT` loop → `1 2 3`
   and `PRINT "ALTAIR"` → `"ALTAIR"`. Booting to the OK prompt takes on the
   order of a million implementation steps (the CPU poll loops dominate).
   All architectural state stays in RTL;
   the host only drives panel switches, the serial line and tape files.
4. **Backend API test** (`scripts/test_backend.py`): PASS. Request
   validation (400 on bad address/key/action/tape size), deposit/examine
   serialization, SIO echo through the API, pause serialization under a
   concurrent poll, FST capture versioning and the `/waveform.fst` endpoint
   with content-length/version headers.
5. **Synthesis** (`scripts/run_synth.sh`): PASS. `altair_8800` plus the
   8080 core synthesizes with `check -assert`; the `altair_ram` storage
   model is read as a blackbox (external-interface boundary, as in the
   ibm_pc system).

## Defects found and fixed during verification

- The first DEPOSIT after RESET was lost because HLDA is granted one step
  after HOLD asserts; panel operations now wait for HLDA explicitly
  (`wait_panel_ready` in the host harness).
- The single-step freeze originally sampled the core's `retire_o` pulse
  combinationally, which Verilator schedules differently between the C++
  build and the `--timing` testbench build. The freeze now uses a
  registered `retire_seen`, making the stop-at-next-M1 semantics
  deterministic in every build.
- The RAM write port sampled combinational logic derived from
  `display_addr` in the same cycle the register updated; the write request
  is now registered and executes on the following edge, and EXAMINE/DEPOSIT
  commands settle one extra step so the host observes final state.
- `KEY` accepted one byte per command while the regression sent two;
  responses are now sent byte-by-byte (the CR was previously dropped and
  BASIC waited for it forever).
- The 88-SIO transmitter log was never cleared, so every state poll
  re-delivered the whole console history.

## Observed behavior of the original software

- 4K BASIC 3.2's startup prints `MEMORY SIZE` and `TERMINAL WIDTH` without
  question marks (the `? ` prompt comes from the line-input routine), and a
  bare CR re-prompts the `WANT SIN/RND/SQR` questions: answers must be
  `Y` or `N`.
- BASIC echoes typed characters itself (`InputLine` calls the OutChar RST),
  so the console must not local-echo.
- The console I/O bit contract (status bit 0: 1 = no received byte; bit 7:
  1 = transmitter busy) was pinned before boot from two independent
  artifacts (the MITS-era SIO loader and the annotated BASIC disassembly)
  and confirmed by the successful boot.

## Known limits

- Functional reconstruction: S-100 bus electrical timing, 8080 pin timing,
  wait states (the WAIT lamp never lights — no modelled device inserts
  them), DMA, the 88-SIO interrupt facility and its RST vectors, cassette
  and floppy subsystems are not modelled. An OUT to the SIO control port is
  accepted and ignored.
- The 88-SIO receiver is a 4096-byte model-level FIFO rather than the real
  card's one-byte register; the overflow/framing/parity status bits never
  set. Transmitter pacing (`tty_tx_delay`, default 300 steps) is a model
  choice, not a datasheet value.
- RAM beyond the configured top reads FFh; power-up RAM is zeroes.
- Memory protection is one latch for the whole RAM (real machines protect
  per board).
- Single step stops one instruction plus one M1 fetch later (stop-at-next-M1,
  matching the original panel); PC therefore rests inside the next opcode.
- The embedded Surfer 0.7.0 viewer bundled in the Docker image crashes at
  startup in the automation browser used for screenshots (even with no
  waveform loaded), so the committed screenshot shows the front panel
  without waves. The FST capture pipeline and endpoint are verified by
  `scripts/test_backend.py`; a browser that runs the bundled Surfer build
  will display captures. Surfer 0.7.0 upstream may need an update in the
  image to lift the incompatibility.
- The copyrighted 4K BASIC 3.2 tape is fetched from deramp.com into the
  ignored `work/` folder and never committed; the fetch script fails loudly
  on a hash mismatch.

## Provenance

Reference documents and their origins are listed in
[spec/reference/README.md](spec/reference/README.md). Historical dates: the
Altair 8800 announcement (Popular Electronics, January 1975) and 1975
shipments are year-level claims; month-level ship dates varied and are not
asserted.
