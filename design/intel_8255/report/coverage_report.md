# Intel 8255 Coverage Report

**Validation date:** 2026-08-26
**Container image:** `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`

## Simulation coverage

The deterministic xezim regression combines directed scenarios with 1,024 fixed-seed (`16'h1ace`) pseudorandom operations. After every sampled cycle, a separately organized blocking reference model checks CPU read data, CPU read enable, all three peripheral output values, and all three output-enable vectors. Specification-derived checks separately enforce Mode 2 bus ownership from `ACK_A_n` so the protocol is not accepted solely through comparison with the state model.

```text
Pseudorandom seed: 0x1ace, operations: 1024
8255 simulation result: 2078 cycles, 2078 interface checks, 16673 field checks
CPU reads: 195, CPU writes: 460, mode-set writes: 133
Mode 0 directions: 16, BSR actions: 16, Mode 1 scenarios: 4, Mode 2 scenarios: 3
Handshake falling edges: 87
Failures: 0
TEST PASSED
```

### Directed scenario closure

| Feature | Exercised | Result |
|---|---:|---|
| Reset to Mode 0 all-input state | Yes | PASS |
| Mode 0 PA/PB/PC-upper/PC-lower directions | 16/16 combinations | PASS |
| Mode 0 input and output data paths | All ports | PASS |
| BSR bit selections and actions | 8 bits × set/reset = 16/16 | PASS |
| Group A Mode 1 input | 1/1 | PASS |
| Group A Mode 1 output | 1/1 | PASS |
| Group B Mode 1 input | 1/1 | PASS |
| Group B Mode 1 output | 1/1 | PASS |
| Mode 2 output ownership from ACK | ACK high/released and ACK low/driven | PASS |
| Mode 2 input | 1/1 | PASS |
| Mode 2 input/output pending overlap with bus released | 1/1 | PASS |
| INTE programming through PC2/PC4/PC6 BSR | All applicable mappings | PASS |
| Port C status/GPIO ownership | All mode classes | PASS |
| Unsupported control read | Yes | PASS |
| Simultaneous active read/write strobes | Yes | PASS, no mutation/read drive |
| Reconfiguration clearing | Directed and random | PASS |

## Formal coverage

The safety harness proves 61 assertion outputs. Reset is required only in the initial formal cycle and remains unconstrained afterward, allowing arbitrary later reset assertions and reset-priority conflicts. A separate lightweight reachability harness avoids burdening cover solving with proof-only transition history while exercising the same instantiated DUT.

| Task | Engine | Bound/convergence | Result |
|---|---|---:|---|
| BMC | ABC `bmc3` | 12 frames | PASS |
| Unbounded proof | ABC `pdr` | converged at frame 2 | PASS, 61/61 assertion outputs |
| Cover | `smtbmc --syn --nopresat z3` | depth 20 configured; maximum witness depth 5 | PASS, 12/12 covers |

The 12 reached covers demonstrate: all-output Mode 0; Group A Mode 1 input; causal Group A output write→ACK→INTR; Group B Mode 1 input; causal Group B output write→ACK→INTR; Mode 2 ACK-low drive; simultaneous Mode 2 input/output pending with ACK high and Port A released; causal PC7 BSR effect; reconfiguration to `8'h9b`; read/capture coincidence; write/ACK coincidence; and later-reset priority during a write conflict.

## Coverage limitations

- No line, branch, or toggle percentage is claimed because the pinned xezim flow does not emit a repository-standard code-coverage database.
- The deterministic random sequence is one fixed seed; repeatability is prioritized over statistical seed breadth.
- The reference state model shares architectural definitions with the DUT and is therefore not claimed to be fully independent; directed black-box protocol checks and formal properties provide complementary oracles.
- Analog timing, metastability, TTL electrical behavior, and package-level behavior are outside RTL scope.

Functional scenario counters, reference-model comparisons, specification-derived protocol checks, unbounded safety proof, formal reachability, and synthesis structural checks are the verification evidence for this design.
