# Test Plan — Motorola MC68000 (work in progress)

## Primary gate: SingleStepTests vector replay

- 1,000,060 single-instruction vectors across 124 opcode files
  (`references/singlesteptests_680x0/`, fetched by
  `scripts/fetch_vectors.py`, compiled to work/sim).
- Per test: seed sparse memory with initial patches, inject the opcode
  word at PC, poke D0-D7/A0-A6/USP/SSP/SR/PC, run one instruction to
  `done_o`, compare all registers + SR + PC against the compiled final
  state, and compare every listed-final memory byte (plus assert RTL
  writes outside the final list landed on zeroed cells).
- Pass criterion: 100% of vectors for every implemented opcode file;
  per-file counters make progress measurable per landing step.

## Secondary gates (applied once the ISA is complete)

| Gate | Pass criterion |
|------|----------------|
| Lint | `verilator --lint-only -Wall` clean |
| Synthesis | Yosys generic `synth` clean |
| Formal | BMC/inductive properties on the sequencer, EA engine, exception framing (written at step 7) |

## Current measured status

- Vector harness: compiled and smoke-checked (test count, stream sizes,
  TRAP/exception vector fields verified in the compiled stream).
- RTL skeleton: lint clean (-Wall), Yosys synthesis clean.
- Opcode-file pass counters: reported by the TB once the MOVE group
  lands (next landing step).
