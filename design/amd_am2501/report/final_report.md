# Am2501 verification report

Verified on 2026-10-03 using the existing `ai-hw-engineer:latest` image.
`sh design/amd_am2501/scripts/run_all.sh` passed. After extending the
synthesis script to explicitly build both packages, `run_synth.sh` also
passed for six-CE and two-CE configurations.

| Check | Observed result |
|---|---|
| RTL lint | PASS, `verilator --lint-only -Wall` for CE_INPUTS=6 and 2 |
| Testbench lint | PASS, `--lint-only -Wall --timing`, no suppressed warnings |
| Formal BMC | PASS, depth 24 on both packages |
| Formal induction | PASS, unbounded equivalence to manufacturer's state-table oracle on both packages |
| Formal cover | PASS, all four covers reached on each package |
| xezim simulation | PASS, 196,609 pair checks; 65,536 exhaustive transitions checked for both packages; 131,087 four-chip look-ahead cascade checks; 0 failures |
| Yosys synthesis/check | PASS for both packages; four enabled flip-flops, no latches, `check -assert` reports no problems |

The cascade runs cover a complete 16-bit traversal and wraparound in both
directions with physical TC-to-CE wiring, plus inhibit and preset scenarios.
Controls are changed in the manufacturer's required CP-HIGH window.

Tool versions: Verilator 5.052, Yosys 0.69 (`9f75ca1f9`), xezim 0.11.0
(`6558a1e`), SymbiYosys with Z3. Reproducible logs and traces are generated
under ignored `work/`. No unresolved binary functional defects or omissions.

Scope includes both documented package enable counts and the complete binary
state diagram. Original timing restrictions remain caller obligations; no
power-up state or reset pin is invented.
