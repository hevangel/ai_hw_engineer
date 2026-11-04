# Zilog Z80 sources, oracle and software provenance

## Manufacturer sources

- Zilog [Z80 CPU User Manual, UM008011-0816](https://www.zilog.com/docs/z80/um0080.pdf)
  (August 2016, revision 11): architectural overview, pin functions, timing
  chapters (instruction fetch, memory read/write, I/O, bus request/acknowledge,
  interrupt request/acknowledge, non-maskable interrupt response, HALT exit),
  interrupt handling, the flag definitions, opcode tables by instruction group
  and the per-instruction descriptions with T-state counts. This is the CPU
  manual; UM0081 covers the Z80 peripheral family and is not a CPU source.
- The original 1976–1978 Zilog data books are useful cross-checks for the NMOS
  parts this design targets. They are not yet vendored; adding a dated copy with
  a SHA-256 is a phase-0 task so the pin-level contract cites a period document
  and not only a 2016 reformatting.

## Undocumented behavior

- Sean Young, *The Undocumented Z80 Documented*, version 0.91, 18 September
  2005: [PDF](http://www.z80.info/zip/z80-documented.pdf). The primary source for
  the Q latch, WZ/MEMPTR, F3/F5 tables, `SLL`, the DD-CB register copies and the
  interrupt quirks. To be vendored with a hash.
- [Z80 undocumented instructions](http://www.z80.info/z80undoc.htm)
  (Richard Spijkers 1992, updated by Jacco Bot 1996, with Bill Smythe's October
  1982 Northern Bytes article): the encoding list, tested on Z80A/Z80B/Z80H.
- [Z80 flag affection table](http://www.z80.info/z80sflag.htm): per-instruction
  flag effects including the undocumented bits. The table the RTL contract is
  generated from.
- [MEMPTR description](https://gist.github.com/0xcafed00d/17165035be8deb7a86ba082b07b47828):
  the esoteric WZ register and the flag leaks after `BIT n,(HL)` and ED-prefixed
  operations.
- [Zilog Z80 historical summary](https://en.wikipedia.org/wiki/Zilog_Z80):
  launch month, designers, transistor count, process, clock grades, first
  samples. Used only for history and date provenance, never for behavior.

## Independent oracle

- [superzazu/z80](https://github.com/superzazu/z80): complete Z80 emulator in
  C99 under the MIT license, single `z80.c`/`z80.h`, README states it passes
  both zexdoc and zexall. Same author as the `superzazu/8080` oracle already
  vendored for `amd_am9080`/`intel_8080`. Vendor unmodified at a pinned commit
  under `references/superzazu_z80/`, keep its license beside it, and record the
  SHA-256 of the two source files before first use. The `roms/` directory of
  that project is excluded: those images carry their own licenses.
- Limitation to record: this oracle counts cycles at instruction granularity,
  so it cannot verify M-cycle shapes or T-state counts. The native engine's
  timing oracle is the extracted UM0080 timing table, checked by pin traces.

## Exercisers

| Program | Provenance | Handling |
|---|---|---|
| ZEXDOC.COM, ZEXALL.COM | Frank D. Cringle, GPL-2.0, extracted from YAZE-AG 2.51.1; distributed in [agn453/ZEXALL](https://github.com/agn453/ZEXALL) | GPL binaries are downloaded into ignored `work/`, SHA-256 recorded, never committed |
| prelim.com | Vectored through the same public suites; license recorded before use | ignored `work/`, hash-checked |
| z80test | Patrik Rak's suite for MEMPTR/WZ behavior that ZEXALL does not cover | license and pinned release recorded before use |

ZEXDOC checks the six documented flags only; ZEXALL checks all eight, which is
why the undocumented-F3/F5 work cannot be signed off with ZEXDOC alone.

## Historical software

- CP/M 2.2 is the period operating system the exercisers and application tests
  run under. All original Digital Research files in the CP/M family were made
  redistributable by Caldera, which is why CP/M archives are widely mirrored
  ([CP/M-86 historical note](https://en.wikipedia.org/wiki/CP/M-86)); each file
  used here is hash-recorded and its acquisition path documented before use.
- TRS-80 Model I ROM images are copyright Tandy. They are never committed: the
  dependent system issue obtains them through its provenance manifest into
  ignored `work/`. The chip-level regressions do not require them.
- Application-class software (an assembler or BASIC interpreter) is selected
  during implementation; provenance, hash and the scripted transcript go here
  before the result counts as evidence.

## Repository rule

Nothing is vendored or downloaded by this specification milestone. Each artifact
above is added with a SHA-256 in this file at the moment it is first used, and
the harness refuses to run a binary whose hash does not match.
