# Final Design Report: Intel 8255

## 1. Executive summary

The Intel 8255A-compatible digital programming model is implemented as a single-clock synthesizable core. Mode 0 simple I/O, Mode 1 strobed I/O on both groups, Mode 2 bidirectional Port A, Port C handshake/status multiplexing, BSR, hidden interrupt enables, and reset-to-input behavior are complete.

Strict lint passes without warnings or violations. A 2,078-cycle xezim regression passes 2,078 whole-interface and 16,673 field checks using a separately organized state model plus specification-derived Mode 2 protocol checks. Formal BMC, unbounded proof of 61 assertion outputs with later reset unconstrained, and 12/12 causal non-vacuity covers pass. Generic Yosys synthesis reports zero structural problems and 391 cells.

## 2. Design overview

- Module: `intel_8255`
- Version: 1.0
- Validation date: 2026-08-26
- Language: SystemVerilog IEEE 1800-2017
- CPU interface: sampled active-low `cs_n`, `rd_n`, and `wr_n` with two address bits
- Peripheral interface: separate input, output, and per-bit output-enable vectors for Ports A, B, and C
- Reset: active-high synchronous reset matching the historical RESET polarity

The original NMOS 8255 has no clock. This implementation intentionally represents it as a synchronous functional core. Bus operations and external handshake transitions are sampled on `clk`; read values and peripheral drive/status values are combinational.

## 3. Reproducible toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Verible | `v0.0-4148-g1ea007ec` |
| xezim | 0.10.3, revision `66efe06` |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | revision `b1a1e98c` |
| Z3 | 4.8.12 |

All validation commands ran in image ID:

```text
sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147
```

## 4. Verification results

### 4.1 Lint

| Check | Command summary | Result |
|---|---|---|
| RTL | `verilator --lint-only -Wall` | PASS, zero warnings |
| RTL + timed testbench | `verilator --lint-only -Wall --timing` | PASS, zero warnings |
| Authored RTL/TB/formal sources | `verible-verilog-lint` | PASS, zero violations |

### 4.2 Simulation

The self-checking bench maintains a software-style state model separate from the DUT implementation and checks all externally observable vectors after each cycle. Because the model necessarily shares architectural definitions with the DUT, specification-derived black-box checks separately enforce Mode 2 Port A release/drive behavior from `ACK_A_n`.

```text
Pseudorandom seed: 0x1ace, operations: 1024
8255 simulation result: 2078 cycles, 2078 interface checks, 16673 field checks
CPU reads: 195, CPU writes: 460, mode-set writes: 133
Mode 0 directions: 16, BSR actions: 16, Mode 1 scenarios: 4, Mode 2 scenarios: 3
Handshake falling edges: 87
Failures: 0
TEST PASSED
```

The directed portion covers reset, all 16 Mode 0 direction combinations, every BSR bit/action combination, all four Group A/Group B Mode 1 direction scenarios, Mode 2 input/output overlap, ACK-controlled Mode 2 bus ownership, INTE mapping, invalid bus controls, control-address reads, and mode reconfiguration. A fixed-seed 1,024-operation regression then stresses legal mode words, BSR commands, reads, writes, pin changes, handshakes, idles, and invalid strobes.

Result: **PASS**.

### 4.3 Formal verification

The full property module checks combinational read/drive equivalence and sequential reset, mode-set, BSR, data-latch, IBF, OBF, INTE, interrupt, and sampled-edge transitions. Reset is assumed only in the initial cycle; later reset, CPU strobes, and all peripheral data/handshake inputs remain unconstrained, including invalid simultaneous read/write and reset/write conflicts.

| Task | Engine | Result |
|---|---|---|
| BMC | ABC `bmc3`, 12 frames | PASS, no assertion output reached |
| Unbounded proof | ABC `pdr` | PASS, 61/61 assertion outputs proved; convergence at frame 2 |
| Cover | synthesized SMT with Z3, depth 20 | PASS, 12/12 covers reached; maximum witness depth 5 |

The cover task uses a smaller reachability-only property module connected to the same DUT. Its causal covers include output write→ACK→INTR sequences, Mode 2 ACK-controlled drive/release, BSR and reconfiguration effects, read/capture and write/ACK conflicts, and later-reset priority.

### 4.4 Synthesis

Yosys generic synthesis completes with no inferred latches, no memories, no remaining processes, and zero `check` problems.

```text
Number of wires:                190
Number of wire bits:            550
Number of public wires:          45
Number of public wire bits:     173
Number of ports:                 18
Number of port bits:             96
Number of memories:               0
Number of processes:              0
Number of cells:                391
  $_AND_                        116
  $_DFF_P_                        5
  $_MUX_                        118
  $_NOT_                         38
  $_OR_                          59
  $_SDFFE_PP0P_                  46
  $_SDFFE_PP1P_                   5
  $_SDFF_PP0_                     2
  $_XOR_                          2
```

The netlist contains 58 sequential primitives. Generic cell counts are not directly comparable with the historical NMOS transistor implementation.

## 5. Semantic review remediation

The initial semantic review returned `NOT READY` because Mode 2 Port A output enable incorrectly followed pending-data `OBF_A_n`. The implementation, simulation reference, directed black-box checks, specification, and formal oracle now make Port A drive only while peripheral `ACK_A_n` is low; `OBF_A_n` remains the pending-data indication. Formal reset assumptions and non-vacuity coverage were also strengthened during remediation. Final semantic re-review returned `READY` with no blocking, major, or minor findings.

## 6. Reproduction

From the repository root on a Docker host, run the exact validated image ID:

```bash
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147 \
  sh design/intel_8255/scripts/run_all.sh
```

Individual entry points are `run_lint.sh`, `run_sim.sh`, `run_formal.sh`, `run_synth.sh`, and `run_coverage.sh`.

## 7. Known issues and scope limits

- No known functional RTL issue remains within the written specification after Mode 2 remediation.
- The extra `clk` and synchronous sampling semantics are not pin-compatible with the asynchronous historical device.
- Integration must synchronize genuinely asynchronous peripheral handshake inputs; the core contains no metastability hardening.
- Original pulse widths, propagation delays, electrical levels, drive currents, package pins, and process behavior are outside scope.
- A CPU control-address read deliberately leaves `data_oe` low; simultaneous active `rd_n` and `wr_n` is ignored.
- Code-coverage percentages are not claimed; scenario counters and formal coverage provide the durable evidence.

## 8. Sign-off

| Criterion | Status |
|---|---|
| Mode 0, Mode 1, Mode 2, and BSR implemented | PASS |
| Reset, INTE, IBF/OBF, and interrupt behavior checked | PASS |
| ACK-controlled Mode 2 Port A ownership | PASS |
| All directed functional scenarios complete | PASS |
| Reference-model and specification-derived deterministic regression | PASS |
| Verilator and Verible lint | PASS |
| BMC and unbounded proof | PASS |
| Formal causal/non-vacuity cover | PASS, 12/12 |
| Generic synthesis and structural checks | PASS |
| Specification, plans, scripts, and reports complete | PASS |
| Final semantic re-review | READY, no findings |

**Sign-off status: READY.**
