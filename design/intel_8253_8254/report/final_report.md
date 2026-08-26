# Final Design Report: Intel 8253/8254

## 1. Executive summary

The Intel 8253 and 8254 digital programming models are implemented in one synthesizable SystemVerilog module. The `IS_8254` parameter selects 8253 shared read/write byte phasing with ignored read-back commands or 8254 independent phasing with count/status read-back. The common implementation includes all three counters, Modes 0–5 and aliases, binary and packed-BCD counting, GATE behavior, count/status latches, and null-count reporting.

Strict lint, deterministic dual-variant simulation, bounded and unbounded formal safety verification, real-DUT formal reachability, functional scenario coverage, and generic synthesis all pass. Simulation completes 21,462 cycles and 511 checks with zero failures. Both variants pass depth-16 BMC and unbounded PDR for the authored safety obligations and reach all seven cover points. Yosys reports zero structural problems for both elaborations.

## 2. Design overview

- Module: `intel_8253_8254`
- Architectural parameter: `parameter bit IS_8254 = 1'b1`
- Version: 1.0
- Validation date: 2026-08-26
- Language: SystemVerilog IEEE 1800-2017
- CPU interface: sampled active-low `cs_n`, `rd_n`, and `wr_n` with two address bits
- Timer interface: three sampled counter clocks, three GATE inputs, and three OUT signals
- Reset: active-low synchronous integration reset

The historical parts have independent asynchronous timer clocks and no device-wide reset pin. This repository intentionally uses a single integration clock. Falling counter-clock and rising GATE events are recognized from sampled levels, making the state transition system synthesizable and formally tractable while retaining independent timer-event inputs.

## 3. Reproducible toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Verible | `v0.0-4148-g1ea007ec` |
| xezim | 0.10.3, revision `66efe06` |
| Yosys | 0.46, revision `e97731b9d` |
| SymbiYosys | v0.68 |
| Z3 | 4.8.12 |

All validation commands ran in image ID:

```text
sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147
```

## 4. Verification results

### 4.1 Lint

| Check | Command summary | Result |
|---|---|---|
| 8253 RTL elaboration | `verilator --lint-only -Wall -GIS_8254=0` | PASS, zero warnings |
| 8254 RTL elaboration | `verilator --lint-only -Wall -GIS_8254=1` | PASS, zero warnings |
| RTL + timed testbench | `verilator --lint-only -Wall --timing` | PASS, zero warnings |
| Authored RTL/TB/formal sources | `verible-verilog-lint` | PASS, zero violations |

### 4.2 Simulation and functional coverage

The procedural self-checking testbench instantiates both variants and uses specification-derived expectations for CPU programming, output timing, latching, read-back, GATE handling, BCD behavior, and variant byte-phase differences.

```text
8253/8254 simulation result: 21462 cycles, 511 checks
CPU reads: 51, CPU writes: 349, counter pulses: 10260
Mode/channel scenarios: 18, aliases: 2, GATE: 5
Latch checks: 10, read-back checks: 9, BCD checks: 15, phase checks: 2
Stress operations: 64
Failures: 0
TEST PASSED
```

The directed regression includes all six modes on all three counters, alias encodings, all read/write formats, counter isolation, pause/restart and trigger/retrigger timelines, pre-arm trigger rejection, Mode 4 recovery while GATE is low, binary and BCD encoded-zero cases, full 5,000/5,000-clock BCD Mode 3 phases, stable count latches, complete 8254 read-back forms, ignored 8253 read-back, variant byte phases, and invalid bus cycles.

Result: **PASS**.

### 4.3 Formal safety verification

Dedicated wrappers elaborate both parameter values. ABC `bmc3` passes to depth 16 and ABC PDR converges for each variant. The proved obligations are:

- legal CPU-bus output-enable and zero undriven data;
- reset and post-control-write OUT states;
- latched 8254 OUT and programmed status metadata excluding null-count bit 6;
- packed-BCD digit preservation for subtraction by one, two, and three plus known zero/borrow vectors;
- Mode 1/5 pending-trigger arm validity;
- Mode 4 next-clock terminal-low recovery when no reload/write supersedes it; and
- Mode 3 encoded-zero decrement (`9998` BCD or `fffe` binary) with OUT preservation.

| Variant | BMC | Unbounded proof |
|---|---|---|
| 8253 | PASS, depth 16 | PASS, PDR converged |
| 8254 | PASS, depth 16 | PASS, PDR converged |

Generated backend output counts are not used as a proxy for specification closure. Complete mode periods, full BCD-zero phases, isolation, latch and byte-phase timelines, complete read-back forms, and active retrigger timelines are supported by simulation rather than claimed as formal proofs.

### 4.4 Formal reachability

Seven non-vacuity points are retained for each variant. The 8253 solve is split into four parameter-selected depth-10 tasks after the aggregate solver reached six points but failed to complete within the tool timeout. Every split task still instantiates the real RTL and preserves the original predicates.

| Variant/task | Points | Latest witness | Result |
|---|---:|---:|---|
| 8253 `cover_8253_mode0` | 2/2 | step 7 | PASS |
| 8253 `cover_8253_mode1` | 1/1 | step 6 | PASS |
| 8253 `cover_8253_mode2` | 1/1 | step 8 | PASS |
| 8253 `cover_8253_bus_reset_readback` | 3/3 | step 6 | PASS |
| 8254 `cover_8254` | 7/7 | step 15 | PASS |

The points cover Mode 0 initial low and later high, triggered Mode 1 low, a Mode 2 low pulse, count-write followed by a driven same-counter read, later reset recovery, and variant-specific read-back activity. They demonstrate reachability, not exhaustive functional proof.

### 4.5 Synthesis

Yosys generic synthesis completes for both parameter values with no inferred memories, no remaining processes, and zero `check` problems.

| Metric | 8253 (`IS_8254=0`) | 8254 (`IS_8254=1`) |
|---|---:|---:|
| Wires | 1,638 | 1,753 |
| Wire bits | 5,610 | 5,958 |
| Cells | 3,710 | 4,077 |
| Memories | 0 | 0 |
| Processes | 0 | 0 |
| Structural check problems | 0 | 0 |

The larger 8254 elaboration retains read-back/status state and independent byte sequencing. Generic cell counts are implementation evidence and are not comparable with historical NMOS/HMOS transistor counts.

## 5. Semantic-review remediation

The initial semantic review at `semantic-review/2026-08-26-092945-pr-local.md` reported three HIGH and two MEDIUM findings. All five were addressed:

| Finding | Resolution and evidence |
|---|---|
| Packed-BCD Mode 3 used binary subtraction | Added BCD-preserving repeated decrement for subtract-by-one/two/three, encoded-zero handling, inline assertions, boundary tests, and full 5,000/5,000-clock BCD phases |
| Formal sign-off exceeded authored properties | Added targeted defect assertions and rewrote plans/reports around exact semantic obligations rather than backend output count |
| Simulation/report closure exceeded implemented oracles | Expanded the regression to 511 checks and narrowed proof-versus-simulation claims to the actual evidence |
| Mode 4 recovery was GATE-qualified | Recovery now precedes GATE-qualified decrement; directed and formal checks cover low-GATE recovery |
| Mode 1/5 retained pre-arm triggers | Trigger capture now requires a valid reload and count writes clear stale pending triggers; directed and formal checks cover ordering |

The post-remediation semantic review at `semantic-review/2026-08-26-121057-pr-local.md` gives an **APPROVED / READY** verdict and confirms all five original findings are resolved. Its sole LOW, nonblocking observation concerned coverage-attribution wording; the test plan and coverage report now describe the fixed-seed loop and the aggregate ten-check bucket precisely.

## 6. Reproduction

From the repository root on a Docker host, run the exact validated image ID:

```powershell
docker run --rm -v "${PWD}:/workspace" -w /workspace sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147 sh design/intel_8253_8254/scripts/run_all.sh
```

Individual entry points are `run_lint.sh`, `run_sim.sh`, `run_formal.sh`, `run_synth.sh`, and `run_coverage.sh`. `run_formal.sh` accepts aggregate groups, the compatibility `cover_8253` group, or an exact configured task such as `cover_8253_mode2`.

## 7. Known limits

- The integration clock and reset are not historical package pins, and sampled event timing is not pin-compatible with the asynchronous parts.
- Integration must synchronize genuinely asynchronous counter-clock and GATE inputs; the core contains no metastability hardening.
- Inputs must remain stable long enough for sampled edge detection.
- Original propagation delays, setup/hold requirements, maximum clock grades, electrical levels, drive current, package behavior, and undocumented silicon behavior are outside scope.
- Modes 2 and 3 require compatible programmed counts of at least 2; BCD inputs require decimal nibbles.
- No code-coverage percentage is claimed; functional scenario counts and formal reachability are the durable coverage evidence.
- Formal proves the listed authored obligations, not every behavior in the specification.

## 8. Sign-off

| Criterion | Status |
|---|---|
| One shared `intel_8253_8254` module | PASS |
| `IS_8254` selects both architectural variants | PASS |
| Three counters, all six modes, aliases, and GATE behavior | PASS |
| Binary and packed-BCD counting | PASS |
| Count latches and 8254 status/read-back | PASS |
| 8253 shared and 8254 independent byte phases | PASS |
| Deterministic dual-variant simulation | PASS, 511 checks |
| Verilator and Verible lint | PASS |
| Depth-16 BMC and unbounded PDR | PASS for both variants |
| Formal causal/non-vacuity cover | PASS, 7/7 semantic points per variant |
| Generic synthesis and structural checks | PASS for both variants |
| Specification, plans, scripts, README, and reports complete | PASS |

**Sign-off status: READY.**
