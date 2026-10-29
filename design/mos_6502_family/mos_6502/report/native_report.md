# Native NMOS 6502 engine verification

## Implemented contract

`mos_6502_native.sv` adds an independent native-cycle sequencer alongside
the existing functional `mos_6502.sv`. It covers documented and undocumented
opcode slots, decimal arithmetic, original/new RMW writes, dummy reads,
page-cross corrections, reset, IRQ/NMI entry, stack cycles, RDY and SO.
The unstable opcode profile is parameterized and qualified in the
[native specification](../spec/spec_native_bus.md). Existing users of the
functional engine retain their interface.

## Measured results (2026-10-19)

Docker image `ai-hw-engineer:latest`: Verilator 5.052, xezim 0.11.0,
Yosys/SymbiYosys 0.69. Commands below are relative to this design directory.

| Gate | Result |
|---|---|
| `scripts/run_native_bus.sh` | Strict `-Wall` lint and 2,560,000 independent cases, all 256 opcode slots, 11,959,871 exact bus transactions; final PC/registers/RAM checked |
| `scripts/run_native_control.sh` | Directed reset/RDY/RMW/IRQ/NMI/SO/KIL checks pass; unmodified historical Klaus image reaches exact success JMP at PC 3469 after 96,241,371 native cycles |
| `scripts/run_native_netlist.sh` | 770 scenarios / 69,300 cycles against unmodified, hash-pinned die-derived transistor simulator; every address, direction and written byte agrees |
| `scripts/run_native_formal.sh` | BMC depth 24, PDR proof and all nine reachable covers (cover bound 32) pass |
| `scripts/run_native_kim.sh` | Original KIM-1 monitor, both 6530 masks and native CPU: two ordered display scans, 12 segment writes, one mask-RAM write after 8,533 clocks; Verilator and xezim agree |
| `scripts/run_native_synth.sh` | Generic Yosys synthesis and `check` pass, 4,264 cells |

`scripts/run_native_all.sh` generates the full pinned instruction inputs
and runs every native gate, including both historical programs. Inputs and
build artifacts stay under ignored `work/native/`. The pre-existing
`scripts/run_all.sh` remains the legacy functional-engine verification flow.

## Independent evidence and bugs caught during development

The [SingleStepTests revision](https://github.com/SingleStepTests/65x02/tree/2f6980a2d95757486c7bee24355c360e40e2a224)
is emulator-generated; it does not establish silicon timing on control-pin
transitions. The separate [perfect6502 revision](https://github.com/mist64/perfect6502/tree/09fc542877a84318291aa42dab143a3e2c3db974)
uses a recovered Visual6502 transistor netlist. Its source and license
hashes are checked before building the test adapter. It is independent of
this RTL and is not modified to make tests pass. The adapter seeds only
the verification model after the netlist executes a deterministic bootstrap.

That comparison found issues missed by the instruction corpus and initial
directed controls: RDY address-carry correction, penultimate-cycle IRQ
sampling, same-page branch polling, NMI admission timing, held SEI/CLI
I-latch writes and the late-NMI BRK latch-clear window. The RTL and the
original directed NMI expectation were corrected to the external die
behavior. The complete instruction corpus, historical programs and formal
properties were then rerun. The RDY address-stability assertion now encodes
the measured address-carry exception rather than assuming all latches stall.

## Remaining fidelity gates

This is substantial native-cycle coverage, not complete electrical sign-off.
Subcycle setup/hold windows, every combined pin transition, all stalled ALU
latches, transistor-oracle reset/KIL recovery, unstable opcodes across dies,
and Atari/NES/C64 board timing still need independent validation. No console
is claimed operational by these CPU results. The native engine exposes
logical debug registers; the die's internal PC/flags have pipeline timing
and are not compared as architectural state in the middle of instructions.

The oracle's simulator and netlist have distinct licenses. The original
netlist retains its CC BY-NC-SA 3.0 header and Visual6502 attribution; no
netlist or simulator code is copied into the original synthesizable RTL.
