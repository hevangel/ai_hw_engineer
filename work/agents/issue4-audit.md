# Issue ai_engineer#4 — 74-series logic: audit at 2026-10-27

Baseline commit: `38b0a04` (main). Working tree has unrelated untracked work
(`design/commodore_906114/`, `system/commodore_64/`) that is **not** part of this task.

## Issue state

- `hevangel/ai_engineer#4` — "[Chip] 74-series logic", open, Status **Building**.
- Last audit comment records Path `ai_hw_engineer/design/ttl_74xx` and Start `2026-08-25`.
- 25 native physical-chip sub-issues (#248, #308–#331), **0/25 complete**, all open.
- Parent acceptance is family-wide: sourced spec + assumption ledger per member,
  synthesizable SV, independent oracle, lint/sim/formal+cover/synth, and explicit
  qualification of timing/analog/physical limits.

## Repository reality — `design/ttl_74xx/`

| Measure | Value |
|---|---|
| Catalog entries (`catalog_scope.json`) | 1393 |
| Implemented | 1161 |
| Pending digital | 165 |
| Analog/electrical exclusions | 67 |
| RTL modules (`src/*.sv`) | 1162 |
| Testbenches (`tb/*.sv`) | 1165 |
| Per-part specs (`spec/chips/*.md`) | 1393 |
| Formal tasks | 8 families / 16 tasks, plus standalone 74181 |

Latest committed evidence: 2026-10-23 — 3483/3483 per-part checks, 16/16 formal tasks.
**Not re-run since**; commit `1f59f46`/`7f5f05d` changed the Dockerfile and EDA tool paths.

## Gaps found

1. **Catalog incomplete** — 165 pending digital parts. Pending reasons show the
   dominant blocker is source access ("Datasheet not accessible", "Reference
   generic … omits the advertised function"), not tooling.
2. **Native conformance unqualified** — models are normalized digital functions.
   Native pin/timing compatibility is explicitly out of contract except where a
   per-part note says otherwise.
3. **Native member sub-issues are empty.** The 25 sub-issues link
   `design/ttl_74_series/ttl_74lsNN` on `codex/chip-family-roadmap`. That branch
   exists; **24 of the 25 folders contain only `README.md`** (`alu_74181` has 20
   files). Main superseded the layout with the consolidated `design/ttl_74xx/`
   library (commit `66d35d7`), so the sub-issue links are dead relative to `main`.
4. **Historical years** — 1160/1161 implemented parts have `introduction_year: null`.
   This is disclosed as "Unknown*" in `design/README.md`, so it is a documented
   unknown rather than a silent omission, but it does not satisfy a sourced-year
   requirement per part.
5. **Library gate is red by design** — `run_all.sh` ends with
   `inventory --require-complete`, which cannot pass while 165 parts are pending.

## Provenance defects in the implemented set

`manifest.json` does not require a `datasheet_url`, and 24 implemented parts lack one.
Five of those have a corrupted `datasheet` field that leaked Wikipedia `<ref>` text:

```
74116   title=TTL-Taschenbuch, Teil 1 |trans-title=TTL Pocket Reference, Part 1 |language=de ...
74119   1-125}}
74418   51}}
74x515  title=HCMOS-Taschenbuch ...
74x743  at=3-124}}
```

The other 19 are ABT widebus parts whose `datasheet` field is just `ABT` (a family
name, not a document), e.g. `74x16240`, `74x16245`, `74x16374`, `74x16841`.

This contradicts acceptance item 1 ("source-backed specification for every member")
and is mechanically checkable, unlike the timing/conformance gaps.

## Environment blockers

- `ai-hw-engineer:latest` was absent locally; pinned build started 2026-10-27.
  No Verilator/Yosys/SBY/xezim on the Windows host.
- `gh` CLI is **not authenticated**, so project fields (Status/Path/Agent/Start)
  cannot be written. The GitHub connector can read issues and comment but cannot
  perform `gh project item-edit`.
