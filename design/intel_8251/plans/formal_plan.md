# Formal Verification Plan: Intel 8251 / 8251A

## Scope

Formal verification covers the parts of the device whose correctness is a
property of a single state transition or of a combinational derivation: output
derivation, the programming sequence, the register-write contract, error-flag
behavior, buffer-fill provenance, and the reachable state space of the two phase
machines.

It deliberately does not cover the serial bit streams. A character at 16x
division spans roughly 176 baud enables, and at 64x roughly 700, so any property
about a whole frame needs a trace far longer than a useful proof depth. Stream
correctness is verified instead by the wire-level monitor and driver in the
simulation regression, which can observe an entire character time. The split is
recorded here so the coverage boundary is explicit rather than implied.

## Safety and equivalence properties

`formal/intel_8251_props.sv` re-derives the decoded mode and command fields, the
bus decode, the timing base, and the status byte from the state ports, then
asserts equality with the DUT. Because the property file computes everything
independently, an error in the RTL derivation shows up as an inequality rather
than being reproduced on both sides.

Combinational equivalence, asserted in every state:

- `data_o` and `data_oe` together, including the choice between status and the
  receive buffer and the all-zero value when no read is decoded;
- `txd` including the send-break override;
- `txrdy`, `txempty`, and `rxrdy`;
- `syndet_o` and `syndet_oe`, including the break-detect and sync-detect sources
  and the external-detection case where the pin is an input;
- `rts_n` and `dtr_n` against the command word.

Combinational structural safety:

- the device drives the CPU bus only during a decoded read;
- a read and a write never decode together;
- `txrdy` implies an empty buffer, an active `CTS`, and a configured device;
- `SYNDET` is never driven before the mode instruction is written.

Single-transition behavioral properties:

- synchronous reset priority: after a cycle with reset low, or after an internal
  reset command, every state element holds its reset value. Reset is assumed only
  in the initial formal cycle, so priority is proved rather than assumed;
- the programming pointer advances exactly as specified from each of its four
  states, and the byte written lands in the register that state selects;
- the mode instruction, both sync characters, and the command instruction are
  unchanged in any cycle whose write did not target them;
- error reset clears all three error flags; otherwise a set flag stays set;
- a CPU data write fills the transmit buffer with that byte, and the transmit
  buffer can only fill through a CPU data write;
- the receive buffer can only fill through the receiver, on a cycle with a
  receiver baud enable and the receiver enabled;
- a status read clears the sync-detect flag unless the receiver set it in the
  same cycle from hunt, which is the only permitted exception;
- `RTS` and `DTR` follow the command word written in the previous cycle.

## State-space invariants

These bound the reachable state so the unbounded proof converges and so the
phase machines cannot reach an encoding the case statements do not handle:

- both phase-state encodings stay inside their defined range;
- before the command instruction, the command register is zero and the
  transmitter is idle with a zero bit count and a zero division counter;
- the transmitter's division counter is below the bit period outside the stop
  phase and below the stop-phase length inside it, and is zero when idle;
- the transmitter's bit count is zero when idle, between one and the character
  length while shifting data, and equal to the character length during parity;
- the receiver's division counter is zero in start search and hunt, below the
  half-bit period during start verification, and below the bit period elsewhere;
- the receiver's bit count is below the character length while shifting data and
  equal to it during parity;
- the start-bit and stop-bit phases are unreachable in synchronous mode, and the
  start-search, start-verify, and stop phases are unreachable while the receiver
  is enabled in synchronous mode.

## Reachability covers

`formal/intel_8251_cover.sv` leaves the environment free except for two
constraints that keep witnesses short: reset is asserted only in the initial
cycle, and both baud-rate enables are held asserted so one core clock equals one
baud pulse. The CPU bus, `RxD`, the modem inputs, and the external sync input are
unconstrained, so the solver chooses the programming sequence and the serial
stimulus rather than following a script.

Cover mode leaves the pre-reset state free, so any cover that could be satisfied
by that free state is qualified to rule it out.

| Cover | Target |
|---|---|
| C1 | configured for asynchronous framing |
| C2 | configured for synchronous framing |
| C3 | a transmit character reaches the stop phase |
| C4 | a complete asynchronous frame is driven and the transmitter returns to idle |
| C5 | a received character is available to the CPU |
| C6 | parity error |
| C7 | framing error |
| C8 | overrun error |
| C9 | break detected and driven on the shared pin |
| C10 | sync pattern detected and the receiver has left hunt |
| C11 | synchronous underrun drives sync-character fill |
| C12 | a status read drives the CPU bus |
| C13 | a receive-buffer read returns a non-zero character |
| C14 | the transmit buffer is loaded while a character is in flight |
| C15 | an internal reset returns the programming pointer to the mode instruction |

## Assumptions

The property task assumes only that reset is low in the initial formal cycle.
Nothing else about the environment is constrained, so the bus strobes, the baud
enables, the serial input, and reset itself are free in every later cycle.

The cover task adds the two witness-shortening constraints described above. They
restrict the search, not the design, and no property is proved under them.

## Proof strategy

Three tasks in one `.sby` file, selected by define:

| Task | Mode | Depth | Engine |
|---|---|---:|---|
| `bmc` | bounded | 24 | `abc bmc3` |
| `prove` | unbounded induction | 24 | `abc pdr` |
| `cover` | reachability | 32 | `smtbmc --syn --nopresat --unroll z3` |

`FORMAL` selects the property module; `FORMAL` plus `FORMAL_COVER` selects the
cover module instead. Both are instantiated inside an `ifdef` at the bottom of
the RTL rather than bound, so the file that is proved is the file that is
synthesized.

The property set is written so induction converges without a manual invariant
hunt: the equivalence assertions are pure functions of registered state and are
therefore trivially inductive, the behavioral properties span a single
transition, and the state-space invariants supply the strengthening that the
phase-machine and counter properties need.

## File organization

```
formal/
├── intel_8251.sby          -- three tasks, per-task engines and defines
├── intel_8251_props.sv     -- equivalence, safety, and invariants
└── intel_8251_cover.sv     -- reachability covers, free environment
```

## Final status

All three tasks pass from the project container.

| Task | Result | Elapsed |
|---|---|---:|
| `bmc`, depth 24 | PASS | 1 s |
| `prove`, depth 24 | PASS, property proved by induction | 1 s |
| `cover`, depth 32 | PASS, 15 of 15 covers reached | 13 s |

The deepest cover witness is at step 20 (break detection), comfortably inside
the configured depth.
