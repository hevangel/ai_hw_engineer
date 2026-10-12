# Test Plan — Apple IIe timing PAL

Plain SV self-checking bench (`tb/tb_top.sv`) with an independent reference
model written from spec.md: an explicit 14-entry truth table per output (the
RTL uses arithmetic compares on the next-tick decode — a different
encoding). The model advances with each committing edge and every output is
compared in every window.

## Directed tests

1. Reset-idle pattern; hold under `entmg_n = 0` with the counter stuck at 0
   (spec 4.4, A6); release resumes from tick 0.
2. Two full 40-column RAM cycles: φ0/φ1 windows, Q3 pattern (falls at ticks
   4/11), PRAS' fall at tick 4 with Q3, PCAS' fall at tick 6, LDPS' single
   pulse at 13, VID7M tracking 7M delayed one tick.
3. Non-RAM cycle (`ramen_n = 1`): PCAS' held high through ticks 6-12;
   following RAM cycle falls normally (the sample is per-cycle, A7).
4. 80-column cadence (`s80vid_n = 0`): LDPS' pulses at ticks 6 and 13.
5. Random soak, 6000+ ticks: random `ramen_n`/`s80vid_n`/7M pattern with
   occasional ENTMG drops; every output re-checked each window.

## Sentinels and runners

`Apple IIe PAL TEST PASSED`; `scripts/run_sim.sh [seed]` runs Verilator and
xezim, both must print the sentinel; `run_coverage.sh` targets 100%
statement/branch (no justified exclusions are expected — the design has no
structurally-constant bits); `run_synth.sh` Yosys.
