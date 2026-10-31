## Close-out assessment — 2026-10-29

Three PRs are open against `hevangel/ai_hw_engineer`, all clean and non-conflicting. Together they close the evidence and provenance workstream; **the issue itself cannot be closed**, and this comment says exactly why.

### PRs awaiting review

| PR | What it does |
|---|---|
| [#91](https://github.com/hevangel/ai_hw_engineer/pull/91) | Rewrites the `74x679` oracle as a mask form (RTL untouched), and stamps Verilator/Yosys/SBY/xezim versions into the regenerated report |
| [#92](https://github.com/hevangel/ai_hw_engineer/pull/92) | Backfills manufacturer sources for 24 implemented parts, cleans 7 more corrupted entries, adds the `check_provenance.py` gate |
| [#93](https://github.com/hevangel/ai_hw_engineer/pull/93) | Records the underlying xezim defect in `docs/xezim/overview.md` with a runnable reproducer |

Merged pairwise and re-tested in a scratch worktree:

```
Inventory OK: 1161 models, 165 pending digital parts, 67 analog exclusions
Provenance OK: 1161 implemented entries each have a datasheet_url or a provenance_gap
PASS sim   ttl_74x679
PASS lint  ttl_74x679
```

I have not merged any of them: `AGENTS.md` requires human review before `main`, so that call is the owner's.

### Acceptance matrix

| Acceptance item | State | Evidence |
|---|---|---|
| Source-backed specification and assumption ledger for every member | **Partial** | 1393 specs exist and every implemented entry now has a datasheet URL *or* an explicit `provenance_gap`. 16 parts gained a verified TI datasheet; 8 remain genuinely unsourced and say so. Introduction years are still unestablished for 1160 of 1161. |
| Implementation plan and synthesizable SystemVerilog | **Partial** | 1161 / 1393 catalog entries implemented; 165 pending digital parts have no model and no stub. |
| Independent oracle; real historical software and exact PC checks for CPUs | **Not applicable, in part** | These are logic devices, not CPUs, so the CPU clause does not bind. Independent oracles exist per part, and the `74x679` oracle is now cross-checked against Verilator. |
| Lint, simulation, formal proof plus reachable covers, synthesis, and honest result report | **Met for the implemented subset** | 3483/3483 lint+sim+synth checks, 16/16 formal check/cover tasks, 74181 exhaustive/UVM/formal flows. The report now names the toolchain, so the numbers are reproducible. `run_all.sh` still exits nonzero at its `--require-complete` gate by design. |
| Native timing, analog approximations and physical validation explicitly qualified | **Met** | Per-part conformance limits are listed in the library report; 67 analog/electrical parts are excluded with per-part reasons; native timing is out of contract and stated as such. |

### What the tool investigation changed

The `74x679` failure was a **xezim miscompile**, not a testbench bug: an `automatic` function that bit-selects a packed formal whose range does not start at zero can return `x` or a wrong bit.

```
xezim 0.11.3:  43 mismatches over 65536 vectors
Verilator 5.052, same file: 0
```

It is deterministic, and `--wave`, `XEZIM_JIT`, `XEZIM_NO_CACHE` and `--sv2017` make no difference. It is the same class as the `mos_6567` entry previously written off as nondeterministic, so `docs/xezim/overview.md` now cross-references it and the zero-based workaround is evidenced rather than cautious.

**Version re-check:** 0.11.3 is the latest release and is already the pin. I also built `main` at `0fca605f` (154 commits past the tag, 2026-10-29) and re-ran the reproducer — still 43 mismatches. The Dockerfile pin is therefore unchanged rather than moved onto an unreleased commit that does not fix it.

Blast radius inside this repository: 4 subroutines in 4 testbenches (677, 678, 679, 680). Only 679 enumerates exhaustively; the other three pass on random vectors and are latent.

### Why the issue stays open

The remaining work is not documentation or evidence:

- **165 pending digital parts**, all source-blocked — DRAM controllers, EDAC, JTAG/boundary-scan, NuBus, cache comparators, FPUs and clock synthesizers. Each needs a primary-source study; none has a stub.
- **25 native member sub-issues**, 0/25 complete. 24 of the 25 member folders on `codex/chip-family-roadmap` contain only `README.md`, and `main` superseded that layout with `design/ttl_74xx`.
- **1160 implemented parts with no sourced introduction year**, disclosed as `Unknown` in `design/README.md` but still not satisfying a per-part sourced-year requirement.

Status stays `Building`, Agent stays `GLM`, Path and Start (`2026-08-25`) unchanged. I am not marking `AI verified` at parent level: two of the five acceptance items are partial and one is only partly applicable.

### Suggested next increment

Either take one pending cluster with obtainable primary sources (the `74x848`/`74x852`/`74x856` transceiver-controller group records "datasheet not yet pulled", which is a weaker blocker than "not accessible"), or retire the 24 empty member folders in favour of an explicit pointer to `design/ttl_74xx` so the sub-issues stop tracking an abandoned structure. Both are scoped; neither is done here.
