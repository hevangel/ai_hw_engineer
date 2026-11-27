# Test plan: Intel 80287

| Check | Command | Oracle | Status |
| --- | --- | --- | --- |
| Lint | `scripts/run_lint.sh` | `verilator --lint-only -Wall` with `VARIANT=1` | pass |
| Shared x87 suite | `scripts/run_sim.sh` | The build host's x87 for finite arithmetic and rounding (7,680 cases, 180 square roots); original Intel ARRSUM software; directed formats, stalls, save/restore and traps | pass |
| 80287 differences | `scripts/run_sim.sh` (tb_80287_extra.hpp) | Intel 210498-005 Table 3-1, Fig. 2-2, App. B, pp. 2-15 to 2-17 | pass |
| Controller formal | `scripts/run_formal.sh` | 8087 controller properties with a numeric cut, re-run with `VARIANT=1` | see report |
| Synthesis | `scripts/run_synth.sh` | Yosys elaboration and `check -assert` | see report |

Numeric behaviour is shared with the 8087 (assumption P-A1). Until M3 there is no 80287-specific numeric evidence.
