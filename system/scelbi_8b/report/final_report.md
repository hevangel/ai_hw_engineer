# scelbi_8b verification report

Environment: `ai-hw-engineer:latest` (Verilator 5.052, Python 3).

| Check | Result |
|---|---|
| Strict Verilator lint (8008 + board) | Pass, zero warnings |
| `tb/tb_calc.sv` boot + calculator | Pass: READY sign-on, program entry, `A + B = 8.0` (1.69M instructions) |
| `tb/tb_game.sv` Shooting Stars session | Pass: listing typed in, rules answered, sequential guesses to a win, star hint + win burst + guess count + goodbye asserted (130.3M instructions, 2564 console bytes) |
| HTTP console (`scripts/test_backend.py`) | Pass: AUTO, READY, SCR, /api/load, RUN, WELCOME, rules, first guess answered with a star hint |
| Web panel | Manual: glass teletype, keyboard, digit keys, LOAD *STARS*, front-panel controls |

## Console protocol notes (from bringing up the real firmware)

- SCELBAL's I/O constants (`sc1.asm`): INPORT = 5, OUTPORT = 016 octal
  (= 14 decimal). Both documented port variants are wired on the card.
- The card forces bit 7 on received bytes and SCELBAL stores/prints every
  character with bit 7 set; its command parser compares `CPI 0203`-style
  high-bit tokens. Test needles must use the bit-7 encodings.
- The dispatcher re-runs its cold start (reprinting READY) on characters it
  does not consume, so the console ring scrolls continuously during
  interaction; HTTP checks are presence-based for that reason.
- This build hangs on `LET` statements (direct assignment works; the
  manual's own programs use both forms). The game listing avoids `LET`.
- SCELBAL's cold start prints the sign-on string at 0x01EA (part of the
  loaded image) and waits for console input at the 0x1600 mailbox.

## Provenance

- SCELBAL SC1 binary: Mike Willegal's SCELBI archive (the image SIMH's
  SCELBI guide loads; 11942 bytes at octal 0100). Same bytes as the
  `design/intel_8008` SCELBAL regression.
- Shooting Stars: Copyright 1974 PCC, transcribed from
  `github.com/maurymarkowitz/What-to-Do-After-you-Hit-Return` (`stars.hpb`),
  adapted to SCELBAL's dialect (no string variables, no `LET`, numeric
  Y/N answers). The adaptation is marked in `spec/spec.md`.
