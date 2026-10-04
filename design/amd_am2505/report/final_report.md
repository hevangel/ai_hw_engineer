# Am2505 verification report

Verified on 2026-10-03 with `sh design/amd_am2505/scripts/run_all.sh`
using the existing `ai-hw-engineer:latest` Docker image.

| Check | Observed result |
|---|---|
| Verilator RTL/testbench lint | PASS with `--lint-only -Wall`, no suppressed warnings |
| Formal BMC | PASS, combinational contract, depth 2 |
| Formal induction | PASS, unrestricted low sums/carry and documented sign wiring |
| Formal cover | PASS, all 11 covers reached |
| xezim simulation | PASS, 32,768 exhaustive slice vectors, 16,384 sign-extension checks, 40,960 actual four-chip 8x4 array cases, 0 failures |
| Yosys synthesis/check | PASS, 68 combinational cells, no storage, no reported problems |

The array exhausts every signed 8-bit X and signed 4-bit Y with five signed
K corners, in both logic polarities. Its four RTL slices use manufacturer
Figure 8 wiring; the independent mathematical oracle is signed multiply/add.
The individual slice oracle uses the manufacturer's Booth coefficients and
explicit caller carry correction, not the RTL's Boolean decode.

Tool versions: Verilator 5.052, Yosys 0.69 (`9f75ca1f9`), xezim 0.11.0
(`6558a1e`), SymbiYosys with Z3. Regenerable logs/traces are under `work/`.
No known binary omissions within the specified wiring contract.

The model promises the documented signed-extension outputs for X4 tied to
X3. Interior-slice S0-S3/Cn+4 are independent of X4. Floating electrical
pins and propagation timing are outside the binary functional contract.
