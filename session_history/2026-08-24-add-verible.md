# Session: Reproducible EDA Image and SN74LS181

**Conversation chain date:** 2026-08-24 through 2026-08-25 UTC
**Capture timestamp:** 2026-08-25T15:51:31Z
**Conversation UUID:** Not exposed in the available Kiro context; this is the existing record for the current conversation chain and was updated in place.

## Goal

Create a reproducible Docker image containing xezim, Verilator, Yosys, SymbiYosys, Surfer, Verible, Z3, and the pinned UVM checkout, then use only that image to specify, implement, exhaustively verify, formally prove, synthesize, report, commit, and publish an SN74LS181-compatible 4-bit ALU.

## Work Completed

### Toolchain

1. Added pinned source revisions for Verilator 5.050, Yosys 0.46, SymbiYosys, xezim 0.10.3, Surfer 0.7.0, and Verible.
2. Pinned the Ubuntu base digest and package snapshot, Rust 1.94.0, the versioned rustup 1.29.0 bootstrap executable and SHA-256 digest, and the Verible archive checksum; retained xezim JIT support, added Surfer native dependencies, and installed Z3.
3. Bootstrapped `ca-certificates` from the signed pinned Ubuntu snapshot by disabling only APT TLS peer verification for that initial transaction; APT repository signatures and package hashes remained enforced.
4. Removed unavailable `yices2`, corrected Yosys checkout/submodules, copied the pinned UVM submodule into the image, and added SymbiYosys's `python3-click` runtime dependency.
5. Removed the inconsistent `VERILATOR_ROOT` override and changed the Docker smoke layer to fail closed for every required executable and both UVM 1.2 and 1800.2-2017 source trees.
6. Rebuilt `ai-hw-engineer:latest` successfully from the final pinned inputs and independently smoke-tested every required tool. The final image ID is `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`.
7. Added the Verible Markdown documentation set, including a version-plus-checksum update procedure; relocated the UVM usage guide from untracked submodule content to `docs/uvm/USAGE.md`.

### SN74LS181 design

1. Stored TI and Fairchild datasheets under `design/alu_74181/spec/` and maintained both active-HIGH and active-LOW functional tables in `spec.md`.
2. Corrected the selector equations and active-LOW carry/lookahead interpretation. The active-LOW table was derived as `F_low(A,B) = NOT F_high(NOT A,NOT B)` and independently checked over 4,096 logic plus 8,192 arithmetic/carry cases.
3. Wrote implementation, exhaustive test, and formal plans.
4. Implemented the combinational X/Y carry-lookahead network in `src/alu_74181.sv`, including `F`, active-LOW `Cn+4`, `P`, and `G`, plus `A=B`.
5. Added an independent 16-entry logic table, 16-entry arithmetic table, and separate X/Y group-output model in `tb_exhaustive.sv`.
6. Added an IEEE 1800.2-2017 UVM interface, item, sequence, sequencer, driver, monitor, scoreboard, environment, test, and top module.
7. Added a no-assumption formal equivalence harness, BMC/prove/cover tasks, and 10 reachability covers.
8. Replaced template scripts with deterministic lint, simulation, formal, synthesis, coverage, and complete sign-off entry points.
9. Added exact coverage and final sign-off reports.

### Final staged-diff review and remediation

1. Reviewed the complete staged diff for RTL/spec/oracle correctness, evidence honesty, Docker reproducibility/bootstrap security, command consistency, and generated artifacts.
2. The initial review found an incorrect active-LOW logic table, mutable rustup bootstrap executable, checksum-incompatible Verible update instructions, and redundant `.gitkeep` placeholders.
3. Corrected and independently checked the active-LOW table, pinned and checksummed the official versioned rustup-init executable, aligned the Verible documentation, and removed all populated-directory placeholders.
4. Removed the temporary generated review artifact rather than publishing it; the findings and remediation are retained in this session record.
5. Rebuilt the image from the remediated Dockerfile and reran independent smoke plus the full sign-off flow successfully.
6. Ran a final independent staged-diff re-review. It returned `READY` with no blocking, major, or minor findings and reconfirmed all four remediations, image identity, evidence, script modes, and repository hygiene.

## Validation Status

All final checks used image `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`. The documented fresh-container command `sh design/alu_74181/scripts/run_all.sh` passed end to end after all review remediations.

| Check | Result |
|---|---|
| Docker build from pinned inputs | PASS |
| Independent tool/version smoke | PASS, including rustup 1.29.0 and Rust 1.94.0 |
| Active-LOW table duality | PASS: 4,096 logic + 8,192 arithmetic/carry cases |
| Verilator `--lint-only -Wall` | PASS, zero warnings |
| Verible authored-source lint | PASS, zero violations |
| xezim exhaustive simulation | PASS: 16,384/16,384 vectors |
| Output-field comparisons | PASS: 81,920/81,920 |
| UVM all-mode scoreboard | PASS: 64/64 transactions; 0 errors, 0 fatals |
| SymbiYosys BMC (`abc bmc3`) | PASS, depth 1 |
| SymbiYosys proof (`abc pdr`) | PASS, converged |
| SymbiYosys cover (`smtbmc z3`) | PASS, 10/10 reached |
| Yosys generic synthesis | PASS, 0 problems, no state/latches |
| Optimized primitive cells | 82: 42 AND, 19 OR, 12 XOR, 9 NOT |
| Final semantic re-review | READY, no findings |
| Staged diff and submodule checks | PASS |

The UVM library emits 23 known false `UVM/COMP/NAME` warnings under required `UVM_NO_DPI`; its diagnostic states that this name checker requires DPI. All scoreboard checks pass and UVM errors/fatals are zero.

## Key Decisions

- Docker had to pass before design development continued, per user instruction.
- Exact source revisions and the checked-out UVM submodule were used instead of moving branches.
- The RTL follows datasheet gate equations; simulation and formal expected values use separate selector tables to avoid a correlated implementation oracle.
- The exhaustive regression covers all 14 functional input bits (`2^14 = 16,384`).
- `abc bmc3`/`abc pdr` are used for finite Boolean checking; Z3 remains the cover engine.
- A symbolic sampling stage gives BMC a state boundary without constraining any DUT functional input.
- The 82 generic Yosys primitives are not directly compared with the datasheet's approximately 75 TTL-equivalent gates because decomposition libraries differ.
- Work was moved from `main` to `design/complete-alu-74181` before publication.

## Files Added or Updated

- `Dockerfile`, `README.md`
- `docs/verible/`, `docs/uvm/USAGE.md`
- `design/alu_74181/spec/`, `src/`, `tb/`, `formal/`, `plans/`, `scripts/`, and `report/`
- This session-history record

Generated simulation/formal/synthesis work directories are ignored. The obsolete `design/alu_74181/sim.out` binary and redundant populated-directory `.gitkeep` files were removed before commit. The UVM submodule remains clean.

## Model-Call Evidence

- Model selection shown by Kiro: **Auto** (server-selected model).
- Exact model invocation count: not exposed in the available Kiro context.
- Per-model invocation counts: not exposed; no reliable count is available to record.
- Exact input/output/cache token totals: not exposed by Kiro and therefore not reported or estimated.
- Available execution evidence: the 11-item task tracker, tool command transcripts, pinned-image rebuild and smoke output, active-LOW duality check, repeated `run_all.sh` output, initial and final semantic-review results, and Git diff/status checks.

## Duration

- Prior record estimated conversation-chain start: approximately 2026-08-24T22:00Z.
- Current capture: 2026-08-25T15:51:31Z.
- Approximate wall-clock span: 17 hours 52 minutes, including user pauses, builds, validation, review, remediation, tool runs, and inactive intervals.
- Active model/tool time is not separately exposed and cannot be reported exactly.

## Publication State

Implementation, review remediation, reproducible image rebuild, final validation, and the independent staged-diff re-review are complete. The staged deliverable is `READY`; only the requested non-force feature-branch commit and push remain.
