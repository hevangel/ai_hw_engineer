# Intel 3404 validation report

Date: 2026-10-08
Environment: `ai-hw-engineer:latest` (Verilator 5.053, Yosys 0.68+195,
SBY v0.69 snapshot, xezim 0.10.5, z3 5.1.0)

## Results

| Step | Result | Evidence |
|------|--------|----------|
| Verilator lint (RTL, `-Wall`, no waivers) | PASS | `run_lint.sh` clean |
| Verilator lint (TB, waived BLKSEQ/PROCASSINIT/UNUSEDSIGNAL) | PASS | `run_lint.sh` clean |
| Formal bmc (smtbmc z3, depth 6) | PASS | `work/formal/bmc/PASS` |
| Formal prove (smtbmc z3, depth 6) | PASS | `work/formal/prove/PASS` |
| Formal cover | PASS, non-vacuous | all six covers reached (steps 2-3), traces in `work/formal/cover/` |
| Verilator simulation | PASS | `intel_3404 TEST PASSED (5010 checks)` |
| Xezim simulation | PASS | `intel_3404 TEST PASSED (5010 checks)` |
| Code coverage (xezim) | 100% | statement 6/6, branch 6/6, toggle 24/24 |
| Yosys generic synthesis | PASS | `check -assert` clean, `work/synth/synth.log` |

## What was verified

- Reset landing: after a reset edge the inverted outputs sit high
  (reconstruction artifact, spec A3).
- Per-section write semantics: a write enable low at an edge stores the
  inverted data; a write enable high holds the stored value even while
  that section's data inputs change (directed hold-against-disturbance
  checks and formal S1-S3).
- Section independence: writing either section never disturbs the other;
  simultaneous writes land independently (directed checks and formal S4).
- 5000 cycles of unconstrained data/write-enable stimulus match the
  shadow model in both simulators.
- Formal properties are formulated from the datasheet timing diagram
  (setup/hold around the rising write-enable edge) rather than from the
  RTL enable structure, and the single assumption is the initial-reset
  convention.

## Verification incident

The first formal run failed: `$past` registers and the stored bits are
unconstrained in the formal initial state, so the properties misfired at
the first evaluated edge (counterexample trace in
`work/formal/bmc/engine_0/`, 2 steps). Fix: an `f_past_valid` flag gates
every `$past`-based assert and cover. The RTL was correct; the property
harness needed the guard.

## Known limitations

- Electrical characteristics (12 ns data-to-output, setup/hold, write
  pulse width) are out of scope for this functional reconstruction.
- The physical 16-pin interface and the stage order within each section
  are documented in `README.md`/`spec.md` (assumption A1) but not
  modeled.
