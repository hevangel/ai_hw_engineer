# Am9300 verification report

Verified on 2026-10-03 with the existing `ai-hw-engineer:latest` Docker image.
Command: `sh design/amd_am9300/scripts/run_all.sh` from the repository root.

| Check | Observed result |
|---|---|
| Verilator RTL and testbench lint | PASS with `--lint-only -Wall`; no suppressed lint warnings |
| Formal BMC | PASS, depth 32, unrestricted physical CP/MR after initial clear |
| Formal induction | PASS, unbounded DUT/original case-table oracle equivalence |
| Formal cover | PASS, all five covers reached (steps 3, 3, 4, 4, 10) |
| xezim pin-level simulation | PASS, 10,498 checks, 2,048 exhaustive transitions, 32 asynchronous reset cases, 64 cascade shifts, 0 failures |
| Yosys generic synthesis/check | PASS, four asynchronous-clear flip-flops, five muxes, one inverter; `check -assert` reports no problems |

Tool versions: Verilator 5.052, Yosys 0.69 (`9f75ca1f9`), xezim 0.11.0
(`6558a1e`), SymbiYosys with Z3. Logs and witnesses are retained under
ignored `work/`; the scripts regenerate them.

The first cover run exposed an observation-step error in the toggle witness.
The harness was corrected to sample the output on the CP transition and
require stable control levels on both sides; no RTL or specification change
was needed. All tasks then passed in the complete regression.

Scope: all documented binary functions and pin polarities; analog timing,
loading, and metastability are outside the functional reconstruction.

No known binary functional omissions or unresolved implementation issues.
Power-up without MR remains unspecified, matching the manufacturer contract.
