# Formal Verification Plan: [CHIP_NAME]

## Overview

This document defines the formal verification strategy for [CHIP_NAME].

## Formal Verification Scope

### In Scope (Formal)
- Interface protocol compliance
- Control logic properties
- FSM reachability and deadlock freedom
- Data integrity (FIFO, memory)
- Arbitration fairness

### Out of Scope (Simulation Only)
- Performance
- Full system integration
- Analog behaviors

## Property Categories

### Safety Properties (assert)

Properties that must always hold:

| ID | Property | Module | Priority |
|----|----------|--------|----------|
| S1 | No data corruption | datapath | P1 |
| S2 | Mutex on shared resource | arbiter | P1 |
| S3 | Valid/ready protocol | interface | P1 |
| S4 | FIFO never overflow | fifo | P1 |
| S5 | FSM no illegal state | controller | P2 |

### Liveness Properties (cover)

Properties that must be reachable:

| ID | Property | Module | Priority |
|----|----------|--------|----------|
| L1 | Can complete a transaction | top | P1 |
| L2 | Can fill FIFO | fifo | P2 |
| L3 | All FSM states reachable | controller | P2 |

### Assumptions (assume)

Constraints on the environment:

| ID | Assumption | Rationale |
|----|------------|-----------|
| A1 | Reset active for first N cycles | Standard reset protocol |
| A2 | Valid input encoding | Interface spec |
| A3 | No simultaneous conflicting ops | Protocol constraint |

## Proof Strategy

| Property Set | Engine | Mode | Depth |
|--------------|--------|------|-------|
| Protocol | smtbmc z3 | bmc | 50 |
| Protocol | abc pdr | prove | — |
| Data integrity | smtbmc z3 | bmc | 30 |
| Reachability | smtbmc z3 | cover | 20 |
| FSM properties | abc pdr | prove | — |

## File Organization

```
formal/
├── <chip>_props.sv       — All SVA properties
├── <chip>_bind.sv        — Bind statements (optional)
├── <chip>_bmc.sby        — BMC configuration
├── <chip>_prove.sby      — Proof configuration
└── <chip>_cover.sby      — Cover configuration
```

## .sby Template

```ini
[tasks]
bmc
prove
cover

[options]
bmc: mode bmc
bmc: depth 50
prove: mode prove
cover: mode cover
cover: depth 30

[engines]
bmc: smtbmc z3
prove: abc pdr
cover: smtbmc z3

[script]
read -formal <chip>.sv
read -formal <chip>_props.sv
prep -top <chip>

[files]
../src/<chip>.sv
<chip>_props.sv
```

## Success Criteria

- All BMC proofs pass to specified depth
- All unbounded proofs (pdr) pass
- All cover points reachable
- No vacuous proofs (cover mode confirms reachability)
- Clean with no timeout or unknown results

## Review Checklist

- [ ] All specified properties captured
- [ ] Assumptions are justified and minimal
- [ ] No over-constraining (cover mode passes)
- [ ] Proofs are non-vacuous
- [ ] Results documented in report
