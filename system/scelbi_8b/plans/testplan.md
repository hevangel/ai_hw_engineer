# scelbi_8b test plan

Status: implemented and passing.

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

## Console fidelity

Every assertion runs against the console transcript ring. The card forces
bit 7 on received bytes and SCELBAL prints with bit 7 set, so all expected
strings are the bit-7-set encodings; typed-character echoes come back as
sent. The listing avoids `LET` (this build's LET parse hangs the
interpreter) and string variables (strings were a separate supplement).

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
