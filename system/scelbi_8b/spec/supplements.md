# SCELBAL supplement packages: acquisition and profile decision

Status: **out of profile**, with the reason recorded. This note exists so the
gap is a sourced decision rather than an omission.

## What the supplements are

SCELBAL was published as a base interpreter plus separately distributed
packages. Mike Willegal's SCELBAL page
(<https://www.willegal.net/scelbi/scelbal.html>) lists three:

| Package | What it adds |
| --- | --- |
| Mathematical Functions Supplement | transcendental and other math functions beyond the base four operations |
| Strings Supplement | string variables and string operations |
| Update Issues 1-6 | corrections published after the book |

The SCELBI Computer Museum documentation index
(<https://www.scelbi.com/documentation>) lists the same three items under
SCELBAL.

## Why they are not loaded here

**There is no binary image to load.** Both Willegal's page and the museum index
distribute the supplements as **scanned book pages (PDF)** — source listings and
diagrams, in the same form the base interpreter was originally distributed
("SCELBAL was released in two forms, paper tape and in book form... most people
purchased the book and then entered the program using whatever input system that
their particular computer had", Willegal). Only the base interpreter has
assembled `source` / `intel hex` / `binary` downloads.

So loading a supplement would mean one of:

- transcribing the listing from the scan by hand and assembling it, or
- recovering a paper-tape image, which requires the paper-tape reader to work
  and a tape to read.

Neither is a software-only step, and both produce an image whose correctness
would rest on the transcription rather than on a distributed artifact. That is a
different claim from the one this system makes about SCELBAL, where the binary is
the same 11942 bytes SIMH's guide loads.

**The base ROM has no hook for them.** In `sc1.asm` the user-defined-function
entry point is a stop:

```asm
;;; no user defined functions yet, stop here if we: see one.
UDEFX:   HLT
```

and the array/function pointer storage is declared but unpopulated
(`DATA 000,000,000,000 ; (PROBABLY STEP, FOR/NEXT, AND ARRAY PTR TEMP)`).
The parser has array-`LET` and function-call token paths (`SYNTX8`,
`PRIGHT`), but they terminate at `UDEFX`. A supplement is expected to supply
code at those addresses. The base image alone therefore cannot run string
variables, arrays or the extra math functions no matter how the board behaves —
this is a firmware gap, not a hardware one.

There are 4378 bytes free below the 16 KiB top (`sc1.bin` is 11942 bytes at
octal 0100, ending at octal 027346), so a supplement image would fit. Space is
not the constraint; provenance is.

## What is claimed

- The base **SC1 interpreter** is authentic and its bytes are the ones SIMH's
   guide loads.
- Programs using string variables, arrays or the extra math functions are
   **outside this profile**. They are not run and not claimed.
- The math actually exercised — floating point with 6 digits, `ABS`, `INT`,
   `SGN`, `RND`, `SQR` where the base provides them — is base-ROM behaviour,
   verified by `tb_calc`, `tb_game` and the console oracle comparison.

## What would change this

A published, hash-pinned binary or Intel-hex image of a supplement, or a
recovered paper-tape image with a documented provenance, would let the
supplement be loaded and a program that uses it be added to `tb/` and to the
oracle comparison. At that point the profile would widen and this note would be
replaced by a supplement section in `spec/spec.md`.

Until then the honest statement is the one in the README: the supplements are
not loaded, and that is a firmware-provenance limit rather than a board limit.