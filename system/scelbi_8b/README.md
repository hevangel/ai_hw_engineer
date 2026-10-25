# SCELBI 8B

The SCELBI 8B (Scelbi Computer Consulting, 1975) — an Intel 8008 with up to
16 KiB of memory and a bit-banger serial console — reconstructed as a virtual
platform that boots the authentic **SCELBAL** BASIC interpreter and plays the
1974 People's Computer Company game **Shooting Stars** on its glass teletype.

Historical sources: SIMH's SCELBI 8B notes (github.com/simh/simh,
Intel-Systems/scelbi), Mike Willegal's SCELBI pages
(willegal.net/scelbi), and the March 1974 QST announcement for the 8H
predecessor. The 8H/8B split (1974 hobbyist model, 1975 business model with
16 KiB support) follows SIMH's account.

## Web interface and waveform

No screenshot is committed yet; capture `assets/web-interface.jpg` after
booting the console and loading *STARS* (the glass teletype shows the READY
prompt and the game's star hints). No waveform capture is implemented.

The console: an ASR-33 glass teletype (the game's "display"), a keyboard
with number keys (the game's "input" — type your guess 1–100 and the machine
answers with stars: more stars, closer), a LOAD \*STARS\* button that types
the 1974 PCC listing into SCELBAL, and the front panel (AUTO / P/P /
AV-STEP / INIT / address trap / memory lamps).

## Run

```sh
docker run --rm -p 127.0.0.1:8083:8080 -v "$PWD:/work" -w /work \
  ai-hw-engineer:latest sh system/scelbi_8b/scripts/run_system.sh
```

Open <http://localhost:8083/>. Press **LOAD \*STARS\*** (types the listing
after the panel's SCR), then **RUN**, answer `1` to the rules question, and
guess. The server binds loopback by default (`SCELBI_HOST` overrides).

## Verification and boundaries

`sh system/scelbi_8b/scripts/run_all.sh` runs strict lint, the RTL
regressions, and the HTTP backend test:

- `tb/tb_calc.sv` — boots SCELBAL, types the SIMH guide's example program,
  RUN prints `A + B = 8.0` (floating point, 6 digits).
- `tb/tb_game.sv` — types the Shooting Stars listing, plays with sequential
  guesses to a win (star hints, win burst, guess count, goodbye), 130M+
  instructions, every console byte checked.
- `scripts/test_backend.py` — the same flow through the HTTP console
  (AUTO, SCR, /api/load, RUN, rules, first guess answered with stars).

Boundaries: the console card models the byte-level bit-banger protocol
(SIMH's model), not 110-baud analog timing; the paper-tape reader is not
implemented; the SCELBAL math-functions and strings supplements are not
loaded (the base SC1 image only). This build's interpreter hangs on `LET`
statements — the game listing uses direct assignments (documented in the
specification).

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Verification report](report/final_report.md)
- [Shooting Stars listing](spec/reference/shooting_stars.bas)
