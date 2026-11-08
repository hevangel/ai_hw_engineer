# NVC (VHDL compiler and simulator)

Tracker: [#82](https://github.com/hevangel/ai_hw_engineer/issues/82). NVC is the
upstream VHDL tool of the extended EDA overlay (`eda_extended/`). The owner wrote
"ncv"; the verified upstream name is NVC.

## Specification

| Item | Value |
| --- | --- |
| Source | https://github.com/nickg/nvc, release `r1.23.1` (2026-10-28) |
| Pinned revision | `fab54a9e96964b431050d837e163c22282a1df6c`, a `--filter=blob:none` clone checked out detached |
| License | GPL-3.0-or-later; some bundled VHDL libraries are Apache-2.0 (see the upstream README) |
| Build | `./autogen.sh`, out-of-tree `../configure --prefix=/opt/nvc --with-llvm=/usr/lib/llvm-21/bin/llvm-config`, `make`, `make install` |
| Prerequisites | Ubuntu 26.04 snapshot packages `llvm-21-dev`, `check`, `libdw-dev`, `libzstd-dev`, `libtool`, plus Flex, Automake, Autoconf, pkg-config and libffi from the base image |
| Runtime packages | `libllvm21`, `libdw1`, `libzstd1`; a C toolchain for linking |
| Platform | Linux x86_64 container only. Upstream also supports macOS and MSYS2; those are not qualified here. |
| Version string | `nvc 1.23.1 (1.23.1.r0.gfab54a9e) (Using LLVM 21.1.8)` |
| Install path | `/opt/nvc/bin` (on `PATH`), `/opt/nvc/include` for the VHPI headers |

Recipe, base-image resolution and reproduction commands are in
[eda_extended/README.md](../../eda_extended/README.md).

## Implementation plan

1. Pin a released revision and build it as an overlay stage so the SV base image
   and its Java support stay unchanged.
2. Qualify with a small corpus whose expected output comes from an independent
   model or the language manual, plus negative inputs with their diagnostics.
3. Run the upstream regression suite from the retained build stage.
4. Record the observed command lines, exit-status behavior, waveform formats and
   plugin interface, and what is **not** qualified.
5. Keep the corpus and `expected.txt` files as the reference for the NVC Rust port
   ([ai_sw_engineer#114](https://github.com/hevangel/ai_sw_engineer/issues/114)).

## Command lines

Analyse, elaborate and run are separate steps that share the `work` library in
the current directory:

```sh
nvc --std=08 -a design.vhd tb.vhd
nvc --std=08 -e tb_top
nvc --std=08 -r tb_top                               # stdout carries textio output
nvc --std=08 -r tb_top --wave=out.fst                # FST, the default format
nvc --std=08 -r tb_top --format=vcd --wave=out.vcd   # VCD
nvc --std=08 -r tb_top --load=./plugin.so            # VHPI plugin
nvc --std=08 -r tb_top --exit-severity=error         # make error-severity assertions fatal
```

## VHDL feature coverage

Selected by the corpus (`eda_extended/nvc/corpus/`), all with `--std=08` unless noted:

| Case | Exercises |
| --- | --- |
| `counter` | Entity/architecture, generics, `numeric_std`, clocked process, synchronous reset, `std.env.finish`, FST and VCD output |
| `crc8` | Packages and package bodies, functions, `std_logic_vector` arithmetic, `ieee.std_logic_textio` (`hwrite`) |
| `adder_exhaustive` | 131,072 exhaustive self-checks, `unsigned` arithmetic, nested loops, `assert ... severity failure` |
| `records_generics` | Records, unconstrained arrays, protected types, `for ... generate` with a generic, positional associations |
| `textio_strings` | `std.textio`, string slices and attributes, `to_string`, `'image`, `time` arithmetic |
| `std93` | A VHDL-1993 design analysed with `--std=93` |

Standards accepted by the analyser: `--std={1993,..,2019}`. VHDL-1993 and
VHDL-2008 are exercised here. VHDL-2019 only gets a trivial analyse/run check
done by hand while writing this record, not a corpus case.

## Behavior of the pinned build

Observed with the probes in `scripts/check_extended_eda.py`:

| Situation | Behavior |
| --- | --- |
| Syntax error | `nvc -a` exits 1 with `unexpected end while parsing port clause` |
| Unknown entity at elaboration | `nvc -e` exits 1 with `design unit NOT_DEFINED not found in library WORK` |
| `severity failure` assertion | Simulation stops; exit status 1; the statement after it does not run |
| `severity error` assertion | Simulation **continues**, but the process still exits 1 |
| `--exit-severity=error` | The error is fatal at once; the following statement does not run |
| `--exit-severity=failure` | The `severity error` run exits 0 |
| VHDL-2008 `process (all)` | Accepted by `--std=08`; rejected by `--std=93` (`unexpected all`) |

## Waveform format and simulator interfaces

- Waveforms: FST (default) and VCD. Both are accepted by the pinned Surver, so
  [Surfer](../surfer/README.md) can view NVC output (file-level interoperability).
- VHPI: a plugin built against `/opt/nvc/include/vhpi_user.h` loads with
  `--load=` and its start-of-simulation callback runs
  (`eda_extended/nvc/vhpi/hello_vhpi.c`). No other VHPI behavior is qualified.
- Not qualified: FLI, GTKWave, coverage reports (`--cover`), JIT/AOT options.

## SV/VHDL co-simulation boundary

**No SystemVerilog/VHDL co-simulation or mixed-language adapter is qualified.**
Installing NVC next to Xezim, Verilator and Icarus does not make them interoperate.
The only qualified exchange is by waveform file (FST/VCD). NVC's own Verilog and
VHDL-2019 front ends are described upstream as experimental and are unqualified.

## Verification

| Evidence | Result |
| --- | --- |
| `scripts/check_extended_eda.py` NVC and interoperability rows | See [`extended-results.json`](../eda-tool-qualification/extended-results.json) |
| Upstream `make check` in the build stage | `bin/unit_test` PASS (1,164 checks in 23 suites, 0 failures); `bin/run_regr` PASS (1,476 regressions ok, 14 skipped, 0 failed) |

Reproduce the upstream suite:

```sh
docker build --target nvc-build -f eda_extended/Dockerfile \
    --build-arg ENGINEER_IMAGE=ai-hw-engineer -t eda-ext-nvc-build .
docker run --rm eda-ext-nvc-build sh -c 'cd /opt/nvc-src/build && make check -j4'
```

## Known limitations

- Only Linux x86_64 in this container; no macOS, Windows or `arm64` evidence.
- The upstream suite skips 14 regressions: 13 need Tcl support, which
  is not built (`tcl not enabled`), and 1 needs `xmllint`, which is not installed.
- PSL is the upstream-documented exception to VHDL-2008 coverage and has no probe
  here.
- `boolean'image` printing lower-case `true` is an NVC observation; the VHDL
  manual text was not checked.
- The Rust port ([ai_sw_engineer#114](https://github.com/hevangel/ai_sw_engineer/issues/114))
  is not part of this record and is not claimed.
