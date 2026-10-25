# Optional transistor-level CPU reference

The board test can use an external Visual6502 NMOS transistor netlist through
the perfect6502 switch-level solver. This is an independent simulation
reference, **not** an implementation or completion of `design/mos_6502_family/mos_6502/cycle`.
It is not synthesizable. No behavioral memory is hidden inside the adapter.

Pinned source: [perfect6502 09fc542877a84318291aa42dab143a3e2c3db974](https://github.com/mist64/perfect6502/tree/09fc542877a84318291aa42dab143a3e2c3db974).
The solver (`netlist_sim.c`, associated headers) is MIT licensed.
**The netlist itself is CC BY-NC-SA 3.0**, by Greg James, Brian Silverman,
and Barry Silverman, from [Visual6502](http://www.visual6502.org/).
Do not describe the whole dependency as MIT licensed. Downloaded reference
artifacts belong in ignored `work/`, with their original notices intact.

The VPI adapter supports one reference CPU per simulator process. It samples
external data before the falling phase-0 edge, exposes address/RW/SYNC and
clock output nodes, and routes all data through the physical socket nets.
It requires Icarus VPI. Unknown bus samples must be counted by the harness;
coercing unknown bits is an explicitly limited reference boundary, not proof
that those reads were electrically valid.

## Historical firmware

The optional original Apple II image is fetched from
[AppleWin 736a12b0a2d59d122ec3d7257497d4ff1fc5c029](https://github.com/AppleWin/AppleWin/blob/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/resource/Apple2.rom).
It remains an external historical artifact with its original ownership;
the project's license does not relicense it. The 12 KiB socket image includes
the Monitor at F800, with reset vector FF59. SHA-256 checks are mandatory.
The download script splits it into six 2 KiB files without changing bytes.

Run with Icarus Verilog, its VPI headers, a C compiler, and Python 3 installed:

```sh
python3 scripts/fetch_board_references.py
SIMULATOR=iverilog sh scripts/run_board_sim.sh
sh scripts/run_reference_boot.sh
```

The fetch command needs network access only on the first run. Existing files
are rehashed on every invocation. Text sources are normalized to UTF-8/LF
with one final newline before hashing; ROM hashes use untouched binary bytes.
No third-party source or ROM image is committed to the repository.

## Explicit solver allocation fix

The pinned solver leaves its state allocation's groupcount uninitialized. The fetcher verifies the original netlist_sim.c unchanged, then generates netlist_sim_initialized.c with the single state allocation changed from malloc to calloc. All VPI and pin-oracle builds use the generated copy. This fixes undefined startup memory reads without changing the transistor network or solver algorithms. The [post-mortem](../../../failure_notes/2026-10-18-apple-ii-reference-initialization.md) records AddressSanitizer evidence and the startup regression.
