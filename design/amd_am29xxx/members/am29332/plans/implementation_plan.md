# Am29332 implementation plan

Branch `design/add-amd-am29xxx` (PR #259), worktree
`worktree/amd-am29xxx`, member folder
`design/amd_am29xxx/members/am29332/`.

1. **Oracle model first** (`scripts/generate_oracle.py`): a Python model of
   the full instruction set (124 opcodes) implementing the spec. The manual's
   worked examples are encoded as a CSV table (stimulus + expected outputs)
   and the model must reproduce every one before any RTL is written:
   - Appendix B traces: 65h × 48h unsigned multiply (7 rows), 75h / 02h
     unsigned divide (12 rows).
   - Appendix A BCD examples 1–10 (ADD/ADDC + SUM-CORR) and 11–13
     (SUB + DIFF-CORR) as operand pairs with expected nibble carries.
   - Chapter 2 worked examples: ANDF/ORF/XORF/PASSF/NOTF-A and EXTF-A/B with
     p>0, w=0 and p<0, w=0 forms; PRIOR-A byte-width-3 example.
   - `--write-table` emits `vectors/oracle.svh` (lockstep vectors with
     PASS-STAT/PASS-Q readback after every edge);
     `--check-table` re-derives every CSV expected column from the model and
     fails on any mismatch (the model↔transcription guard).
2. **RTL** (`src/amd_am29332.sv`): one module; combinational decode +
   datapath; status/Q registers on CP with HOLD gate; parity, RS/HOLD/SLAVE
   pin muxes, MSERR comparator; `ifdef FORMAL` observation signals.
3. **Verification gate** (per repo AGENTS.md): `verilator --lint-only -Wall`,
   SymbiYosys bmc/prove/cover, lockstep simulation over the full generated
   vector set (every defined opcode × all four byte widths, worked examples,
   multiply/divide/BCD algorithm sequences at width 1/2/4, HOLD windows,
   slave-compare and parity cases), Yosys synthesis `check -assert`.
4. **Reports and tracking**: `report/final_report.md`, family README row,
   design index, evidence comments on #171 and #126, project fields.

Risks: the 124-opcode decode width (one always_comb case per class);
FORMAL-friendliness (no inout tri-state reasoning in proofs — tri-state and
slave-compare logic verified in simulation; formal verifies the sequential
contract and selected combinational contracts on internal signals).
