# SCELBI 8B specification

Status: implemented and verified (see `report/final_report.md`).

## Historical sources and provenance

The SCELBI (SCientic-ELectronics-BIology) 8H was announced in a March 1974
QST advertisement; the 8B followed in 1975 with support for up to 16 KiB of
memory (SIMH's SCELBI notes, github.com/simh/simh Intel-Systems/scelbi;
Mike Willegal's SCELBI pages at willegal.net/scelbi). The console is a
"bit banger" serial interface, commonly to an ASR-33.

Firmware: the authentic SCELBAL interpreter binary (`src/rom/scelbal_sc1.bin`,
11942 bytes, loaded at octal 0100) from Mike Willegal's SCELBI archive — the
same image SIMH's SCELBI guide loads. Provenance and hashes:
`../../design/intel_mcs8/intel_8008/README.md` (the design's regression uses the same
bytes). SCELBAL documentation: the SCELBAL book scan
(scelbi.com/files/docs/scelbal/SCELBAL.pdf, chapter 14 = language reference)
and the assembler source (`sc1.asm`) — its I/O constants
(`INPORT EQU 5`, `OUTPORT EQU 016` octal) pin the console port assignment.

The Shooting Stars game listing (`spec/reference/shooting_stars.bas`) is the
1974 People's Computer Company game (copyright PCC; transcription:
github.com/maurymarkowitz/What-to-Do-After-you-Hit-Return, `stars.hpb`),
adapted to SCELBAL's dialect: no string variables (strings were a separate
supplement package) and numeric Y/N answers. It uses direct assignment
(`A=1`), which is the implied-LET form SCELBAL documents and which this
build accepts.

## Hardware and integration

- Intel 8008 core (the repository's `design/intel_mcs8/intel_8008`), 16 KiB RAM,
  reset starts at address 0 where a `JMP 0040` reaches SCELBAL.
- Console card: bit-banger serial per SIMH's SCELBI 8B model. Receive:
  9 INPs per character (start bit reads 0, data bits LSB first in bit 7,
  idle reads 0x80); the card forces bit 7 on received bytes (the SCELBI
  7-bit convention SCELBAL's parser relies on). Transmit: 10 OUTs per
  character (start + 8 data LSB first + stop, bit 0). Both documented port
  variants are wired: INP 2 / INP 5, OUT 10 / OUT 14 (SCELBAL itself uses
  INP 5 and OUT 14). INP 4 reads the flag port: bit 0 printer ready
  (always), bit 4 key available.
- Host writes stall the CPU for the write cycle (no lost stores); the host
  preloads memory with the SCELBAL image before reset.

## Host interface

Web console (`host/web`): ASR-33 glass teletype (parity-stripped display),
keyboard with number keys for the game, LOAD *STARS* button (types the
listing), RUN, and front-panel controls AUTO / P/P / AV-STEP (instruction or
cycle) / INIT / address trap. The panel polls drive the machine: each poll
runs 50000 cycles. HTTP API: `/api/state`, `/api/control`, `/api/tty`
(keyboard), `/api/load` (program text, newlines become CRs). The server binds
loopback by default (`SCELBI_HOST` overrides); `SCELBI_PORT` (default 8080).

## Acceptance criteria

- Boot: SCELBAL prints its sign-on (READY with the console's parity
  convention) and answers SCR with READY. Verified at the RTL level
  (`tb/tb_calc.sv`: types the SIMH guide's example program, RUN prints
  `A + B = 8.0`) and over HTTP (`scripts/test_backend.py`).
- Game: the Shooting Stars listing types in, RUNs, asks the rules question,
  and answers guesses with star hints; played to a win with sequential
  guesses and exited cleanly (`tb/tb_game.sv`, 130M+ instructions).
- Console fidelity: every byte the machine prints carries bit 7 (the card's
  parity convention); echoes of typed characters come back as sent.
- `LET` handling: both the keyword form (`10 LET A=1`) and the implied form
  (`10 A=1`) are accepted and produce `A + B = 8.0` (`tb/tb_let.sv`).
  The earlier claim that this build hangs on `LET` was a test-harness
  artifact — see `report/final_report.md`, "The LET hang".

## Qualified scope

- The console card models the SIMH byte-level protocol, not 110-baud analog
  timing. There is no start-bit timing, no baud rate, and no line driver.
- The paper-tape reader is not implemented. SIMH marks its own PTR as "not
  implemented yet", so no reference behavior is claimed for it.
- The SCELBAL math-functions and strings supplements are not loaded; the
  base SC1 image only. Programs that use string variables or the extra math
  functions are outside this profile.
- Verification is RTL simulation. There is no FPGA build, no physical 8008,
  and no silicon comparison.