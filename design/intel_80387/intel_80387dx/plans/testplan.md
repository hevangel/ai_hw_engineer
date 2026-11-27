# Test plan: Intel 80387

| Check | Command | Oracle | Status |
| --- | --- | --- | --- |
| Lint | `scripts/run_lint.sh` | Verilator `-Wall` with `VARIANT=2` | pass |
| Host differential | `scripts/run_sim.sh N SEED` | The build host's x87 runs the same instruction bytes from the same state | 4,140,084/4,140,084 over three seeds |
| Transcendentals | (same bench) | Host x87, same bytes; values within 8 ULP, exceptional classes exact | pass |
| Directed | (same bench) | 387PRM 4.7, App. C/D, Fig. 2-5 to 2-8 | pass |
| Original software | (same bench) | Intel ARRSUM (8087 numerics supplement, figure S-24), which runs unchanged on the 387 per App. D | pass |
| Controller formal | `scripts/run_formal.sh` | 8087 controller properties with `VARIANT=2` | see report |
| Synthesis | `scripts/run_synth.sh` | Yosys elaboration and `check -assert` | see report |

**Differential coverage.** 46 instruction forms, with operands drawn from 11 classes: normal, near one, tiny, huge, denormal, pseudo-denormal, ±0, ±∞, QNaN, SNaN, and the unsupported formats (unnormal, pseudo-zero, pseudo-∞, pseudo-NaN). All four rounding modes are used, with precision control 64/53/24 and all exceptions masked. The comparison covers ST(i) values, the full tag word, IE..PE, SF, C0–C3, TOP and stored bytes.

**Excluded by spec A1.** Bit-exact transcendental values: they are compared with an 8-ULP bound instead. Also excluded are the remainder and quotient bits of partial FPREM/FPREM1 reductions. Unmasked-exception responses are covered by directed tests and by the shared 8087 suite's trap checks; the host cannot run them without a signal handler.
