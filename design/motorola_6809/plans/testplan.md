# Test Plan — Motorola MC6809

## Gates (all must pass; run via `scripts/run_all.sh`)

| Gate | Script | Pass criterion |
|------|--------|----------------|
| Lint | `run_lint.sh` | `verilator --lint-only -Wall` clean (RTL and TB) |
| Functional suite | `run_sim.sh` (1/2) | reyco2000 6809_functional_test self-reports pass via DEV_EXIT=0 (all instructions × addressing modes × flags) |
| Interrupt suite | `run_sim.sh` (2/2) | reyco2000 6809_interrupt_test self-reports pass (IRQ/FIRQ/NMI/SWI/SWI2/SWI3/CWAI/SYNC) |
| Formal | `run_formal.sh` | `bmc`, `prove`, `cover` tasks all DONE (PASS) |
| Synthesis | `run_synth.sh` | Yosys generic `synth` clean |

## Third-party suite coverage (hardware-validated)

- Every documented instruction in every addressing mode, with expected
  results AND flag values (alu8/alu16 vector tables, modemem RMW checks).
- All 16 short branches and long branches for every N/Z/V/C combination.
- Indexed postbyte forms including 5-bit, A/B/D offsets, n8/n16, PCR,
  auto-increment/decrement, and all indirect forms.
- Stack engine: full-frame push/pop integrity (t0b compares the stacked
  bytes against a fixed pattern), pull-in-pieces, PSHU with S-slot,
  PC-transfer via TFR/push-pull and jump-through-DPV trampolines.
- Interrupts: frame layout checks (HCC, FRAME bytes), nesting, masking,
  CWAI delayed-entry, SYNC wake-on-masked vs service-on-unmasked,
  deferred DEV line changes.

## Formal properties (formal/motorola_6809.sby)

- Reset vector address; fetch discipline; vector-fetch window (FFF2+).
- Push addressing: write at (pq_us ? u : s) - 1; pull/RTI: read at the
  pointer; JSR/BSR return-address byte order (PCL first).
- RMW address stability; wait-state bus parking.
- Queue invariant: the push/pull walk never runs with an empty mask.
- BMC-only bounded progress: FETCH reached within 60 cycles of leaving it
  (CWAI/SYNC waits excluded).
- Reset-stable assumption once released; cover points for every vector,
  both wait states, frame boundaries, PSHU/PULU, indirect EA, masked
  IRQ/FIRQ.
