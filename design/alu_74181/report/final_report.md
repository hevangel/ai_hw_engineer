# Final Design Report: alu_74181

## 1. Executive Summary

The SN74LS181-compatible 4-bit ALU is implemented and signed off for active-HIGH data with active-LOW carry/lookahead pins. All 16,384 functional input assignments pass a normalized datasheet table oracle implemented separately from the structural RTL. A UVM 1800.2-2017 environment passes all 64 selector/mode/carry transactions. Lint, formal BMC/proof/cover, and generic synthesis all pass in the source-revision-pinned `ai-hw-engineer:latest` container.

## 2. Design Overview

- Module: `alu_74181`
- Version: 1.0
- Date: 2026-08-24
- Implementation: purely combinational SystemVerilog IEEE 1800-2017
- Data convention: active HIGH
- External carry convention: `Cn=0` means carry present; `Cn+4=0` means carry out
- Outputs: `F[3:0]`, `Cn+4`, `A=B`, active-LOW group `P` and `G`

## 3. Reproducible Toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | revision `b1a1e98c` |
| Z3 | 4.8.12 |
| xezim | 0.10.3, revision `66efe06` |
| Surfer | 0.7.0, revision `f8cafda` |
| Verible | `v0.0-4148-g1ea007ec` |
| Rustup | 1.29.0, versioned `rustup-init` archive |
| Rust | 1.94.0 |
| UVM | Accellera IEEE 1800.2-2017 checkout `65a3ded3` |

All commands below were run with the repository mounted at `/workspace` in `ai-hw-engineer:latest`. The final rebuilt and signed-off image ID is `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`.

The Dockerfile pins the Ubuntu base digest, Ubuntu package snapshot timestamp, tool source revisions, Rust version, the rustup 1.29.0 bootstrap executable checksum, Verible archive checksum, and UVM gitlink. Because the pinned minimal Ubuntu base does not yet contain a CA bundle, only APT TLS peer verification is disabled during the initial snapshot transaction that installs `ca-certificates`; APT still verifies signed repository metadata and package hashes. All subsequent downloads use normal verified HTTPS plus the documented revision or checksum pins. A recursive submodule checkout is required before building.

## 4. Verification Results

### 4.1 Lint

| Check | Command summary | Result |
|---|---|---|
| RTL | `verilator --lint-only -Wall` | PASS, zero warnings |
| RTL + exhaustive TB | `verilator --lint-only -Wall --timing` | PASS, zero warnings |
| RTL/formal/TB | `verible-verilog-lint` | PASS, zero violations |
| UVM package | Verible from UVM include directory | PASS, zero violations |

### 4.2 Exhaustive Simulation

xezim 0.10.3 enumerated:

```text
16 A × 16 B × 16 S × 2 M × 2 Cn = 16,384 vectors
```

Each vector checks `F`, `Cn+4`, `A=B`, `P_bar`, and `G_bar`:

```text
74181 exhaustive result: 16384 vectors, 81920 field checks,
Failures: 0 vectors, 0 fields
TEST PASSED
```

The active-LOW function table was also checked against the negative-logic dual of the active-HIGH oracle for all 4,096 logic cases and 8,192 arithmetic/carry cases.

Result: **PASS**.

### 4.3 UVM Simulation

`alu_74181_all_modes_test` uses an IEEE 1800.2-2017 sequence, sequencer, driver, monitor, analysis port, scoreboard, environment, and test.

```text
Checked 64 selector/mode/carry transactions
UVM_ERROR : 0
UVM_FATAL : 0
```

Result: **PASS**. The reference library emits 23 false component-name warnings under the required `UVM_NO_DPI` mode because its name-check regex depends on DPI; all authored component names are valid and the warnings do not affect checking.

### 4.4 Formal Verification

The harness has no functional assumptions. A symbolic sampling stage supplies a state boundary for BMC while leaving all 14 DUT input bits unconstrained, including at frame zero.

| Task | Engine | Depth | Result |
|---|---|---:|---|
| BMC | `abc bmc3` | 1 | PASS; no output asserted, 0.05 s |
| Unbounded proof | `abc pdr` | convergence | PASS; property proved, 0.04 s |
| Cover | `smtbmc z3` | 1 | PASS; 10/10 statements reached |

The packed assertion checks every DUT output against the shared normalized datasheet table as separately coded in the formal harness. This is structurally independent from DUT equations, but a common specification-transcription error remains possible and was addressed by manual datasheet review plus exhaustive simulation.

## 5. Synthesis Results

Yosys 0.46 completed generic synthesis, reported zero `check` problems, and inferred no latches or flip-flops.

```text
Number of wires:                 68
Number of wire bits:             96
Number of public wires:          14
Number of public wire bits:      35
Number of ports:                 10
Number of port bits:             22
Number of memories:               0
Number of processes:              0
Number of cells:                 82
  $_AND_                         42
  $_NOT_                          9
  $_OR_                          19
  $_XOR_                         12
```

The 82 Yosys primitives are not directly comparable to the datasheet's approximately 75 TTL-equivalent gates because the counting libraries and gate decomposition differ.

## 6. Reproduction

From the repository root on a Docker host:

```bash
git submodule update --init --recursive
docker build --progress=plain -t ai-hw-engineer:latest .
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  ai-hw-engineer:latest sh design/alu_74181/scripts/run_all.sh
```

Individual entry points are `run_lint.sh`, `run_sim.sh`, `run_formal.sh`, `run_synth.sh`, and `run_coverage.sh`.

## 7. Known Issues and Scope Limits

- No known functional RTL issues.
- Analog voltage levels, propagation delays, fan-out, open-collector electrical behavior, and package characteristics are documented from the datasheet but are outside synthesizable RTL scope.
- UVM no-DPI name-check warnings are a reference-library limitation described above, not DUT warnings.

## 8. Sign-off

| Criterion | Status |
|---|---|
| RTL matches all logic/arithmetic table entries | PASS |
| Complete binary input space simulated | PASS |
| Carry, group P/G, and comparator outputs checked | PASS |
| UVM all-mode smoke test | PASS |
| Verilator and Verible lint | PASS |
| BMC, unbounded proof, and cover | PASS |
| Generic synthesis and structural checks | PASS |
| Documentation and reproducible scripts | PASS |

**Sign-off status: READY FOR REVIEW.**
