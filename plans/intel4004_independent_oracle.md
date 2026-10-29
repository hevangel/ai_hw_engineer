# Plan: Independent-oracle reference models for the Intel 4004

Status: open (tracked since the 2026-10-23 review of issue #57; root cause
documented in `failure_notes/2026-09-02-intel4004-fin-pc-advance.md`,
prevention plan item 2).

## Problem

The 4004's TB instruction-set simulator (`tb/tb_intel_4004.sv`) and the
formal golden model (`formal/intel_4004_props.sv`) were both written by
re-deriving `spec/spec.md` in the same session as the RTL. They share the
RTL's decode structure, variable names, and expressions, so every check
compares the RTL against a mirror of its own reading. The FIN PC bug escaped
exactly this way, and the shared-misreading risk remains for any future
semantic subtlety (TCS/DAA escaped the same way in the 2026-09-27 round and
needed real firmware plus MAME to pin down).

Partial mitigations already in place:

- The TB now carries an **independent PC anchor**: every non-branch
  instruction's post-instruction PC is asserted from the raw fetch bus
  against the manual's documented advance rule (one word per instruction,
  two for FIM, FIN's one-word exception), with no dependency on the ISS. A
  landing the ISS mirrors still fails the anchor.
- The Busicom 141-PF manual regression (42 examples, exact tape output) is
  the real-software oracle and runs in `run_all.sh`.

## Goal

Regenerate both reference models from an external artifact so that the
tables they decode from are not co-authored with the RTL:

1. **Semantic table.** Extract a machine-readable opcode table (mnemonic,
   encoding, operand fields, cycle count, semantic rule) from an external
   source — preferred: MAME `src/devices/cpu/mcs40/mcs40.cpp` (hardware-
   validated, runs the original Busicom ROMs); cross-check rows against the
   Pyntel4004 opcode list and the scanned MCS-4 manual. Store the table as a
   checked-in data file (`design/intel_mcs4/intel_4004/spec/opc_table.*`) with the
   commit hash of the source pinned in the header, like the Busicom
   reference pins Ilmer's `chips` crate.

2. **Generated ISS.** Make the TB simulator's decode and execute paths read
   the table (generate SystemVerilog from it, or drive the checks from a
   DPI/host-side interpreter of the table). The generated model must not
   contain hand-written per-opcode expressions.

3. **Generated formal golden model.** Same table driving
   `intel_4004_props.sv`'s golden model, so formal equivalence inherits the
   independence.

4. **Regression gate.** A script (`scripts/gen_reference.py`) regenerates
   both models and diffs them against the committed versions, so a semantic
   change to RTL+models must come with a table change citing the external
   source (the FIN note's rule 2).

## Acceptance

- `grep`-level check: no opcode-specific hand-written semantics remain in
  the TB ISS or the formal golden model beyond the generated glue.
- The table's provenance (MAME commit, Pyntel4004 page, manual page) is
  recorded per opcode row where sources disagree (e.g. the manual's SUB row
  vs. the SBM equation).
- Full 4004 suite (lint, sim, formal bmc/prove/cover, synth) and the Busicom
  regression pass with the generated models.

## Non-goals

- Cycle-exact micro-operation modeling (out of scope per spec section 11).
- Replacing the Busicom real-software regression; the table and the firmware
  oracle complement each other.
