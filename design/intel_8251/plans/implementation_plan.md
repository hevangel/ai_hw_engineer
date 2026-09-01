# Implementation Plan: Intel 8251 / 8251A

## Objective

Produce a synchronous, synthesizable SystemVerilog reconstruction of the Intel
8251/8251A USART programming model, verified by simulation, bounded and
unbounded formal proof, and generic synthesis, with all evidence reproducible
from the project container.

## Architecture

Five loosely coupled blocks share one clock domain and one sequential process:

- **Programming pointer.** A four-state pointer decides whether a control-port
  write lands in the mode instruction, sync character 1, sync character 2, or
  the command instruction. It is the only gate on the rest of the device: no
  serial activity happens until the pointer reaches the command state.
- **Register file.** Mode instruction, two sync characters, and the command
  instruction. Every behavioral field is a named continuous assign off those
  bytes, so the decode is visible at one place in the source.
- **Timing base.** The programmed baud-rate factor produces a bit period, a
  half-bit period, and a stop-phase length, all counted in baud-clock enable
  pulses. Every serial phase is a down-counter reload of one of those three
  values, which keeps the counters narrow and the state space small.
- **Transmitter.** A five-phase machine (idle, start, data, parity, stop) over a
  single 8-bit shifter, with a separate holding buffer so the datapath is
  double-buffered. Character launch is a single combinational condition, shared
  by the idle state and, in synchronous mode, by the boundary that ends the
  previous character. That is what makes synchronous characters contiguous.
- **Receiver.** A six-phase machine (start search, start verify, data, parity,
  stop, hunt) over a single 8-bit shifter plus a 15-bit sync-hunt window, with a
  holding buffer, three sticky error flags, a sync-detect flag, and a break
  run-length counter.

## Module hierarchy

```
intel_8251                 -- the whole device, no submodules
├── intel_8251_props       -- instantiated only under `FORMAL`
└── intel_8251_cover       -- instantiated only under `FORMAL` + `FORMAL_COVER`
```

There are no parameters. Everything configurable on the historical part is
configurable through register state, so making it a parameter would misrepresent
the device.

## Implementation phases

### Phase 1: specification and interfaces

Fix the port list, the CPU bus decode, and the three deviations from the
historical part before writing RTL: a single `clk` with synchronous `rst_n`,
`TxC`/`RxC` as single-cycle enable pulses rather than free-running clocks, and
input/output/output-enable triples in place of the tristate data bus and the
bidirectional `SYNDET` pin. Write `spec/spec.md` first and record the reading
chosen wherever the datasheet is ambiguous, so those choices can be reviewed
rather than reverse-engineered from the RTL.

### Phase 2: core RTL

Build in this order so each step is checkable against the specification on its
own: bus decode and status readback, programming pointer, mode and command
decode, timing base, transmitter, receiver, sync hunting, then break detection.
Keep one `always_ff` and apply effects in the order the specification fixes
(CPU reads, transmitter, receiver, CPU writes) so same-cycle races resolve the
way the specification says rather than by accident of source order.

### Phase 3: verification

Write the reference model and the wire-level serial driver and monitor together.
The model gives whole-interface comparison every cycle; the driver and monitor
give framing checks that do not depend on the model being right. Then write the
formal property set as a re-derivation of every output from registered state,
plus the invariants needed to bound the phase machines, and a cover harness with
a free environment so witnesses are found rather than scripted.

### Phase 4: evidence and review

Run lint, simulation, all three formal tasks, and synthesis from the container,
commit the resulting work products, and record the exact tool revisions and
image identifier used.

## Design decisions

- **Baud clocks as enables.** The historical part samples serial data on
  free-running `TxC`/`RxC` while running its register model from `CLK`. Modeling
  those as separate clocks would introduce clock-domain crossings that the
  original resolves with analog timing margin. Single-cycle enable pulses keep
  the design single-clock and synthesizable while preserving every ordering the
  programming model depends on.
- **No tristates.** The shared CPU data bus and the shared `SYNDET`/`BD` pin
  become input, output, and output-enable signals. This keeps the RTL free of
  bus contention and lets the formal property set assert exactly when the device
  drives.
- **One shifter per direction.** Character lengths from 5 to 8 bits are handled
  by masking and right-aligning a single 8-bit shifter rather than by four
  datapaths. Received characters shorter than 8 bits therefore zero-fill their
  high bits, matching the device.
- **Shift instead of variable part select.** The sync-hunt window extracts the
  previous character with a right shift and a mask. A variable indexed part
  select would let the index range exceed the window and synthesis would inject
  undefined bits.
- **Half-bit resolution only where needed.** The 1.5-bit stop phase is one bit
  period plus one half-bit period. At 1x division a half bit is not
  representable, so that combination costs two bit times; this is documented as
  accepted rather than silently rounded.
- **One-shot command bits stay one-shot.** Error reset, internal reset, and
  enter hunt act at the write. The whole command byte is still stored, so the
  three stored bits are explicitly declared as carrying no behavior.
- **Canonical idle state.** The bit counter is cleared whenever a phase machine
  returns to idle. Without that, the machines have two encodings for the same
  behavior and the formal invariants get weaker for no benefit.

## Constraints and dependencies

- SystemVerilog IEEE 1800-2017, synthesizable subset, one module per file.
- Must lint clean under `verilator --lint-only -Wall` and
  `verible-verilog-lint` with no waivers.
- Formal properties live in separate files and are instantiated under `ifdef`,
  never bound, so the synthesized RTL is exactly the file that was proved.
- Tools come from the project container only: Verilator, Verible, xezim, Yosys,
  SymbiYosys, and Z3.

## Milestones

1. `spec/spec.md` complete, port list frozen.
2. RTL lints clean and synthesizes without warnings.
3. Reference model agrees with the DUT across the whole directed sequence.
4. Wire-level framing checks pass for every programmed geometry.
5. Bounded proof passes.
6. Unbounded proof passes.
7. Every cover statement is reached.
8. `run_all.sh` passes end to end and the work products are committed.
