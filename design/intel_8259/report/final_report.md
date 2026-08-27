# Final Design Report: Intel 8259A

## 1. Executive summary

The Intel 8259A-compatible Programmable Interrupt Controller is implemented as a
single-clock synthesizable core. Initialization (ICW1-ICW4), operation commands
(OCW1-OCW3), edge/level request sensing, the IRR/ISR/IMR registers, a rotating
priority resolver, the CPU acknowledge sequence in both MCS-86/88 and MCS-80/85
modes, all end-of-interrupt variants, automatic EOI, special fully nested mode,
special mask mode, polled mode, register readback, and cascade signaling are
complete.

Strict lint passes without warnings or violations. A 5,816-cycle xezim
regression passes 5,816 whole-interface and 40,763 field checks using a
cycle-accurate reference model plus specification-derived protocol checks.
Formal BMC, unbounded proof of 31 assertion outputs with later reset
unconstrained, and 8/8 non-vacuity covers pass. Generic Yosys synthesis reports
zero structural problems and 1,038 cells.

## 2. Design overview

- Module: `intel_8259`
- Version: 1.0
- Validation date: 2026-08-26
- Language: SystemVerilog IEEE 1800-2017
- CPU interface: sampled active-low `cs_n`, `rd_n`, `wr_n`, one address bit `a0`
- Request interface: eight `ir` inputs, `int_o` request, `inta_n` acknowledge
- Cascade interface: `cas_i`/`cas_o`/`cas_oe` bus and the `sp_n_i`/`en_n_o`
  shared program/enable pin
- Reset: active-low synchronous `rst_n`

The original NMOS 8259A is asynchronous and has neither a clock nor a reset pin;
it is brought to a defined state only by the ICW1 sequence. This implementation
represents it as a synchronous functional core: bus operations, request lines,
and the acknowledge handshake are sampled on `clk`, while read data, the
vector/opcode/address output, the interrupt output, and the cascade/buffer
outputs are combinational. A synchronous `rst_n` establishes a defined
un-initialized state.

## 3. Reproducible toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Verible | `v0.0-4148-g1ea007ec` |
| xezim | 0.10.3, revision `66efe06` |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | v0.68 |
| Z3 | image default |

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

The self-checking bench maintains a cycle-accurate reference model separate from
the DUT implementation and checks the entire observable interface after each
cycle. Because the model necessarily shares programming-model definitions with
the DUT, specification-derived black-box checks separately enforce the vector
formula, priority nesting, EOI clearing, the poll word, and cascade signaling.

```text
Pseudorandom seed: 0x8259, operations: 2048
8259 simulation result: 5816 cycles, 5816 interface checks, 40763 field checks
CPU reads: 263, CPU writes: 1780, init sequences: 276
INTA sequences: 13, EOI commands: 216, poll reads: 1, OCW3 writes: 250
IR rising edges: 138
Failures: 0
TEST PASSED
```

The directed portion covers reset, 8086 single-mode initialization, the vector
formula, fully nested priority with preemption, non-specific/specific/rotate EOI
and set-priority, masking and IMR readback, polled mode, level-triggered
re-request, automatic EOI, special mask mode, the MCS-80/85 `CALL` sequence,
cascade master and slave operation, buffered mode, and reinitialization. A
fixed-seed 2,048-operation regression then stresses random initialization,
command, request, read, and acknowledge activity.

Result: **PASS**.

### 4.3 Formal verification

The property module checks combinational output equivalence and structural
safety, and proves reset, initialization, mask-update, and specific-EOI
transitions. Reset is assumed only in the initial cycle; later reset, CPU
strobes, and all request/acknowledge/cascade inputs remain unconstrained.

| Task | Engine | Result |
|---|---|---|
| BMC | ABC `bmc3`, 20 frames | PASS, no assertion output reached |
| Unbounded proof | ABC `pdr` | PASS, 31/31 assertion outputs proved; converged by frame 5 |
| Cover | `smtbmc --syn --nopresat --unroll z3`, depth 30 | PASS, 8/8 covers reached; maximum witness step 26 |

The cover task uses a scripted-stimulus harness connected to the same DUT. The
AIG-based ABC engine used for BMC and proof converges in under a second, but SBY
does not support cover mode with ABC, and the only available SMT solver (Z3)
does not scale on this circuit's default cover encoding. Enabling `--unroll` and
pinning the bus stimulus to a deterministic trace yields fast, deterministic
non-vacuity results; unconstrained random reachability is provided by the
simulation regression.

### 4.4 Synthesis

Yosys generic synthesis completes with no inferred latches, no memories, no
remaining processes, and zero `check` problems.

```text
Number of wires:                455
Number of wire bits:           1705
Number of public wires:          90
Number of public wire bits:     321
Number of ports:                 18
Number of port bits:             45
Number of memories:               0
Number of processes:              0
Number of cells:               1038
  $_AND_                        245
  $_DFF_P_                       15
  $_MUX_                        394
  $_NOT_                        138
  $_OR_                         152
  $_SDFFE_PN0P_                  29
  $_SDFFE_PN1P_                   8
  $_SDFFE_PP0P_                   7
  $_SDFF_PP0_                    16
  $_SDFF_PP1_                     3
  $_XOR_                         31
```

The netlist contains 78 sequential primitives. Generic cell counts are not
directly comparable with the historical NMOS transistor implementation.

## 5. Reproduction

From the repository root on a Docker host, run the validated image ID:

```bash
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147 \
  sh design/intel_8259/scripts/run_all.sh
```

Individual entry points are `run_lint.sh`, `run_sim.sh`, `run_formal.sh`,
`run_synth.sh`, and `run_coverage.sh`.

## 6. Known issues and scope limits

- No known functional RTL issue remains within the written specification.
- The added `clk` and `rst_n` and the synchronous sampling semantics are not
  pin-compatible with the asynchronous historical device, which has neither pin.
- Integration must synchronize genuinely asynchronous request and acknowledge
  inputs; the core contains no metastability hardening.
- Cascade behavior is modeled at the single-device signaling level (master
  cascade drive, slave address decode, buffered `EN_n`); full multi-chip system
  timing is not modeled.
- Original pulse widths, propagation delays, electrical levels, drive currents,
  package pins, and process behavior are outside scope.
- Formal cover uses a scripted, constrained environment due to a solver
  performance limitation; see the coverage report.
- Code-coverage percentages are not claimed; scenario counters and formal
  coverage provide the durable evidence.

## 7. Sign-off

| Criterion | Status |
|---|---|
| ICW1-ICW4 initialization and OCW1-OCW3 operation implemented | PASS |
| Edge/level sensing, IRR/ISR/IMR, and rotating priority | PASS |
| MCS-86/88 and MCS-80/85 acknowledge sequences | PASS |
| EOI variants, automatic EOI, special mask, poll, SFNM | PASS |
| Cascade signaling and buffered mode | PASS |
| All directed functional scenarios complete | PASS |
| Reference-model and specification-derived deterministic regression | PASS |
| Verilator and Verible lint | PASS |
| BMC and unbounded proof | PASS |
| Formal non-vacuity cover | PASS, 8/8 |
| Generic synthesis and structural checks | PASS |
| Specification, plans, scripts, and reports complete | PASS |

**Sign-off status: READY.**
