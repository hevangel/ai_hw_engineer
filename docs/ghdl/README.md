# GHDL (VHDL compiler and simulator)

Tracker: [#466](https://github.com/hevangel/ai_engineer/issues/466), a
cross-repository coordination issue in `hevangel/ai_engineer`. GHDL is the
second VHDL tool in the extended EDA overlay (`eda_extended/`), alongside NVC.
It is an **additional** VHDL implementation, not an alternative profile of NVC,
and the two are not claimed to interoperate.

## Specification

| Item | Value |
| --- | --- |
| Source | https://github.com/ghdl/ghdl, package `ghdl` 5.0.1 (`5.0.1+dfsg-1ubuntu1`) |
| Pinned revision | Exact Ubuntu package version `5.0.1+dfsg-1ubuntu1`, from the Ubuntu snapshot pinned in the [project Dockerfile](../../Dockerfile) (`UBUNTU_SNAPSHOT=20261001T000000Z`, `resolute/universe`) |
| Version string | `GHDL 5.0.1 (Ubuntu 5.0.1+dfsg-1ubuntu1) [Dunoon edition]` |
| Build backend / runtime | `mcode` JIT code generator; statically linked binary (`not a dynamic executable`); `--version` reports GNAT 14.2.0 |
| Packages | `ghdl`, `ghdl-common` (shared libraries), `ghdl-mcode` (the backend) |
| License | GPL-2.0-or-later (`License: GPL-2+`, copyright 2002-2025 Tristan Gingold and contributors) |
| Standards accepted | `--std=93`, `--std=00`, `--std=02`, `--std=08` |
| Standards rejected | `--std=87`, `--std=01`, `--std=19` (rejected by this build) |
| Install path | `/usr/bin/ghdl`, a small dispatcher that execs `/usr/bin/ghdl-mcode` |
| Waveforms | `--vcd=FILE` and `--fst=FILE` |

Recipe and reproduction commands are in
[eda_extended/README.md](../../eda_extended/README.md).

## Implementation plan

1. Pin the Ubuntu package version rather than tracking upstream releases, so the
   snapshot is the single source of reproducibility.
2. Qualify with the shared VHDL corpus that the NVC profile is held to, so the
   two tools are compared against the same expected output.
3. Add GHDL-specific cases for waveform output (VCD and FST) and a VHDL-93 run.
4. Record negative cases with the diagnostics GHDL actually emits.
5. State where GHDL differs from NVC, including the extra line it prints on
   `finish`, and what is **not** qualified.

## Command lines

Analyse, elaborate and run are separate steps:

```sh
ghdl -a --std=08 design.vhd tb.vhd        # analyse into the current directory
ghdl -e --std=08 tb_top                   # elaborate
ghdl -r --std=08 tb_top                   # run; stdout carries report output
ghdl -r --std=08 tb_top --vcd=out.vcd     # VCD waveform
ghdl -r --std=08 tb_top --fst=out.fst     # FST waveform
ghdl -r --std=08 tb_top --assert-level=error   # treat severity error as fatal
ghdl -r --std=08 tb_top --stop-time=50ns       # bounded run
```

GHDL keeps its library in the current directory (`work-obj08.cf` for
`--std=08`); this build has no `--work` switch, so cases must not share a
working directory.

## VHDL feature coverage

Selected by the corpus (`eda_extended/ghdl/` plus the shared
`eda_extended/nvc/corpus/` reused for the differential check):

| Case | Exercises |
| --- | --- |
| `wave` | Entity with a generic, clocked process, synchronous reset, `unsigned` arithmetic, `report`/`finish`, VCD and FST output |
| `std93` | VHDL-93 analysis and run: entity/architecture, explicit sensitivity list, a `for` loop in the testbench |
| `shared-*` (6 cases) | The NVC corpus: exhaustive adder with `severity failure`, CRC-8 with `numeric_std` and `ieee.std_logic_textio`, records/generics/protected types, `for ... generate`, text I/O and strings, and a VHDL-93 gate |

## How GHDL relates to NVC

Both are qualified VHDL-2008 tools in the same image. The relationship is
**complementary and differential**, not an adapter:

- They are independent implementations, so they give two opinions on the same
  VHDL. `scripts/check_extended_eda.py` runs the shared corpus through both and
  compares each against the same `expected.txt`.
- Observed difference: on a design that calls `std.env.finish`, GHDL prints an
  extra `simulation finished @<time>` line and NVC does not. The comparison
  drops that prefix; it is a reporting difference, not a behavioural one.
- Observed difference: GHDL's `--assert-level=error` makes `severity error`
  fatal, while NVC continues and still exits nonzero unless
  `--exit-severity=error` is given. Each tool's policy is asserted in its own
  profile; a shared script must not assume one tool's assertion policy for the
  other.
- **No mixed-language support is claimed.** Installing GHDL and NVC next to
  Xezim, Verilator and Icarus does not make them interoperate. No VHDL/
  SystemVerilog or VHDL/SystemC co-simulation adapter is qualified; the only
  qualified exchange is a waveform file (VCD/FST) that
  [Surfer](../surfer/README.md) can read.
- GHDL and NVC are **not** two profiles of one tool. Neither is presented as a
  replacement for the other, and no shared library or cache is assumed.

## Behaviour of the pinned build

Observed with the probes in `scripts/check_extended_eda.py`:

| Situation | Behavior |
| --- | --- |
| Syntax error | `ghdl -a` exits 1 with a position and an expected-token message (`unexpected end of file, 'END;' expected`) |
| Missing architecture body | Analysis succeeds; elaborating a top that needs it exits 1 with `cannot find entity or configuration` |
| `severity failure` assertion | Run stops; exit 1; the statement after it does not execute |
| VHDL-2008 `process (all)` | Accepted by `--std=08`; rejected by `--std=93` with `all sensitized process not allowed before VHDL 2008` |
| `--std=87`, `--std=01`, `--std=19` | Rejected by this build |
| Waveform | `--vcd=` writes a VCD with `$var` declarations; `--fst=` writes a non-empty FST |
| `--stop-time=50ns` | Terminates the run early with exit 0 |

## Waveform format and simulator interfaces

- Waveforms: VCD and FST. Both are file-level interoperable with
  [Surfer](../surfer/README.md); no live simulator server is involved.
- VPI/VHPIDIRECT: **not qualified.** The installed backend is `mcode`, which
  does not provide the VPI plugin path. A VHPIDIRECT foreign function was also
  rejected at analysis (`missing body for function ... declared at line ...`),
  so no C/C++ plugin boundary is claimed for GHDL here. NVC's VHPI remains the
  only qualified VHDL plugin path in this image.
- Not qualified: coverage, synthesis, `--ieee` library variants beyond the
  defaults, and the `ghdl-llvm`/`ghdl-gcc` backends (only `ghdl-mcode` is
  installed).

## Verification

| Evidence | Result |
| --- | --- |
| `scripts/check_extended_eda.py --tools ghdl` | See [`extended-results.json`](../eda-tool-qualification/extended-results.json) |
| Differential over the shared VHDL corpus | 5 of 6 cases byte-identical; `counter` differs only by GHDL's `simulation finished @226ns` line |

Reproduce:

```sh
docker build -f eda_extended/Dockerfile -t ai-hw-engineer-extended .
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer-extended \
    python3 scripts/check_extended_eda.py --work-dir scratchpad/eda-extended --tools ghdl
```

## Known limitations

- Linux x86_64 container only; no `arm64`, macOS or Windows evidence.
- The Debian/Ubuntu package is a `+dfsg` repack: some upstream test data and
  examples are excluded (`libraries/vital95`, `libraries/vital2000`, parts of
  `testsuite/`). Upstream's own test suite is therefore not present in this
  image and was not run.
- Only the `mcode` backend is installed. No LLVM/GCC backend, so no VPI.
- `--std=87`, `--std=01` and `--std=19` are rejected by this build; VHDL-2019
  is not available here.
- Only VHDL-93 and VHDL-2008 are exercised.
- The GHDL corpus is not the NVC corpus; the differential check reuses it and
  is documented as a comparison, not as two independent proofs of the same
  expected values.
- No Rust port is tracked for GHDL at the time of writing.