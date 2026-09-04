# Final Design Report: Intel 8251 / 8251A

## 1. Executive summary

`design/intel_8251/` contains a synchronous, synthesizable SystemVerilog
reconstruction of the Intel 8251/8251A Universal Synchronous/Asynchronous
Receiver Transmitter programming model, together with its specification, a
self-checking simulation regression, a formal property set with reachability
covers, and generic synthesis. Every stage passes from the project container and
the resulting work products are committed under `work/`.

The design implements both framing modes: asynchronous framing with a start bit,
5 to 8 data bits, optional odd or even parity, and 1, 1.5, or 2 stop bits at 1x,
16x, or 64x baud division; and synchronous framing with contiguous characters,
single or double sync character, internal or external sync detection, and
automatic sync-character fill on transmitter underrun. Parity, overrun, and
framing errors, break transmission and detection, the `TxRDY`/`TxEMPTY`/`RxRDY`
handshake, the readable status byte, modem control, and the software internal
reset are all present.

Results at a glance: lint clean with no waivers, 13530 simulation cycles with
zero failures, bounded and unbounded formal proofs passing, all 15 cover
statements reached, and synthesis producing 1479 generic cells with 122
flip-flops and zero reported problems.

## 2. Design overview

| Item | Value |
|---|---|
| Top module | `intel_8251` |
| Source | `src/intel_8251.sv`, 695 lines, one module, no parameters |
| Ports | 23 ports, 37 port bits |
| Sequential processes | one `always_ff`, synchronous active-low reset |
| State elements | 122 flip-flops after synthesis |
| Specification | `spec/spec.md`, 386 lines |
| Testbench | `tb/tb_intel_8251.sv`, 1496 lines, non-UVM, self-checking |
| Formal | `formal/intel_8251_props.sv` 344 lines, `formal/intel_8251_cover.sv` 116 lines |

Three deviations from the historical part are deliberate and are recorded in the
specification:

- The original derives internal timing from a `CLK` pin while sampling serial
  data on the free-running `TxC` and `RxC` baud clocks. This core is single
  clock: `TxC` and `RxC` become `txc_tick` and `rxc_tick`, single-cycle enable
  pulses, and a synchronous `rst_n` establishes a defined un-programmed state.
- The tristate CPU data bus and the bidirectional `SYNDET`/`BD` pin are
  represented by separate input, output, and output-enable signals, so no
  tristate driver appears in the RTL.
- At 1x division a half bit is not representable, so a 1.5-bit stop phase
  occupies two bit times. That degenerate combination is accepted and documented
  rather than rejected.

Where the datasheet is ambiguous, the reading chosen is stated in the
specification rather than left implicit. The one case that matters is the
synchronous programming sequence: the sync-character writes are consumed
whenever synchronous mode is programmed, including when external sync detection
is selected, in which case the stored characters are not used for detection.

## 3. Reproducible toolchain

| Tool | Validated version/revision |
|---|---|
| Verilator | 5.050, revision `3d2421f3` |
| Verible | `v0.0-4157-gfdbac312` |
| xezim | 0.10.3, revision `4d14581` |
| Yosys | 0.59+0, revision `26b51148a` |
| SymbiYosys | v0.68 |
| Z3 | 4.8.12 |

All validation commands ran in image ID:

```text
sha256:6527347d5b89da25ec70b3309539f591be5e7bc53bead2d24be7feaf925f9e3c
```

This image carries Yosys 0.59, which prints a different `stat` summary format
than the Yosys 0.46 used for earlier designs in this repository. `run_synth.sh`
accepts either format so the flow is not tied to one Yosys release.

## 4. Verification results

### 4.1 Lint

| Check | Command summary | Result |
|---|---|---|
| RTL | `verilator --lint-only -Wall` | PASS, zero warnings |
| RTL + timed testbench | `verilator --lint-only -Wall --timing` | PASS, zero warnings |
| Authored RTL/TB/formal sources | `verible-verilog-lint` | PASS, zero violations |

No lint waivers or `lint_off` pragmas are used anywhere in the design. Signals
that are intentionally stored without behavior, namely the three one-shot command
bits, are declared through an explicit unused-bits reduction with a comment
explaining why.

### 4.2 Simulation

The regression runs two independent checking mechanisms over the same stimulus.
A lockstep reference model is stepped one cycle ahead of each sampling edge and
the complete output interface is compared after the edge. Separately, a
wire-level monitor decodes the frames the transmitter emits and a wire-level
driver constructs frames on `RxD`, both written from the frame definition in the
specification and independent of the DUT's internal structure.

From `work/sim/intel_8251.log`:

```text
8251 simulation result: 13530 cycles, 13530 interface checks, 135418 field checks
CPU reads: 564, CPU writes: 1035, mode programmings: 217
TX frames decoded: 10, RX frames driven: 11, sync detections: 3
Error events: parity 1, framing 1, overrun 1, break 1
Failures: 0
TEST PASSED
```

Fourteen directed phases cover reset, asynchronous framing at 5 to 8 bits with
both parity polarities and all three stop-bit lengths, all three baud divisions,
sparse baud enables, transmit handshake and `CTS` gating, all three error flags
and their reset, break transmission and detection, modem status, internal reset,
and four synchronous configurations. A deterministic pseudorandom regression
seeded with `0x8251` then runs 2048 operations, reprogramming the device 217
times in total, with every cycle checked by the lockstep comparison.

Details are in `plans/testplan.md` and `report/coverage_report.md`.

### 4.3 Formal verification

| Task | Mode | Depth | Engine | Result | Elapsed |
|---|---|---:|---|---|---:|
| `bmc` | bounded | 24 | `abc bmc3` | PASS | 1 s |
| `prove` | unbounded induction | 24 | `abc pdr` | PASS, property proved | 1 s |
| `cover` | reachability | 32 | `smtbmc --syn --nopresat --unroll z3` | PASS, 15 of 15 reached | 13 s |

The property set re-derives every output as a pure function of the registered
state and asserts equality with the DUT, then proves the programming-pointer
transitions, the register-write contract, error-flag stickiness and reset,
buffer-fill provenance, and a set of invariants that bound both phase machines
and all of their counters. Reset is assumed only in the initial formal cycle, so
synchronous reset priority is proved rather than assumed; nothing else about the
environment is constrained.

The cover harness leaves the CPU bus, `RxD`, the modem inputs, and the external
sync input free, so the solver chooses the programming sequence and serial
stimulus that reaches each cover. The deepest witness is break detection at
step 20.

Details are in `plans/formal_plan.md`.

### 4.4 Synthesis

Generic synthesis through Yosys with `hierarchy -check`, `proc`, `flatten`,
`fsm`, `memory`, `techmap`, and `check`. From `work/synth/synth.log`:

```text
Found and reported 0 problems.

=== intel_8251 ===
      552 wires
     1754 wire bits
      103 public wires
      339 public wire bits
       23 ports
       37 port bits
     1479 cells
      362   $_AND_
        1   $_DFF_P_
      574   $_MUX_
       98   $_NOT_
      245   $_OR_
       73   $_SDFFE_PP0P_
       48   $_SDFF_PP0_
       78   $_XOR_
```

122 flip-flops, all but one with synchronous reset, and no latches, no memories,
and no unresolved processes. Netlists are written to
`work/synth/intel_8251_synth.v` and `work/synth/intel_8251_synth.json`.

## 5. Reproduction

```bash
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  sha256:6527347d5b89da25ec70b3309539f591be5e7bc53bead2d24be7feaf925f9e3c \
  sh design/intel_8251/scripts/run_all.sh
```

Individual entry points are `scripts/run_lint.sh`, `scripts/run_sim.sh`,
`scripts/run_formal.sh` (with `all`, `bmc`, `prove`, or `cover`),
`scripts/run_synth.sh`, and `scripts/run_coverage.sh`, which re-runs the
simulation and prints the coverage evidence lines from the log.

## 6. Known issues and scope limits

- **No pin-level or electrical model.** NMOS levels, drive strength, setup and
  hold times, propagation delays, and the 28-pin package are out of scope.
- **No baud-clock domain.** The environment is responsible for producing clean
  single-cycle `txc_tick` and `rxc_tick` pulses. Metastability and clock-domain
  crossing between the core clock and the baud clocks are not modeled.
- **1x asynchronous division is structural only.** The receiver spends one extra
  baud enable on start-bit search before its half-bit verification, so at 1x it
  cannot centre its samples and a 1x loopback does not decode. The historical
  part has the same limitation and requires external bit synchronization at 1x.
  The regression therefore exercises 1x for launch and completion timing but
  performs its wire-level frame decoding at 16x and 64x.
- **Formal coverage stops short of whole frames.** A character spans roughly 176
  baud enables at 16x and 700 at 64x, beyond a useful proof depth. Frame-level
  correctness comes from simulation. This boundary is stated in
  `plans/formal_plan.md`.
- **Original 8251 versus 8251A.** The behavior implemented follows the 8251A,
  which is fully double-buffered and adds break detection on the `SYNDET`/`BD`
  pin. The original 8251 has documented usage restrictions around command timing
  that are not modeled.
- **Ambiguous datasheet reading.** Whether external sync detection still consumes
  the sync-character writes is not settled by the sources located. The
  specification states the reading implemented so it can be reviewed; if the
  opposite reading is preferred, the change is one branch in the programming
  pointer plus the matching model, property, and directed-test updates.
- **No unresolved TODOs** remain in the RTL, testbench, formal sources, or
  scripts.

## 7. Sign-off

| Gate | Status |
|---|---|
| RTL lints clean under `verilator --lint-only -Wall` | PASS |
| Testbench lints clean with `--timing` | PASS |
| Verible lint clean on all authored sources | PASS |
| Simulation passes with zero failures and all coverage minimums met | PASS |
| Bounded formal proof | PASS |
| Unbounded formal proof | PASS |
| All cover statements reachable | PASS |
| Generic synthesis with zero reported problems | PASS |
| Specification, plans, and reports current with the RTL | PASS |
| `scripts/run_all.sh` passes end to end | PASS |
