# Family-layout consolidation and Java EDA environment

Validation date: 2026-10-29. Branch merge base `4612e2c`; `main` at merge time `52e8cfa` (75 commits ahead of the branch).

The migration moves 22 chip folders under six canonical family roots and folds the 74181 into the existing 74-series catalog, preserves shared RTL implementations, gives identified physical package profiles member folders and native sub-issues, and updates source lists, system references, indexes and generated-output ignores. The numbered 74-series library is *not* split into per-part folders: `main` had already consolidated every implemented 74xx number into the single `design/ttl_74xx/` catalog before this branch landed, so that catalog stays the one home for 74-series RTL. `scripts/design_families.json` records the `families`, the TTL `catalogs` and the old/new `moves`.

## Resulting layout

| Family root | Members |
|---|---|
| `design/amd_am25xx/` | Am2501, Am2505 |
| `design/amd_am29xx/` | Am2901, Am2902, Am2903, Am2904, Am2909, Am2910, Am2911, Am2913, Am2914, Am2918 |
| `design/intel_mcs4/` | 4001, 4002, 4003, 4004 |
| `design/intel_mcs8/` | 3205, 3404, 8008 |
| `design/intel_8086_8088/` | 8086 |
| `design/mos_6502_family/` | 6502, with the physical-bus variant nested as `mos_6502/cycle/` |

The two NMOS 6502 implementations share the 6502 member issue and the cycle model is nested under that chip, so its relative links are one level shallower than the old sibling folder. The parameterized 8253/8254 RTL remains shared with its existing member folders. Apple II package RTL remains shared and is referenced from individual member folders; a generic mask-ROM model is not assigned a fabricated part identity.

The numbered 74-series parts keep one catalog folder, `design/ttl_74xx/`, which owns the RTL, formal, testbench and launch scripts for every implemented part, including the 74181 (`src/alu_74181.sv`, `formal/`, `scripts/run_74181_*.sh`, `README_74181.md`, `spec/74181.md`). The physical 74LS packages that the Apple II board actually used keep member profiles under `design/ttl_74xx/members/`, linked from `members/README.md`; no RTL is copied into member folders.

## Conflicts resolved against current `main`

1. **Duplicate 74181 tree dropped.** The branch carried `design/ttl_74_series/alu_74181/`, a second copy of the pre-consolidation design. `main` owns the same RTL once, in `design/ttl_74xx/`; the branch copy was removed rather than landing two implementations of one chip.
2. **Branch-only TTL family folder retired.** `design/ttl_74_series/` no longer exists. Its 24 per-part member profiles were moved to `design/ttl_74xx/members/<part>/` and its family index became `design/ttl_74xx/members/README.md`, so the issue-tracking intent survives without a parallel folder tree.
3. **New `main` files inside moved directories were relocated.** 21 files that `main` added under `design/mos_6502/` after the branch was cut (native-engine formal, plans, report, scripts, spec, `src/mos_6502_native.sv`, testbenches) now live under `design/mos_6502_family/mos_6502/`.
4. **References in newer `main` files were rewritten.** `system/commodore_64`, `system/nes`, `system/apple_ii` (timing simulation), `system/scelbi_8b` (scripts, spec, report), the 6560 and 2A03 reports, and the 6507/6510/6526/6530/6560 sibling launch scripts pointed at the old flat paths.
5. **Broken absolute links fixed.** All 31 new member profiles (24 TTL, 7 Apple II) carried absolute Windows paths (`../B:\...\design\...`) written by the branch; every link now resolves relatively in a fresh checkout.
6. **Historical logs kept.** `session_history/` keeps `main`'s text: those notes describe sessions that ran under the pre-consolidation paths, so rewriting them to a path that did not exist at the time would falsify the record.
7. **Stale conflict block removed.** `design/ttl_74xx/report/final_report.md` carried a committed conflict block from an earlier merge; it now contains the single correct command.

## Checks recorded

All commands below were run in this worktree on 2026-10-29.

- `python -m unittest discover -s scripts -p test_design_families.py` — 5 tests pass: family/member indexes, catalog member profiles, old-root removal, static `design/...` source references, and the Am2911 cross-member formal inputs.
- `bash -n` over 493 shell scripts inside `ai-hw-engineer:latest` — no syntax failures. Six project/system scripts had been checked out with CRLF and could not run in the Linux image; `.gitattributes` now pins `scripts/*.sh` and `system/**/scripts/*.sh` to LF, matching the existing `design/**/scripts/*.sh` rule.
- Markdown link check over the 218 changed `.md` files — 7 unresolved targets, all present on `main` before this merge and unrelated to it: the `intel_80286` index row (branch not merged), `intel_8275/references/intel_8275.pdf` (not committed), a `../../system/nes/` link in the 2A03 specification, and four links into the untracked `references/` download-cache manifests.
- Relocated Am2501 full flow (`design/amd_am25xx/amd_am2501/scripts/run_all.sh`) inside `ai-hw-engineer:latest` — lint, formal, simulation and synthesis all passed.
- Lint passed for the relocated `mos_6502` (`design/mos_6502_family/mos_6502/scripts/run_lint.sh`), the 74181 (`design/ttl_74xx/scripts/run_74181_lint.sh`), `system/scelbi_8b`, `mos_6507`, `mos_6510`, `mos_6530` and `ricoh_2a03`.

Not rerun by this merge: the full Docker image rebuild, the remaining AMD complete flows, the TTL library-wide `run_all.sh`, the 6502 native-engine flow, and firmware/network-dependent system acceptance. Existing per-design reports remain the record for their original scope; nothing here is a new human or physical sign-off.

## Pre-existing defect found while verifying

`scripts/update_docker.py` on `main` does not compile: `IndentationError` at line 94 (a duplicated `request()` body left by merge commit `49c1bf6`). Because of it, `test_update_docker.py` cannot import and the toolchain-updater unit tests cannot run. The file is untouched by this merge and needs a separate fix.
