# Intel 80286 Single-Pass Release-Gate Closure — 2026-11-24

This report documents the fixes and verification evidence that closed the
`design/intel_80286` single-pass release gate (`scripts/run_all.sh`) on branch
`design/intel-80286-release-gate` for parent issue `#80`.

## Frozen-Tree Identification

- Tool container: `ai-hw-engineer:latest` (Verilator `5.052`, Yosys `0.69`, SymbiYosys, Yices 2, ABC)
- Release-gate command (executed from repository root):
  ```sh
  sh design/intel_80286/scripts/run_all.sh --work-dir design/intel_80286/work/release_20261124
  ```
- Evidence directory: `design/intel_80286/work/release_20261124` (formal epoch `formal_runs/release.ClGBL2`, `audit.json`)
- Source hashes audited across every task:
  - `design/intel_80286/src/intel_80286.sv`: `5dc923fc3573b17c04e65e4e5072745d79631c89cbbe440400dec41b2eda6c81`
  - `design/intel_80286/formal/intel_80286_props.sv`: `b02d3d3f2c5c92d0bf1a985709a0886674f1b774ba9cc0270deb6e0e607f6b5f`
- Total uninterrupted wall-clock duration: `12,907 s` (`3 h 35 m 07 s`, exit `0`)

## Root Causes Resolved

1. **Connected-core blind cover hang (`intel_80286_cover`).**
   The previous `intel_80286.sby` `cover` task tried to reach all 76 elaborated
   cover cells (54 CPU covers + 22 submodule covers) blindly with depth 64 SMT:
   - Two CPU covers in `formal/intel_80286_props.sv` (`fault_code_o == 2` and
     `fault_code_o == 3`) were permanently unreachable (`fault_code_o <= 2` stop
     site was deleted in `f1b8e4a8`, and every `fault_code_o <= 3` entry path
     was already proven unreachable by k-induction). Replaced with explicit
     invariant `if (rst_n) assert(fault_code_o <= 2'd1);` (proven by induction)
     and removed the two dead covers (`52` reachable CPU covers remain;
     `formal/property_inventory.json` updated to `442` asserts / `1` assume /
     `52` covers in source, elaborating to `449` CPU assertions + `52` CPU
     covers).
   - Four submodule covers inside `intel_80286` are tied off by CPU wiring
     (`.pedc_claim_i(1'b0)`, mutually exclusive claim, unused `start_i &&
     busy_o`), while all 22 component covers pass in their standalone `.sby`
     suites. Only the blind `cover` task now strips submodule `$check` cells;
     `bmc`, `prove`, and witness replay retain all component assertions and
     assumptions (`560` total `$assert`, `6` `$assume`).
   - Splitting the remaining `52` CPU covers into `14` shallow blind covers
     (`cov_shallow_*`, `cover: depth 15`, all reached blindly by step 13) and
     `38` deep multi-cycle instruction/protection covers (`cov_deep_*`) allows
     blind `intel_80286_cover` to complete in `1,100 s`.

2. **Deep core cover witness replay (`intel_80286_cover_witnesses`).**
   `tb/core_cover_witnesses.cpp` generates 11 deterministic primary-input
   sequences from reset (`.smtc` + `.yw`, constraining only the 10 CPU primary
   inputs) covering all 38 `cov_deep_*` targets. Replaying these sequences with
   `yosys-smtbmc -c` stalled (~6.5 s/step due to 11,882 unconstrained
   `$anyseq` variables from `design_prep.il`, plus `-c` does not enforce
   assertions during search). Instead, `scripts/run_core_cover_witnesses.py`
   lowers the frozen `intel_80286_prove/model/design.il` into `model/sim_prep.il`
   (preserving all `560` `$assert`, `6` `$assume`, and `52` `$cover` cells,
   without `-zinit` or `-noinitstate`) and replays each primary-input `.yw`
   trace with `yosys sim -q -assert -r ... -summary ... intel_80286`, verifying
   all `38/38` deep covers and zero assertion/assumption failures in `81 s`.
   `scripts/audit_formal.py` fail-closed validates `.smtc` and `.yw` port
   exclusivity, reset at step 0, lowered model cell counts against `prove`,
   `sim -assert` script/log integrity, summary non-cover zero failures, and
   exact `52/52` union coverage.

3. **Redundant whole-core PDR in default `run_formal.sh`.**
   `intel_80286_pdr.sby` duplicated the full k-induction safety proof already
   established by `intel_80286.sby prove`. `run_formal.sh` now skips
   `intel_80286_pdr.sby` by default (retained behind `--include-pdr`) and
   `audit_formal.py` defaults `require_pdr=False` (retained behind
   `--require-pdr`).

4. **Mutation pattern validator coverage (Priority #8).**
   `scripts/check_mutation_patterns.py` was widened from `9` suites to all `16`
   mutation suites (adding all `7` component suites: access check, cached
   reference, code check, code load, event, segment load, segment), verifying
   all `119` mutation patterns match their targets cleanly once.

## Single-Pass Gate Results (`release_20261124`)

| Stage | Result | Details |
|---|---|---|
| Preflight & pattern check | Pass | `preflight.py` (`442`/`1`/`52`); `check_mutation_patterns.py` (`119` patterns, `16` suites) |
| Script unit tests | Pass | `test_preflight.py` (6), `test_audit_formal.py` (24), `test_build_runner.py` (11), `test_work_paths.py` (3); full `discover` runs 88 tests |
| Strict lint | Pass | `verilator --lint-only -Wall --top-module intel_80286 src/*.sv` (0 warnings) |
| Component formal (12 suites) | Pass | `36/36` tasks (`bmc`, `prove`, `cover`) pass |
| Connected-core `intel_80286_bmc` | Pass | `5,989 s` (`449` CPU asserts, `52` covers) |
| Connected-core `intel_80286_prove` | Pass | `1,014 s` (`449` CPU asserts, `52` covers, k-induction depth 12) |
| Connected-core `intel_80286_cover` | Pass | `1,100 s` (`14/14` `cov_shallow_*` reached blindly by step 13) |
| Deep core cover witnesses | Pass | `81 s` (`38/38` `cov_deep_*` via Yosys `sim -assert`; `52/52` union) |
| Aggregate formal audit (`audit_formal.py`) | Pass | `40/40` current tasks passed, matched source hashes |
| Bus/native/directed sims (`run_bus_owner.sh`, `run_native_bus.sh`, `run_native_core.sh`, `run_sim.sh`) | Pass | Exit 0 |
| Random instruction vectors (`run_vectors.sh`) | Pass | `99,650` cases, `1,715,162` states (Unicorn 2.1.4) |
| Physical Harris-286 captures (`run_hardware.sh`) | Pass | Pinned `SingleStepTests/80286` MOO captures replay exact |
| Gate mutation suites | Pass | `29/29` mutants caught (`undefined` 4, `protection` 4, `protected_event` 6, `protected_string` 15) |
| IBM AT BIOS (`run_software.sh`) | Pass | `196,846` instructions to `F000:0225` ROM checksum plus timer/DMA/page/refresh checks |
| PCE-286 oracle (`run_pce_oracle.sh`) | Pass | `3,019` scenarios: `2,926 PASS`, `93 WAIVED`, `0 MISMATCH` |
| Yosys synthesis (`run_synth.sh`) | Pass | All 13 targets exit 0 with `check -assert` (`intel_80286` `71,624` cells in `744.28 s`; `intel_80286_native_beats` `71,042` cells in `787.24 s`; `intel_80286_native_cpu` `72,285` cells in `764.42 s`) |

## Remaining Open Scope for Issue #80

This closure resolves the single-pass release gate (`run_all.sh`), connected-core
formal cover closure (`52/52`), and 16-suite mutation pattern validation; parent
issue `#80` remains open because full CPU completion items remain:
- Microsoft OS/2 SDK 1.00 `CPGREP.EXE` independent trace and RTL execution
- External DOS/protected-mode system workload execution against Unicorn/PCE traces
- Unexercised protected-mode/ISA combinations, native bus/pin timing details, and 80287 external coprocessor execution beyond the integrated channel
- Physical Harris-286 silicon verification for assumptions `A31`, `A47`, and `A48`
