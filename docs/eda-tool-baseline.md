# EDA tool baseline: pins, licenses, compatibility and limits

This page is the acceptance record for the maintained hardware EDA tools. It
complements [the qualification report](eda-tool-qualification.md), which holds
the original positive and negative probe results. Everything here describes
the **pinned tools image** built from the root [Dockerfile](../Dockerfile), plus
the optional [Apple II overlay](../system/apple_ii/Dockerfile). It does not
cover tool features that no probe exercises; those are listed as unsupported or
unqualified below.

## Image identity and environment boundaries

| Item | Value |
| --- | --- |
| Base image | `ubuntu:26.04@sha256:da6fc2be547864451aa253836dd926da33623312df4a9a243e35dc877c378a78`, Ubuntu 26.04.1 LTS |
| Package snapshot | `https://snapshot.ubuntu.com/ubuntu/20261001T000000Z` (resolute, -updates, -security, -backports) |
| Architecture | `x86_64` Linux container only. No `arm64` build has been attempted. |
| Mode | Headless. The Surfer desktop GUI is built (`surfer --version`) but only exercised through the web viewer served by `surver`/`serve_web.sh` and a real browser. |
| Network at runtime | Not required by any probe. Image builds need GitHub, GitLab, crates.io, PyPI and the Ubuntu snapshot service. |
| Resources | Probes ran with Docker Desktop defaults. Large-waveform memory and time are measured in [Surfer](#surfer-waveform-viewer). |
| Base vs overlay | The base image has no Icarus Verilog. Icarus 12.0-3 is only in `ai-hw-engineer-apple-ii`, built `FROM ai-hw-engineer`. |

## Pinned tools, sources and licenses

Each revision is the value of the matching `ARG` in the [Dockerfile](../Dockerfile).
Licenses were read from the upstream `LICENSE`/`COPYING` file at the pinned
revision, not from memory.

| Tool | Pin | Source | License | Used for |
| --- | --- | --- | --- | --- |
| Verilator 5.052 | `ea338be98e1e838d3518809ce8899f85a009963c` | github.com/verilator/verilator | LGPL-3.0 (or Artistic-2.0 per upstream docs) | Lint, `--binary` simulation, FST trace, coverage |
| Yosys 0.69 | `9f75ca1f9834a39a863915b5dae0c7b1e33533bc` | github.com/YosysHQ/yosys | ISC | Synthesis, JSON netlists, structural `check` |
| SymbiYosys | `b1a1e98cba941ec8433f8dc27f416cd7bb7f14be` | github.com/YosysHQ/sby | ISC | BMC, k-induction, cover, counterexamples |
| EQY | `7a92d8441aa442dd1b5543458d6f1060a8f85dd1` | github.com/YosysHQ/eqy | ISC | RTL-to-gate equivalence |
| Yices 2.7.0 | `85cf17e44eac76b5d14b297c09fc9bfecf47ef65` | github.com/SRI-CSL/yices2 | GPL-3.0 | EQY SMT solver; SBY `smtbmc yices` |
| Z3 5.1.0 | release zip, SHA-256 `f47be8d27d3230e823bf1eeede2fe0abaca55bb78d0b59974370e6689a92284a` | github.com/Z3Prover/z3 | MIT | SBY `smtbmc z3` |
| Xezim 0.11.3 | `058f2bba58648452e5799d17572356ebcae7d163` | github.com/aionhw/xezim | Apache-2.0 | Simulation, UVM, VCD output |
| Surfer 0.7.0 | `bd749b1f786c1c62cd67893ca71346cbe6983915`, Trunk 0.21.14 | gitlab.com/surfer-project/surfer | EUPL-1.2 | Waveform viewer, `surver` server, web app |
| Verible v0.0-4296-g0f262651 | release tarball, SHA-256 `8569defb891d2316067613ea00442af28a7a09d405d95b54c0c91f9942d26635` | github.com/chipsalliance/verible | Apache-2.0 | Format, lint, syntax check |
| UVM reference libraries | submodule `libs/uvm` (`1.1d`, `1.2`, `1800.2-2017`, `1800.2-2020`) | Accellera releases | Apache-2.0 | UVM testbenches (Xezim) |
| Icarus Verilog 12.0-3 | Ubuntu package `iverilog=12.0-3` (overlay only) | Ubuntu snapshot | GPL-2.0 (distribution package) | Independent four-state simulator, VPI host |
| Java | Ubuntu `default-jdk-headless` from the same snapshot | Ubuntu snapshot | GPL-2.0 with Classpath Exception (OpenJDK package) | Independent Java oracles ([Java guide](java/README.md)) |
| Rust 1.99.0 / rustup 1.29.1 | `RUSTUP_INIT_SHA256=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71` | static.rust-lang.org | MIT OR Apache-2.0 | Build stage only (Xezim, Surfer) |

Patches applied to upstream tools in this repository:

| Patch | Where | Scope |
| --- | --- | --- |
| Remove the stray `0-3` token from the packaged `iverilog-vpi` helper | `system/apple_ii/Dockerfile` | Binary-package workaround for `iverilog=12.0-3`; source-level fix and reproducer in [the root-cause report](iverilog/vpi-prefix-map-root-cause.md) |
| Surfer `index.html` readiness probe (HDL Workbench only) | `hdl-workbench/apps/ide/public/surfer/` | Not part of this image; see [Surfer](#surfer-waveform-viewer) |

No other upstream source is patched. Z3, Verible and the Rust installer are
verified against recorded SHA-256 values during the build.

## Compatibility matrix

| Pair | Constraint | Evidence |
| --- | --- | --- |
| EQY and Yosys | EQY plugins (`eqy_partition`, `eqy_combine`, `eqy_recode`) must be built against the installed Yosys. The image builds EQY in the `FROM yosys-build` stage so the ABI matches. | `compat yosys-version-and-eqy-plugin-abi` loads `eqy_combine.so` into Yosys 0.69; `eqy equivalent` and `eqy inequivalent` |
| SBY and Yosys | SBY drives the installed Yosys and `yosys-abc`. | `sby bmc-prove-cover`, `compat sby-abc-pdr` |
| SBY and solvers | `smtbmc` works with Z3 5.1.0 and Yices 2.7.0 on `PATH`. Boolector, Bitwuzla, cvc5 and the AIGER tools (`aigbmc`, `suprove`, `avy`, `rIC3`) are **not installed**. | `compat sby-smtbmc-z3`, `compat sby-smtbmc-yices`, `compat sby-boolector-unsupported` |
| EQY and solvers | Yices is EQY's preferred SMT solver and SBY's checker for `abc` counterexamples. | Dockerfile `yices-build` comment; `eqy` probes |
| Xezim and UVM | Xezim finds UVM through `XEZIM_UVM_DIR=/opt/uvm`; version via `UVM_HOME_*`. Probes use `-D UVM_NO_DPI`. | `uvm-versions 1.2`, `1800.2-2017`, `1800.2-2020` |
| Xezim and Surfer | Xezim writes VCD with `--wave`; Surfer/Surver reads VCD, FST and GHW. | `xezim simulate`, `surfer surver-serves-vcd` |
| Verilator and Surfer | Verilator `--trace-fst` output loads in Surver's supported formats. | `verilator-trace fst-and-coverage` |
| Java and design oracles | `javac` and `java` from `default-jdk-headless` build the unchanged Am2900ME reference and adapters. | `java javac-and-java` (see [result status](#java-and-the-independent-oracle-runtime)) |
| Icarus and the base image | Icarus is **overlay only**; do not assume `iverilog` in the base image. | `iverilog` probes run in the overlay |
| Python | Python 3.14.4 from the Ubuntu snapshot drives SBY, EQY and the audit scripts. | `scripts/check_eda_tools.py` |

## Supported and unsupported behavior per tool

"Probe" names refer to rows in
[`eda-tool-qualification/results.json`](eda-tool-qualification/results.json).
A behavior that no probe covers is **unqualified**, not claimed unsupported.

| Tool | Supported and qualified | Unsupported or unqualified |
| --- | --- | --- |
| Xezim | `--simulate`, `--sv2017`, `--error-exit`, `--wave` VCD, direct `$fatal` exits nonzero, UVM 1.2 / 1800.2-2017 / 1800.2-2020 with `UVM_NO_DPI`, 13 differential SystemVerilog semantics cases against Verilator | UVM with DPI enabled; four-state X/Z behavior (the Verilator oracle is two-state, so the differential cases avoid X/Z); `$error` exits nonzero only with `--error-exit`; the 0.11.4 upgrade is native-qualified only (its WebAssembly build fails, see [Xezim](#xezim-native-webassembly-and-the-0114-upgrade)) |
| UVM | Factory/test selection, objection lifecycle, zero-fatal run, deliberate `uvm_fatal` ends the run with `UVM_FATAL: 1` and the exit code is not trusted | A zero UVM process exit is never accepted; the report summary must be read. UVM 1.1d is present but not probed. |
| Verilator | `--lint-only -Wall`, `--binary --timing --assert`, `--trace-fst`, `--coverage`, syntax errors exit nonzero | Not used to run UVM. Two-state only. Multithreaded builds are documented but not qualified. |
| Yosys | `read_verilog -sv`, `hierarchy -check`, `synth`, `check -assert`, `write_json`, unresolved cell exits nonzero | The `slang` plugin is **not installed** (`compat yosys-slang-plugin-unsupported`). Vendor technology mapping flows are not qualified. |
| SymbiYosys | `bmc`, `prove` (k-induction), `cover`, counterexample on a false property, `smtbmc z3`, `smtbmc yices`, `abc pdr` | `smtbmc boolector`, `btormc` and AIGER engines fail with `engine_0 ... did not return a status`, return code 16 |
| EQY | `use sat` equivalence, deliberate inequivalence fails, plugins load into Yosys 0.69 | Partitioned/sequential strategies beyond the probe design; solvers other than Yices/Z3 |
| Verible | Version, format, lint, deliberate syntax error rejected | The language server is not exercised |
| Icarus (overlay) | Four-state compile/run, packaged C and C++ VPI helper, documented direct-`cc` build, `$fatal` exits nonzero | Absent from the base image |
| Surfer | `surfer --version`, web app and `serve_web.sh` present, `surver` serves a VCD with token authentication, short and wrong tokens rejected | Native desktop GUI (headless image); browsers beyond those in [Surfer](#surfer-waveform-viewer) |
| Java | `javac` and `java` compile and run a class; the Am2901 Java oracle builds and runs | Present only in images built from the current `Dockerfile`; older local images have no JDK |

## Where the evidence lives

| Evidence | Location |
| --- | --- |
| Per-tool positive/negative probes (commands, exit codes, pass/fail) | [`eda-tool-qualification/results.json`](eda-tool-qualification/results.json), produced by `scripts/check_eda_tools.py` |
| Xezim against Verilator semantics | [`eda-tool-qualification/xezim-oracle-results.json`](eda-tool-qualification/xezim-oracle-results.json), produced by `scripts/xezim_oracle_compare.py` |
| Surver large-waveform measurements | [`eda-tool-qualification/surfer-limits-results.json`](eda-tool-qualification/surfer-limits-results.json), produced by `scripts/surfer_waveform_limits.py` |
| Native Xezim 0.11.4 probes and differential run | [`xezim-0.11.4-results.json`](eda-tool-qualification/xezim-0.11.4-results.json), [`xezim-0.11.4-oracle-results.json`](eda-tool-qualification/xezim-0.11.4-oracle-results.json) |
| Icarus overlay probes | [`icarus-overlay-results.json`](eda-tool-qualification/icarus-overlay-results.json) |
| WebAssembly Worker harness (existing bundle) | [`xezim-wasm-harness-results.json`](eda-tool-qualification/xezim-wasm-harness-results.json), from `hdl-workbench/apps/ide/scripts/wasm-browser-acceptance.mjs` |
| Original qualification report and browser proof | [eda-tool-qualification.md](eda-tool-qualification.md) |
| Merged implementation PR | [#79 Fix Icarus VPI helper and verify EDA tool workflows](https://github.com/hevangel/ai_hw_engineer/pull/79) |
| Acceptance PR for this record | See the issue comments on #68 to #77 |

Reproduce everything from the repository root:

```sh
docker build -t ai-hw-engineer .
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer \
    python3 scripts/check_eda_tools.py --work-dir scratchpad/eda-audit
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer \
    python3 scripts/xezim_oracle_compare.py --work-dir scratchpad/xezim-oracle
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer \
    python3 scripts/surfer_waveform_limits.py --work-dir scratchpad/surfer-limits
docker build -f system/apple_ii/Dockerfile -t ai-hw-engineer-apple-ii .
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer-apple-ii \
    python3 scripts/check_eda_tools.py --tools iverilog --work-dir scratchpad/eda-audit-icarus
```

## Surfer waveform viewer

**Provenance.** The image builds Surfer 0.7.0 at `bd749b1f786c1c62cd67893ca71346cbe6983915`
from the upstream GitLab tree, using the pinned Trunk 0.21.14, and keeps the
EUPL-1.2 license. HDL Workbench ships the same release as unmodified WASM and
JavaScript assets. Its `UPSTREAM.md` records the commit, license and the
WASM SHA-256 `1341ad01c59f5169209239728417d14f430183abd92515f22bf07cd7c86937ae`.
`UPSTREAM-SHA256SUMS` lists every unmodified asset, and I re-verified all of
them with `sha256sum -c`. The one locally modified file, the browser entry
`index.html`, is checked against `LOCAL-WRAPPER-SHA256SUMS`; it matches the
committed blob (a CRLF checkout changes only the working-tree bytes).

**Adapter boundary.** Unstable Surfer messages stay inside the versioned
adapter `hdl-workbench/apps/ide/src/surfer/SurferIframeAdapter.ts`, which pins
`PINNED_SURFER_VERSION = "0.7.0"` and the commit above, exposes four typed
commands (`loadWaveform`, `addSignals`, `setCursor`, `zoom`) and rejects
cross-origin URLs, bad signal paths and bad time ranges with typed errors. The
IDE test suite passes (9 files, 57 tests), including the adapter and panel
tests.

**Browsers.** Real-browser evidence for the pinned build:

| Browser | Evidence |
| --- | --- |
| Firefox 152.0.4-beta.30 (Camoufox) | HDL Workbench `apps/ide/test-artifacts/surfer/browser-test-log.json`: same-origin VCD load, `AddVariables`, `CursorSet`, `ZoomToRange`, iframe-reload readiness handshake; no console or page errors |
| Chromium-based built-in browser | [Qualification report](eda-tool-qualification.md#built-in-browser-proof): VCD load through local Surver, expand `tb`, add three signals, cursors, zoom |

Other browsers are unqualified. Safari and mobile browsers have not been run.

**Large waveforms.** `scripts/surfer_waveform_limits.py` generates a 64-signal
VCD, starts `surver`, and records load time and peak resident memory in the
pinned container (Docker Desktop defaults, one run each):

| VCD size | Loaded | Time to loaded (0.5 s polling) | Peak `surver` memory |
| --- | --- | --- | --- |
| 10 MB | yes | 0.53 s | 15.1 MB |
| 100 MB | yes | 0.51 s | 130.3 MB |
| 400 MB | yes | 2.01 s | 503 MB |

Surver memory is roughly 1.2 to 1.3 times the file size. These are server-side
numbers. The browser viewer decodes in WebAssembly, and HDL Workbench caps its
own Worker run at 256 MiB of WASM memory, so the browser limit is lower than the
server limit. Files larger than 400 MB were not tried.

**Upgrade regression.** Before moving the pin, re-run `check_eda_tools.py --tools surfer`,
`sha256sum -c` on the HDL Workbench asset sums, its IDE tests and the Surfer
browser acceptance script, and update `UPSTREAM.md`.

## Xezim: native, WebAssembly and the 0.11.4 upgrade

The image pins Xezim 0.11.3. HDL Workbench vendors Xezim **0.11.4**
(`e8266416d52b0bed45c0b78b8b7db39098221391`, core `8ebdf4a3f1346fe758e98f4a6a6c822f17f38e54`,
`MIT OR Apache-2.0`, patches documented in its `vendor/UPSTREAM.md`). I took
0.11.4 as the selected upgrade and ran the same qualification against it.

| Check | Result |
| --- | --- |
| Native 0.11.4 CLI, built from the vendored sources with `--features jit` (Rust 1.99.1, Linux), binary SHA-256 `4f1e93644c5942507dc450c778a37a274d09a08d44037608dee61080b3e4d2be` | Built. Because `vendor/xezim` has no `Cargo.lock`, the build used the lock from `crates/xezim-web` |
| `check_eda_tools.py --tools xezim,uvm,uvm-versions` against 0.11.4 | 8 of 8 pass ([results](eda-tool-qualification/xezim-0.11.4-results.json)) |
| Differential semantics against Verilator, 0.11.3 | 13 of 13 cases identical ([results](eda-tool-qualification/xezim-oracle-results.json)) |
| Differential semantics against Verilator, 0.11.4 | 13 of 13 cases identical ([results](eda-tool-qualification/xezim-0.11.4-oracle-results.json)) |
| `cargo test --locked --manifest-path crates/xezim-web/Cargo.toml` (Linux) | 19 of 19 pass: output and VCD limits, path traversal, disabled host system task, plusargs, FST output, ROM and virtual files |
| WebAssembly build of 0.11.4 (`wasm32-unknown-unknown`, wasm-bindgen 0.2.129, clang 21) | **Fails to compile.** `vendor/xezim-core/src/lib.rs:2609`: `elab_phase` expects `web_time::Instant` but receives `std::time::Instant` (error E0308) |

**Upgrade decision:** 0.11.4 passes native qualification but **must not be
accepted for the browser build** until the `lib.rs:2609` type mismatch in the
vendored core is fixed in HDL Workbench. The image keeps 0.11.3. The wasm32
failure is a finding in HDL Workbench's vendored core (commit `33ad491`); the
one lane that owns core changes should fix it, and the build above should be
re-run to accept the upgrade.

**WebAssembly runtime (existing bundle, built 2026-10-25 from the previously
vendored Xezim).** `apps/ide/scripts/wasm-browser-acceptance.mjs` drove the
Worker harness through the DevTools protocol in Chromium 157.0.8103.39.
[All stages passed](eda-tool-qualification/xezim-wasm-harness-results.json):

| Stage | Observed |
| --- | --- |
| Counter simulation | Completed, `COUNT=4` |
| Project run with ROM, file I/O and NBA ordering | Completed, 699-byte complete VCD with 3 transitions |
| Invalid SystemVerilog | `failed` with one error diagnostic |
| Recovery | A fresh run after the failure completed |
| Invalid C DPI source | `DPI_COMPILATION_FAILED` with the compiler message |
| C and C++ DPI modules | Compiled to WebAssembly and called: `DPI_C=30`, `DPI_CPP=42` |

The IDE unit suite (9 files, 57 tests) also covers Worker timeout, crash
recovery and a fresh Worker afterward, and DPI module limits: host imports are
rejected, non-`int` signatures and linear memory above the cap are rejected,
missing symbols and invalid return values fail explicitly.

**Unsupported in the browser (recorded in `vendor/UPSTREAM.md` and HDL
Workbench `AGENTS.md`):** DPI imports are limited to functions returning SV `int`
with scalar `input int` ports; other prototypes are compile errors. WASM memory,
output and VCD sizes are capped (256 MiB); an overflow is reported as
`RESOURCE_LIMIT` with no partial waveform. There is no native, server or
JavaScript fallback.

## Java and the independent oracle runtime

The `Dockerfile` installs `default-jdk-headless` from the pinned snapshot and
its build-time smoke test runs `java -version` and `javac -version`. The earlier
local image predated that change and had **no Java**, which is why the Am2901
Java oracle once stopped at `javac: not found`. I rebuilt the image from the
current `Dockerfile` (the Ubuntu snapshot service had returned 502/503 earlier
in the day; the retry succeeded):

| Image | ID |
| --- | --- |
| `ai-hw-engineer:eda-acceptance` (base, rebuilt 2026-11-06) | `sha256:dde1a471899caf2b92d0e84907f8e911261b7b0c636c0eba0388b44b0e8b2ce9` |
| `ai-hw-engineer-apple-ii:eda-acceptance` (overlay on that base) | `sha256:b278cd8cff731a56760d34fda753642024b63b6fe472c4e7f2e3eac6e57076c5` |

These supersede the 2026-10-25 digests in the
[qualification report](eda-tool-qualification.md). Docker builds are pinned by
revision and hash but are not bit-for-bit reproducible, so the image ID is
recorded with each run.

- `java`: OpenJDK 25.0.4.1; `check_eda_tools.py` `java javac-and-java` compiles and runs a class.
- Full probe set in the rebuilt base image: **36 of 36 pass** ([results](eda-tool-qualification/results.json)).
- Overlay build and its Icarus smoke tests pass; the 9 Icarus probes pass ([results](eda-tool-qualification/icarus-overlay-results.json)).

## Representative workflows

| Workflow | Image | Result |
| --- | --- | --- |
| Am9080A `scripts/run_all.sh`: lint, six SymbiYosys proofs with covers, 16,842,752 ALU comparisons, 7,808 opcode cases, TST8080 and 8080PRE, UVM (15 scenarios), Yosys synthesis | `ai-hw-engineer` (before the rebuild; same pins) | `Am9080A complete verification PASSED`, exit 0 |
| Am2901 `scripts/run_all.sh`: formal, 98,304 independent Java-oracle cases, manufacturer 1975 microcode (8,925,698 exact checks) | rebuilt `ai-hw-engineer:eda-acceptance` | `Am2901 complete verification PASSED`, exit 0 |

The Am2901 run is the one that needs `javac`; it now passes, closing the
2026-10-25 Java oracle blocker.

## Limits that remain

- The Am9080 flow was not repeated after the rebuild, only the Am2901 flow.
- The image is x86_64 Linux only. Surfer's native GUI and non-listed browsers are unqualified.
- The browser WebAssembly bundle is the 2026-10-25 build, not 0.11.4 (see above).
- Four-state X/Z behavior of Xezim is not covered by the Verilator comparison.
- None of this is Human verified, and no physical-silicon claim follows from tool probes.
