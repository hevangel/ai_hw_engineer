# scelbi_8b test plan

Status: implemented and passing (results in `report/final_report.md`).

## RTL regressions (Verilator, scripts/run_sim.sh)

- `tb/tb_calc.sv` — boot and calculator: after reset SCELBAL prints READY;
  the SIMH guide's example program (A=1, B=7, PRINT "A + B ="; PRINT A+B,
  RUN) produces `A + B = 8.0`. Guards against console-protocol regressions
  and interpreter bring-up breakage.
- `tb/tb_game.sv` — full game session: SCR, type the Shooting Stars listing
  from its hex image (FIFO-backpressured typing, exactly what /api/load
  does), verify the line-290 echo, RUN, answer the rules question, and guess
  sequentially until the game concedes; asserts the star hint, the win
  burst, the guess-count sentence, and the goodbye. The secret is SCELBAL's
  own RND, so the test plays the real game.
- `tb/tb_let.sv` — `LET` regression, run twice: `+let=0` types the implied
  form (`10 A=1`) and `+let=1` types the keyword form (`10 LET A=1`). Both
  must print `A + B = 8.0`. This is the evidence that the reported `LET`
  hang does not exist in this build and that the old console-driving pattern
  (typing a whole program without waiting for each line) was the cause.

## Console fidelity

Every assertion runs against the console transcript ring. The card forces
bit 7 on received bytes and SCELBAL prints with bit 7 set, so all expected
strings are the bit-7-set encodings; typed-character echoes come back as
sent. The Shooting Stars listing uses the implied LET and avoids string
variables (strings were a separate supplement).

## Paper-tape reader (scripts/run_ptr.sh)

`tb/tb_ptr.sv` proves the card works with real 8008 code rather than only being
wired up. A loader at `0x0200` reads `INP 3` and stores each byte with `Lm M`,
incrementing `HL`; the test preloads a 24-byte tape and then checks every byte
that landed in memory against the image. The opcodes were verified against the
8008 user manual: `INP 3` is `0x47`, `Lm M` (M-(r), source A) is `0xF8`,
`INR L` is `0x30`, `Llh`/`Lh` are `0x36`/`0x2E`.

## Web console screenshot

`assets/web-interface.png` is a real capture, not a mockup. The panel was driven
over `/api/tty` to a booted SCELBAL session showing `A + B = 8.0`, then
captured with headless Edge at 1500x1250. Before capturing, the script checks
`/api/state` actually reports the result, so the image cannot be taken of a
blank or early panel.

## Waveform capture (scripts/run_waveform.sh)

`tb/tb_wave.sv` boots SCELBAL, types the calculator program and RUN, then
records CPU, bus and console signals for 4000 cycles around the RUN reply.
Assertions are the same as `tb_calc` (the result string and `8.0` must be in
the transcript), so a passing capture is also a passing session.

## HTTP backend (scripts/test_backend.py)

Builds the simulator, starts the console server, and drives the same flow
over HTTP: AUTO, SCR, /api/load with the listing, RUN, rules, first guess
answered with a star hint. Presence-based checks only — SCELBAL's dispatcher
reprints READY on stray characters, so the ring scrolls continuously and
position-based checks would race.

## Independent reference sources

The SIMH SCELBI 8B model (Intel-Systems/scelbi) is the behavioral reference
for the bit-banger protocol and the SCELBAL load/run procedure; the SIMH
guide's example session (A=1, B=7 → 8.0) doubles as the expected output of
tb_calc.

`work/scelbi_ref/oracle.py` is a separate SCELBI 8B console simulator written
from SIMH's `i8008.c` rather than from this RTL. It is used to check that a
behavior is SCELBAL's and not a shared misreading: it accepts `LET` in all
tested forms, matching the RTL. The two models' instruction streams were also
diffed; they agree for the first 665k retired instructions and then diverge
at an `INP` boundary, which is recorded as an open limit in the report.