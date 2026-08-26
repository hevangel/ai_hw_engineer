# Test Plan: Intel 8255

## Overview

Verification uses a deterministic, self-checking SystemVerilog testbench. A separately organized software-style reference state is maintained and compared after each directed or pseudorandom operation. Because that model necessarily shares mode definitions with the DUT, specification-derived black-box checks separately enforce handshake phases, especially Mode 2 `ACK_A_n` bus ownership. The testbench checks CPU read data, peripheral outputs, per-bit output enables, buffer-full signals, active-low output-buffer-full signals, and interrupts as exposed through Port C.

## Verification goals

- Prove reset produces Mode 0 with all ports released as inputs.
- Check all Mode 0 direction combinations and output-latch persistence.
- Check all eight BSR bit selections for set and reset.
- Check Mode 1 input and output protocol on both groups.
- Check Mode 2 simultaneous bidirectional capability on Port A.
- Check hidden INTE controls and interrupt qualification.
- Check Port C handshake overrides and remaining GPIO behavior.
- Check mode-set clearing and reconfiguration.
- Check unsupported control reads and invalid simultaneous bus strobes.
- Stress transitions and data values with a deterministic pseudorandom regression.

## Testbench architecture

```text
tb_intel_8255
├── clock/reset generator
├── CPU read/write tasks
├── peripheral handshake tasks
├── separately organized reference state/model
├── expected read and pin-mux functions
├── specification-derived protocol checks
├── whole-interface checker
└── directed + deterministic-random test sequence
```

The procedural bench is preferred over UVM for this compact register peripheral because it supports precise edge-by-edge checking without adding verification-library startup noise. The interface remains structured so a future UVM agent can reuse the same CPU transaction and handshake abstractions.

## Directed tests

| Test | Coverage |
|---|---|
| Reset/default | Control `9b`, all OEs low, no CPU control read drive |
| Mode 0 directions | 16 combinations of PA, PB, PC upper, and PC lower direction bits |
| Mode 0 values | Per-configuration XOR/OR patterns across all input and output paths |
| BSR | Set and reset PC0 through PC7; mode remains unchanged |
| Mode 1 A input | STB capture, IBF, INTE via PC4, INTR, CPU read clear |
| Mode 1 A output | CPU write, OBF low, ACK, INTE via PC6, INTR |
| Mode 1 B input | STB capture, IBF, INTE via PC2, INTR, CPU read clear |
| Mode 1 B output | CPU write, OBF low, ACK, INTE via PC2, INTR |
| Mode 2 input | PA release, STB capture, IBF, input interrupt, read clear |
| Mode 2 output | PA released with ACK high, driven with ACK low, released when ACK returns high |
| Mode 2 overlap | Input and output pending while ACK is high and PA is released |
| Reconfiguration | Mode-set clears latches, flags, and INTE controls |
| Invalid bus | Both strobes low and control read cause no state mutation |

## Deterministic pseudorandom regression

A fixed `16'h1ace` seed drives 1,024 operations selected from:

- legal mode-set words;
- BSR writes;
- Port A/B/C reads and writes;
- peripheral input changes;
- STB/ACK transitions;
- idle cycles.

After every operation, the checker compares all observable outputs with the separately organized reference model. The seed and operation count are printed and checked by `run_sim.sh` for reproduction.

## Functional coverage accounting

The testbench records counters rather than relying on simulator-specific covergroup support:

| Counter | Target |
|---|---:|
| Mode 0 direction configurations | 16/16 |
| BSR selections × actions | 16/16 |
| Mode 1 group/direction scenarios | 4/4 |
| Mode 2 input/output scenarios | 2/2 plus overlap |
| Mode-set writes | At least 20 |
| CPU reads/writes | At least 100 each |
| Handshake falling edges | At least 20 |
| Whole-interface comparisons | At least 500 |

Code-coverage percentages are not claimed because xezim does not produce a repository-standard line/toggle report. Directed scenario completion, checker counts, formal covers, and synthesis checks are the durable coverage evidence.

## Pass/fail criteria

- Every reference-model comparison matches.
- Every specification-derived protocol check passes.
- Every directed scenario reaches its completion marker.
- Functional counters meet or exceed targets.
- Simulation reports the fixed seed/count, `Failures: 0`, and `TEST PASSED`.
- No timeout occurs.
- Formal assertions and covers pass separately.
