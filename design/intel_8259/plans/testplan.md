# Test Plan: Intel 8259A

## Overview

Verification uses a deterministic, self-checking SystemVerilog testbench. A
separately organized, cycle-accurate reference model is stepped in lockstep with
the DUT, and the entire output interface is compared after every sampled cycle.
Because that model necessarily shares the programming-model definitions with the
DUT, specification-derived black-box checks separately enforce the interrupt
vector formula, priority nesting, end-of-interrupt clearing, the poll word, and
cascade signaling, so the design is not accepted solely through comparison with
a structurally similar model. The compared interface is `data_o`, `data_oe`,
`int_o`, `cas_o`, `cas_oe`, `en_n_o`, and `en_n_oe`.

## Verification goals

- Prove reset holds the device un-initialized with `INT` inactive and buses
  released.
- Check the ICW1-ICW4 initialization sequence in single and cascade modes.
- Check edge-triggered and level-triggered request sensing.
- Check the interrupt vector formula in MCS-86/88 mode and the `CALL`
  opcode/address sequence in MCS-80/85 mode.
- Check fully nested priority, preemption, and the block of lower priority.
- Check non-specific EOI, specific EOI, rotate-on-EOI, set-priority, and
  automatic EOI.
- Check masking through OCW1 and IMR readback.
- Check polled mode and the poll acknowledge.
- Check IRR/ISR readback through OCW3.
- Check special mask mode enabling an otherwise blocked level.
- Check cascade master cascade-address drive and bus release, slave engagement
  only on a matching cascade address, and buffered-mode `EN_n`.
- Check reinitialization clearing.
- Stress transitions and command values with a deterministic pseudorandom
  regression.

## Testbench architecture

```text
tb_intel_8259
├── clock/reset generator
├── CPU read/write tasks
├── interrupt-request edge/level tasks
├── INTA pulse task (captures the presented bus datum)
├── separately organized cycle-accurate reference model (model_step)
├── expected combinational-output block
├── specification-derived protocol checks
├── whole-interface checker
└── directed + deterministic-random test sequence
```

The procedural bench is preferred over UVM for this compact register peripheral
because it supports precise edge-by-edge checking of the acknowledge sequence
without verification-library startup overhead. CPU reads sample the bus during
the active read, before the sampling edge commits any read side effect (the poll
acknowledge), matching how a CPU latches the bus.

## Directed tests

| Test | Coverage |
|---|---|
| Reset/default | Un-initialized, `INT` low, buses released |
| 8086 single init + interrupt | ICW1/ICW2/ICW4, edge request, vector `{ICW2[7:3], level}` |
| Fully nested priority | Lower blocked while in service; higher preempts |
| Specific EOI and rotation | Rotate-on-non-specific-EOI reorders priority; specific EOI |
| Masking | OCW1 mask hides a request; unmask reveals it; IMR readback |
| Polled mode | OCW3 poll, poll word with pending level, poll acknowledge sets ISR |
| Level-triggered | Held line re-requests after EOI |
| Automatic EOI | ISR self-clears at end of acknowledge |
| Special mask mode | Enables a lower level while a higher level is in service |
| 8085 cascade master | `CALL` opcode, interval-8 address bytes, cascade drive for slave line |
| 8086 cascade slave | Engages only on a matching cascade address; drives its own vector |
| Buffered master | `EN_n` is driven as an output |
| Reinitialization | ICW1 restart clears IRR and holds `INT` inactive until ready |

## Deterministic pseudorandom regression

A fixed `16'h8259` seed drives 2,048 operations selected from: full
reinitialization with random flavor bits (trigger, single/cascade, µP mode,
AEOI), OCW1 mask writes, OCW2 commands, OCW3 commands (including poll), interrupt
request edge changes, CPU reads, INTA pulses, and idle cycles. After every
operation the checker compares the entire output interface with the reference
model. The seed and operation count are printed and checked by `run_sim.sh`.

## Functional coverage accounting

The testbench records counters rather than relying on simulator-specific
covergroup support:

| Counter | Target |
|---|---:|
| Initialization sequences | At least 10 |
| Acknowledge sequences | At least 10 |
| EOI commands | At least 8 |
| Poll reads | At least 1 |
| OCW3 writes | At least 5 |
| CPU reads / writes | At least 20 / 60 |
| IR rising edges | At least 15 |
| Whole-interface comparisons | At least 500 |

Code-coverage percentages are not claimed because the pinned xezim flow does not
emit a repository-standard line/toggle report. Directed scenario completion,
checker counts, formal covers, and synthesis checks are the durable coverage
evidence.

## Pass/fail criteria

- Every reference-model interface comparison matches.
- Every specification-derived protocol check passes.
- Every directed scenario reaches its completion marker.
- Functional counters meet or exceed targets.
- Simulation reports the fixed seed/count, `Failures: 0`, and `TEST PASSED`.
- No timeout occurs.
- Formal assertions and covers pass separately.
