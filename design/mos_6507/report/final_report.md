# MOS 6507 package verification

## Contract and evidence

The original `mos_6507.sv` adapter uses the shared native NMOS engine,
retains sixteen-bit logical addresses, exposes thirteen physical address
bits and disables IRQ/NMI with the die-documented internal ties. The
[specification](../spec/spec.md) separates sampled digital behavior from
unimplemented clock/electrical behavior and revision-specific assumptions.

## Results (2026-10-19)

Docker image `ai-hw-engineer:latest`, Verilator 5.052, xezim 0.11.0,
Yosys/SymbiYosys 0.69. `scripts/run_all.sh` includes all shared native
6502 gates, not only this small package test.

| Gate | Measured result |
|---|---|
| Strict lint | `verilator --lint-only -Wall` passes without RTL warning waivers |
| Formal | BMC depth 24, PDR proof, all 12 reachable covers within bound 40; actual core IRQ/NMI/SO ties asserted |
| Package simulation | 45 exact bus checks in Verilator and xezim; reset vectors, logical/physical aliases, read stalls, writes despite RDY, indexed carry across physical wrap, BRK stack/vector and FFFF-to-0000 architectural PC wrap |
| Historical software | Original KIM monitor through actual thirteen-bit package interface; two ordered display scans, 12 segment writes and one mask-RAM write after 8,533 clocks in both simulators |
| Synthesis | Generic flattened Yosys synthesis and `check` pass, 4,199 cells |
| Shared CPU prerequisites | All 2,560,000 independent opcode cases, 11,959,871 exact bus cycles; 770 die-derived timing scenarios, 69,300 cycles; native formal and historical Klaus success at PC 3469 after 96,241,371 clocks |

The package bench executes CLC/CLD/CLV before checking the exact BRK status
byte. A first four-state run exposed undefined power-on flag assumptions
in the bench; architectural instructions now initialize those flags rather
than relying on Verilator's two-state startup. No unknown state is masked
in the expected stack data.

The shared native NMI-vector cover is intentionally disabled only in the
6507 formal task: the package's proven internal high ties make that state
unreachable. Ordinary native 6502 formal still reaches it. BRK's IRQ-vector
path remains reachable and covered on the 6507.

## Remaining gates

This result establishes the sampled package contract and real NMOS software
execution. It does not establish the on-chip oscillator, PHI2 duty cycle,
electrical constraints, every 6507 die revision or transistor-oracle warm
reset/KIL timing. Atari game code, TIA/RIOT arbitration, controller input,
cartridge bank switching, independent raster/audio comparison and a usable
system front panel remain requirements for the Atari 2600 system build.
The historical KIM diagnostic fixture is not an Atari emulator.
