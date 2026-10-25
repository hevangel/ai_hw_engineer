# Protected MOVS/STOS/OUTS fault repair — 2026-10-25

Issue: [ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80).
This milestone advances the full 80286 objective; full completion is unproven.

## Implementation and oracle

Extend the protected memory-denial handling to MOVS source and destination
phases, STOS and OUTS source faults. The native repair table is in the
[integration contract](../spec/protected_mode_integration.md#movs-stos-and-outs-protected-fault-repair),
derived from Intel's original technical memos. Protected word wrap now follows
the correct reference phase through the cache checker. Real-mode paths retain
their prior dispatch. The formal register-isolation checks explicitly allow
only the documented index/count changes for these phases.

The new `tb/protected_string_replay.h` is independent of RTL decoding. It
constructs exact instruction boundaries, handler repairs and byte-level
operand expectations from the manufacturer rules. MOVS destination tests
include the completed source read and its repeated read after handler repair.
OUTS tests check actual port write bytes. The FFFF cases explicitly relocate
the operand after checking the wrapped fault state. READY-stalled runs delay
every byte request and verify all held request fields.

The old core fails the new native-state expectation. Its full source copy,
binary and diagnostic are preserved in
`work/protected_strings_red_20261025_01/`. The defect is part of the same
[escaped fault-state assumption](../../../failure_notes/2026-10-25-intel80286-ins-fault-state.md).

## Source and tools

- Core SHA-256:
  `3e2a84e8a5d417e153b3fe525ecd66e180428e3814b644fbc33c2c2258687f96`.
- CPU properties SHA-256:
  `a6ce79a5e9853f915156fbff15ce0b967fbc9b023fad23fccd6fc2f2c0c40cbd`.
- Replay binary SHA-256:
  `cf69a2a7565ef3428c40db4dfcf8cf0bf4b83f808da47aa40b45751b3737956e`.
- Verilator 5.052; g++ 15.2.0; Yosys 0.69 (`9f75ca1f9`), in the existing
  `ai-hw-engineer:latest` container with `--pull=never`.

The Intel 1987 manual was also fetched from the verified
[reference mirror](https://raw.githubusercontent.com/mbbsemu/reference-documents/main/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf)
for architectural cross-checking. Its SHA-256 is
`ad487ba99b48cd9f61b14c0fe912a04c7cdb4c7c14a18419aa9faf62d8962460`;
GitHub reports blob `df73f4e8b16a26fa87ba798d1fcdda6bd8836efb` and
27,939,701 bytes. The local PDF and extracted text remain in ignored
`scratchpad/286_references/`. The detailed fault repair expectations come from
the Intel technical memos, rather than an inferred later-x86 model.

## Commands and evidence

Run inside the tool container with this worktree mounted at `/work`:

```sh
bash design/intel_80286/scripts/run_protected_mode_replay.sh protected_strings_20261025_03
python3 design/intel_80286/scripts/run_protected_string_mutations.py \
  design/intel_80286/work/protected_strings_20261025_03/build_manifest.json \
  protected_strings_mutations_20261025_01
yosys -Q -q -l design/intel_80286/work/strings_checks_20261025_01/synthesis.log \
  -s design/intel_80286/work/strings_checks_20261025_01/synth.ys
```

From `design/intel_80286/formal`, the retained smoke configuration runs with:

```sh
sby -d ../work/strings_checks_20261025_01/bmc12 \
  ../work/strings_checks_20261025_01/checks.sby bmc
sby -d ../work/strings_checks_20261025_01/cover64 \
  ../work/strings_checks_20261025_01/checks.sby cover
```

Use fresh output directories for reproductions. Previous runs are retained.

## Results and limitations

- Replay passes all 55 cases: the prior 15 cases plus four new groups, five
  profiles and two wait modes. Profiles are byte REP, word REP last/nonfinal,
  backward word without REP, and word wrap without REP. Exact PCs, successors,
  frames, indices/count, data traffic and completed elements are checked.
- Strict Verilator `-Wall` build passes. The passing replay manifest identifies
  all 19 source/runner inputs, the compiler and binary.
- Generic synthesis passes with 28,734 cells including submodules and zero
  problems from `check -assert`.
- All ten compiled mutations are detected with their expected semantic
  diagnostic. Five retain the INS checks; five exercise wrong MOVS source
  count, lost destination-phase SI, preserved STOS DI, preserved OUTS SI and
  an early MOVS wrap fault. The manifest identifies both mutation scripts,
  the baseline and each mutated core/log.
- Depth-12 ABC BMC passes in 251 seconds. This is a shallow smoke bound.
- Cover mode reaches eight complete witnesses before its 180-second timeout.
  It starts writing a ninth VCD at step 10, but no complete witness set is
  retained for that trace. The full cover gate remains incomplete.
- All 19 replay inputs and both 21-file formal snapshots match current source
  bytes; `work/strings_checks_20261025_01/source_audit.json` retains the audit.

The scanned page-14 SCAS paragraph was rendered and inspected: it does print
SI, so the ambiguity recorded below is present in the source document and
is not introduced by its OCR transcription.

The full 24-cycle/unbounded formal gate and complete cover suite are open.
Shallow BMC does not reach the complete protected instruction/handler workload.
CMPS fault repair is still missing, and SCAS needs corroboration of the old
memo's SI-versus-DI discrepancy. IOPL faults, A20 port timing, INS DF=1
integration, privilege/task machinery, historical OS/2 CPGREP execution and
the full release runner remain open. No acceptance checkbox for the full CPU
is closed by this milestone alone.
