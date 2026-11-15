# Am26LS33 implementation plan

## Contract

1979 Linear and Interface Data Book pages 4-40..4-44 (shared
Am26LS32 · Am26LS33 sheet): identical digital contract to the verified
Am26LS32 member (per-receiver comp = (IN+ > IN−), 3-state outputs, OR-ed
enables, fail-safe ties); the LS33's ±500 mV over ±15 V sensitivity
envelope is electrical and documented, not modeled.

## Structure

One self-contained file `src/am26ls33.sv`, structurally identical to
the verified Am26LS32 source with its own part identity (distinct
physical part, distinct member issue). No waivers needed.

## Verification mapping

Lint (Verilator `-Wall`), exhaustive 1024-combination simulation under
Verilator and xezim (exact `z`-state assertions), formal
bmc/prove/cover (`formal/am26ls33.sby`), Yosys synthesis with
`check -assert`. The test and formal plans state the detailed mapping.
