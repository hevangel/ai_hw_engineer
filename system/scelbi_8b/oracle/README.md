# SCELBI 8B console oracle

`scelbi_oracle.py` is an independent SCELBI 8B console model used as a second
opinion when a console or CPU question comes up. It is **not** part of the RTL
and nothing in `src/` depends on it.

It is derived from SIMH, not from this repository's RTL:

- CPU semantics from `simh/Intel-Systems/scelbi/i8008.c` (Hans-Ake Lund, 2017)
- Console bit-banger from `simh/Intel-Systems/scelbi/scelbi_io.c`
  (`ttyin_d`, `ttyout_d`, the flag port and port map)

Both files are the SIMH SCELBI-8B model; `scelbi_io.c` is the part that defines
what the card does, and SIMH's own PTR unit is unimplemented there, so the
paper-tape reader here follows only the documented port/flag map.

## Why it exists

The first version of this system's report claimed SCELBAL "hangs on `LET`"
statements. That claim was wrong. Settling it needed a model that was not
written by reading the RTL, because a model derived from the RTL inherits the
RTL's misreadings. The oracle resolved it: `LET` parses and runs identically to
the implied form.

The same oracle later resolved the `INP`-boundary divergence (see
`report/final_report.md`): four `INP 5` reads out of 39,594 disagreed, and the
oracle was the side that was wrong -- it abandoned a received character when the
host queue emptied mid-frame, where SIMH's `ttyin_d` latches at the start bit and
finishes the frame. Fixing the oracle, not the RTL, made the two agree exactly.

## Use

```sh
# Type SCR and print the console reply.
python3 system/scelbi_8b/oracle/scelbi_oracle.py 'SCR'

# Longer session, bounded.
python3 system/scelbi_8b/oracle/scelbi_oracle.py 'SCR
10 A=1
20 PRINT A
RUN' --max-instructions 4000000
```

Newlines in the argument become carriage returns, which is what the ASR-33
sends. Output is the console transcript with bit 7 stripped; the instruction
count goes to stderr.

## Limits

- Functional only. No timing, no analog line behaviour, no interrupt model.
- 14-bit memory and the 8008's wrap-around at 16 KiB, matching the RTL's scope.
- Opcodes the RTL treats as NOPs (for example `INR`/`DCR` on M) are modelled as
  NOPs here too, so this is not an independent check of those encodings.
- It is a second implementation, not a hardware reference. Agreement between the
  oracle and the RTL is evidence the two models agree, which is weaker than
  evidence that either matches a real SCELBI.