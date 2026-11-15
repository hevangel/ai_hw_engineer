# scelbi_8b verification report

Environment: `ai-hw-engineer:latest` (Verilator 5.052, Python 3).
All results below were run in that image on 2026-11-15.

| Check | Result |
|---|---|
| Strict Verilator lint (8008 + board) | Pass, zero warnings |
| `tb/tb_calc.sv` boot + calculator | Pass: READY sign-on, program entry, `A + B = 8.0` (1.69M instructions) |
| `tb/tb_game.sv` Shooting Stars session | Pass: listing typed in, rules answered, sequential guesses to a win, star hint + win burst + guess count + goodbye asserted (130.3M instructions, 2564 console bytes) |
| `tb/tb_let.sv` `LET` reproducer (`+let=0`) | Pass: implied LET, `A + B = 8.0` (1.99M instructions) |
| `tb/tb_let.sv` `LET` reproducer (`+let=1`) | Pass: keyword LET, `A + B = 8.0` (1.99M instructions) |
| `scripts/run_waveform.sh` | Pass: `build/scelbi_8b.vcd` (1.1 MB, 8001 timestamps) over the RUN reply |
| `tb/tb_ptr.sv` (`scripts/run_ptr.sh`) | Pass: paper-tape reader loads a 24-byte tape through `INP 3` into `0x1000`, every byte checked |
| HTTP console (`scripts/test_backend.py`) | Pass: AUTO, READY, SCR, /api/load, RUN, WELCOME, rules, first guess answered with a star hint |
| Web panel | Manual: glass teletype, keyboard, digit keys, LOAD *STARS*, front-panel controls |

Reproduce with `sh system/scelbi_8b/scripts/run_all.sh` (lint, both RTL
regressions, both `LET` variants, HTTP backend) and
`sh system/scelbi_8b/scripts/run_waveform.sh` (VCD capture).

## The `LET` hang

The earlier report stated this SC1 build "hangs on `LET` statements" and the
game listing therefore avoided the keyword. That claim does not reproduce.

`tb/tb_let.sv` types the same calculator program twice, once with the keyword
(`10 LET A=1`, `+let=1`) and once with the implied form (`10 A=1`, `+let=0`).
Both runs print `A + B = 8.0` and retire the same number of instructions, so
the keyword is parsed and executed identically.

The original observation was a test-harness artifact: the program text was
typed into the console without giving the interpreter time to consume each
line, so a line could be swallowed by the dispatcher's READY reprint before
the parser saw it. Typing one line at a time and waiting for the console to
go quiet (the pattern `tb_calc` uses) removes the failure.

A second, independent check agrees. `work/scelbi_ref/oracle.py` is a
SCELBI 8B console simulator written directly from SIMH's `i8008.c` (not from
this RTL) plus SCELBAL's `sc1.asm` console routines. It runs `LET` constant,
`LET` expression, `LET` redefinition and implied-LET sessions and accepts all
of them, listing the program back unchanged. Because the two models are
independent, agreement is evidence about SCELBAL's behavior rather than a
shared misreading.

The RTL and the SIMH-derived oracle were also compared instruction by
instruction over the same session: register state, PC, flags and SP agree
exactly for the first 665k retired instructions, after which the traces
diverge at an `INP` boundary. That divergence is unresolved and is recorded
as a limitation below; it is not covered by the passing session tests.

## Console protocol notes (from bringing up the real firmware)

- SCELBAL's I/O constants (`sc1.asm`): INPORT = 5, OUTPORT = 016 octal
  (= 14 decimal). Both documented port variants are wired on the card.
- The card forces bit 7 on received bytes and SCELBAL stores/prints every
  character with bit 7 set; its command parser compares `CPI 0203`-style
  high-bit tokens. Test needles must use the bit-7 encodings.
- The dispatcher re-runs its cold start (reprinting READY) on characters it
  does not consume, so the console ring scrolls continuously during
  interaction; HTTP checks are presence-based for that reason.
- SCELBAL's cold start prints the sign-on string at 0x01EA (part of the
  loaded image) and waits for console input at the 0x1600 mailbox.

## Paper-tape reader

SIMH's SCELBI 8B model documents the reader's port and status bits in
`scelbi_io.c` but leaves its own PTR unit unimplemented (`ptr_svc` returns
immediately). The card here is built from that documented interface: `INP 3`
returns the byte under the read head and advances one byte; flag-port bit 1
reports data available and bit 2 reports tape in reader. There is no analog tape
timing — the reader presents a byte stream, not sprocket-hole timing.

SCELBAL does not use the reader: its `save`/`load` vectors in the SC1 ROM are
`JMP EXEC` stubs (`sc1.asm` lines 73-74), so the interpreter has no tape
routines to call. The reader is therefore exercised by real 8008 code rather
than by the interpreter: `tb/tb_ptr.sv` installs a small loader at `0x0200`,
preloads a 24-byte tape, and runs it. The loader reads `INP 3`, stores each byte
with `Lm M` at `[HL]` (incrementing `HL`), and the test checks every byte in
memory against the tape image. Result: all 24 bytes land in order.

## Web console screenshot

`assets/web-interface.png` is a real capture of the panel at 1500x1250, taken
after `/api/state` confirmed SCELBAL had booted, the calculator program was
entered, and the teletype showed `A + B = 8.0`. The capture shows the glass
teletype, the lamp rows, and the processor readouts (PC, ACC, flags, instruction
and cycle counts). The earlier claim that no screenshot existed is superseded.

## Waveform capture

`scripts/run_waveform.sh` boots SCELBAL, types the calculator program and RUN,
then records the CPU (PC, A, flags, retired), the bus (address, data,
mem/io read/write strobes), the console (tx data/strobe, rx push/full) and the
front-panel registers for 4000 clock cycles around the RUN reply. The VCD opens
in Surfer:

```sh
docker run --rm -it -v "$PWD:/work" -w /work ai-hw-engineer:latest \
  surfer system/scelbi_8b/build/scelbi_8b.vcd
```

The window is short on purpose: SCELBAL spends most of its time in the
console-polling loop, and a whole-session dump is ~800 MB of that loop with the
result buried in it.

## Provenance

- SCELBAL SC1 binary: Mike Willegal's SCELBI archive (the image SIMH's
  SCELBI guide loads; 11942 bytes at octal 0100). Same bytes as the
  `design/intel_mcs8/intel_8008` SCELBAL regression.
- Shooting Stars: Copyright 1974 PCC, transcribed from
  `github.com/maurymarkowitz/What-to-Do-After-you-Hit-Return` (`stars.hpb`),
  adapted to SCELBAL's dialect (no string variables, numeric Y/N answers).
  The adaptation is marked in `spec/spec.md`.
- SIMH's SCELBI notes (`Intel-Systems/scelbi/scelbi.txt`) and CPU model
  (`i8008.c`) are the behavioral reference for the console protocol and the
  load/run procedure.

## Known limits

- The RTL-vs-oracle instruction comparison is incomplete: the traces agree for
  the first 665k instructions and then diverge at an `INP` boundary. The
  session tests pass on both models, so this is a modeling or alignment
  difference rather than a known functional failure, but it is not explained.
- The paper-tape reader follows SIMH's documented port/flag map; SIMH's own PTR
  unit is unimplemented, so there is no reference emulator to diff against. The
  reader is verified only by the loader test above.
- Analog tape timing (sprocket holes, reader speed) is not modelled.
- The math-functions and strings supplements are not loaded. The base SC1 ROM
  has no function/array or string capability: its user-defined-function entry
  point is `UDEFX: HLT` and the parser stops at a function token, so those
  features need a supplement image that is not part of the 11942-byte SC1
  binary.
- No FPGA build, no physical hardware, no analog line timing.
- The web panel screenshot is not committed; `assets/` is empty.