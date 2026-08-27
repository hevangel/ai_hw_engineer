# Intel 8259A Coverage Report

**Validation date:** 2026-08-26
**Container image:** `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`

## Simulation coverage

The deterministic xezim regression combines directed scenarios with 2,048
fixed-seed (`16'h8259`) pseudorandom operations. After every sampled cycle, a
separately organized cycle-accurate reference model checks the entire output
interface: CPU read data and read enable, the interrupt output, the cascade
value and enable, and the buffer-enable value and enable. Specification-derived
checks separately enforce the vector formula, priority nesting, EOI clearing,
the poll word, and cascade signaling.

```text
Pseudorandom seed: 0x8259, operations: 2048
8259 simulation result: 5816 cycles, 5816 interface checks, 40763 field checks
CPU reads: 263, CPU writes: 1780, init sequences: 276
INTA sequences: 13, EOI commands: 216, poll reads: 1, OCW3 writes: 250
IR rising edges: 138
Failures: 0
TEST PASSED
```

### Directed scenario closure

| Feature | Exercised | Result |
|---|---:|---|
| Reset to un-initialized, buses released | Yes | PASS |
| 8086 single-mode init and edge interrupt | Yes | PASS |
| Interrupt vector formula `{ICW2[7:3], level}` | Yes | PASS |
| Fully nested priority (block lower, preempt with higher) | Yes | PASS |
| Non-specific EOI | Yes | PASS |
| Rotate-on-non-specific EOI (priority reorder) | Yes | PASS |
| Specific EOI | Yes | PASS |
| Set-priority (OCW2) | Yes (directed + random) | PASS |
| Interrupt masking and IMR readback | Yes | PASS |
| Polled mode and poll acknowledge | Yes | PASS |
| Level-triggered re-request | Yes | PASS |
| Automatic EOI | Yes | PASS |
| Special mask mode | Yes | PASS |
| MCS-80/85 `CALL` opcode and address bytes | Yes | PASS |
| Cascade master cascade-address drive and bus release | Yes | PASS |
| Cascade slave engagement only on matching address | Yes | PASS |
| Buffered-mode `EN_n` output | Yes | PASS |
| Reinitialization clearing | Yes | PASS |

## Formal coverage

The property harness proves 31 assertion outputs. Reset is required only in the
initial formal cycle and remains unconstrained afterward, allowing arbitrary
later reset assertion and reset-priority conflicts. A scripted-stimulus
reachability harness demonstrates non-vacuity of the safety proofs.

| Task | Engine | Bound/convergence | Result |
|---|---|---:|---|
| BMC | ABC `bmc3` | 20 frames | PASS |
| Unbounded proof | ABC `pdr` | converged by frame 5 | PASS, 31/31 assertion outputs |
| Cover | `smtbmc --syn --nopresat --unroll z3` | depth 30 configured; maximum witness step 26 | PASS, 8/8 covers |

The eight reached covers demonstrate: the device reaches the initialized state;
an interrupt is requested to the CPU; the MCS-86/88 vector byte is driven on the
second acknowledge pulse; a master drives the cascade address for a slave line;
a CPU register read drives the bus; priority is rotated away from the reset
order; rotate-in-automatic-EOI mode is active; and special mask mode enables an
interrupt while a level is in service.

## Coverage limitations

- No line, branch, or toggle percentage is claimed because the pinned xezim flow
  does not emit a repository-standard code-coverage database.
- The deterministic random sequence uses one fixed seed; repeatability is
  prioritized over statistical seed breadth.
- The reference model shares programming-model definitions with the DUT and is
  therefore not claimed to be fully independent; directed black-box protocol
  checks and formal properties provide complementary oracles.
- Formal cover uses a scripted, constrained environment because the only
  available SMT solver (Z3) does not scale on this circuit's cover encoding
  without the `--unroll` option and pinned stimulus. Unconstrained reachability
  across random inputs is provided by the simulation regression.
- Analog timing, metastability, NMOS/TTL electrical behavior, and package-level
  behavior are outside RTL scope.

Functional scenario counters, reference-model comparisons, specification-derived
protocol checks, unbounded safety proof, formal reachability, and synthesis
structural checks are the verification evidence for this design.
