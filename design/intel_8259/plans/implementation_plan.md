# Implementation Plan: Intel 8259A

## Objective

Implement a single-module, synthesizable reconstruction of the Intel 8259A
Programmable Interrupt Controller digital programming model: initialization
(ICW1-ICW4), operation commands (OCW1-OCW3), edge/level request sensing, the
IRR/ISR/IMR registers, a rotating priority resolver, the CPU acknowledge
sequence in both MCS-86/88 and MCS-80/85 modes, all end-of-interrupt variants,
automatic EOI, special fully nested mode, special mask mode, polled mode,
register readback, and cascade signaling.

## Architecture

```text
                      +---------------------------------+
CPU controls/a0/data->| bus decode + init/OCW sequencer |
                      +----------------+----------------+
                                       |
        +------------------+-----------+------------+------------------+
        |                  |                        |                  |
  +-----v-----+     +------v------+          +------v------+     +-----v------+
  | IRR (edge/|     | IMR mask    |          | ISR + EOI/  |     | priority   |
  | level)    |     |             |          | rotation    |     | resolver   |
  +-----+-----+     +------+------+          +------+------+     +-----+------+
        |                  |                        |                 |
        +---------+--------+------------+-----------+-----------------+
                  |                     |
            +-----v-----+        +------v-------+
            | INT logic |        | acknowledge  |
            | (nested/  |        | FSM + cascade|
            |  SFNM/SMM)|        | + vector gen |
            +-----+-----+        +------+-------+
                  |                     |
                INT to CPU        data_o / cas / en_n
```

The core uses one `always_ff` process for all registered state (initialization
FSM, ICW/OCW registers, IRR/ISR/IMR, priority rotation, acknowledge phase) and a
set of `always_comb` blocks for the priority resolver, interrupt-request logic,
CPU read data, acknowledge vector/opcode output, and cascade/buffer outputs.
Request edges and acknowledge pulses are detected with previous-sample
registers, mirroring the synchronous sampling approach used across this
repository's reconstructions of asynchronous devices.

## Module hierarchy

```text
intel_8259
├── CPU transaction decode (cs_n/rd_n/wr_n/a0)
├── initialization state machine (ICW1 -> ICW2 -> [ICW3] -> [ICW4] -> ready)
├── ICW1-ICW4 and OCW1 registers
├── IRR request sensing (edge / level)
├── IMR mask
├── priority resolver (rotate + fixed priority encoder)
├── interrupt-request logic (nested / SFNM / special mask)
├── ISR with EOI, rotation, and set-priority
├── acknowledge FSM (2 or 3 pulses) + cascade address + vector/opcode/address
└── register readback and poll word
```

A single module is intentional. The interrupt state interactions (request,
mask, in-service, priority, acknowledge phase) are tightly coupled, and
splitting them would obscure the ordering rules that define correct behavior.

## Implementation phases

### Phase 1: specification and interfaces

- [x] Define the CPU bus, request lines, acknowledge handshake, and split
      cascade/buffer pins.
- [x] Record the ICW/OCW encodings, register map, and vector/address formulas.
- [x] Define synchronous event ordering and deviations from the asynchronous
      original (added clock and reset).

### Phase 2: core RTL

- [x] Implement reset to a defined un-initialized state and the ICW1-ICW4
      initialization sequencer.
- [x] Implement edge- and level-triggered request sensing.
- [x] Implement the rotating priority resolver and the nested/SFNM/special-mask
      interrupt-request logic.
- [x] Implement the acknowledge FSM for MCS-86/88 (two pulses) and MCS-80/85
      (three pulses, CALL opcode and two address bytes).
- [x] Implement OCW1 masking, OCW2 EOI/rotate/set-priority, and OCW3
      special-mask/read-select/poll.
- [x] Implement automatic EOI and rotate-in-automatic-EOI.
- [x] Implement cascade signaling (master cascade drive, slave decode, buffered
      `EN_n`).
- [x] Add explicitly connected property and cover modules under `FORMAL`.

### Phase 3: verification

- [x] Add a self-checking procedural testbench with a separately organized
      cycle-accurate reference model.
- [x] Add specification-derived black-box checks (vector formula, nesting,
      EOI clearing, poll word, cascade drive).
- [x] Exercise reset, initialization, both trigger modes, priority nesting,
      all EOI variants, rotation, masking, poll, special mask, both µP modes,
      cascade master and slave, buffered mode, and reinitialization.
- [x] Add formal combinational-equivalence and behavioral safety properties and
      a scripted-stimulus non-vacuity cover harness.
- [x] Run strict lint, simulation, BMC, unbounded proof, cover, and synthesis.

### Phase 4: evidence and review

- [x] Capture exact test counts, proof results, cover reachability, and
      synthesis utilization.
- [x] Record scope limits and the formal-cover tool workaround.
- [x] Update the chip index and historical README.

## Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| Core timing | Single rising-edge clock | Portable synthesis for a historically asynchronous device |
| Reset | Synchronous active-low `rst_n` | Repository default; the original has no reset pin, so reset establishes a defined pre-initialization state |
| Bidirectional pins | Separate `i`, `o`, and `oe` for the cascade and buffer-enable pins | Avoids internal tri-states and supports FPGA/ASIC wrappers |
| CPU/handshake strobes | Active-low levels and pulses sampled on `clk` | Preserves historical signal names while making acceptance deterministic |
| Architecture | One module | Keeps request/mask/in-service/priority/acknowledge ordering visible together |
| Priority resolver | Rotate candidate mask + fixed lowest-index priority encoder | Behaviorally identical to modular ranking but far easier for AIG and SMT reasoning |
| Both µP modes | MCS-86/88 and MCS-80/85 acknowledge sequences | Faithful to the 8259A, which added 8086 mode to the MCS-85-era 8259 |
| Cascade | Master drives `CAS`; slave engages only on a matching cascade address | Models multi-chip selection within a single-device core |
| Verification oracles | Cycle-accurate reference model, specification-derived directed checks, and formal properties | Exposes protocol mistakes a structurally similar model could share with the RTL |

## Constraints and dependencies

- IEEE 1800-2017 SystemVerilog.
- No vendor primitives or generated IP.
- Tools supplied by image
  `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`.
- No target clock or area budget; generic Yosys synthesis is the structural
  acceptance test.
- External asynchronous requests and acknowledges require integration-level
  synchronization.

## Milestones

| Milestone | Status |
|---|---|
| Specification complete | Complete |
| RTL complete | Complete |
| Formal clean (BMC, proof, cover) | Complete |
| Simulation complete | Complete |
| Synthesis complete | Complete |
| Documentation and automated gates | Complete |
