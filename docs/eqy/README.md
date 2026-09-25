# EQY (Equivalence Checking with Yosys)

## What It Is

EQY is a formal equivalence checking (LEC) driver from YosysHQ: it proves
that two designs — a known-good "gold" design and a "gate" design — are
functionally equivalent, or produces a counterexample showing input
sequences where their outputs differ. Typical uses:

- **RTL vs post-synthesis netlist**: prove a synthesis run introduced no
  functional changes.
- **Refactor vs original**: prove a hand refactor (e.g. extracting a shared
  shifter) preserves behavior in all conditions.
- **Optimization validation**: prove a local rewrite or new pass preserves
  behavior before adopting it.

EQY partitions both designs into cells, groups them by name and structure
(`[collect]`), and proves each group equivalent with a strategy — the pure
Yosys `sat` engine (no external solver), or SBY-based strategies that use
the image's SBY + z3/yices stack.

In this repo EQY complements the per-design formal suites in
`design/<chip>/formal/`: SBY proves *properties about one design*, EQY
proves *two designs equal to each other*.

## In Our Docker Image

EQY is built from source in the `eqy-build` stage, pinned to
`EQY_REV` in the `Dockerfile`. Its strategies are Yosys plugins
(`eqy_combine.so`, `eqy_partition.so`, `eqy_recode.so`), so per upstream's
install guide they are compiled against the exact Yosys build they run
with — the stage descends from `yosys-build` and installs via
`yosys-config --build` into `/opt/eqy`.

The image also ships `yices2`, EQY's preferred SMT solver (and the checker
SBY uses to validate abc-engine counterexamples).

## Facts

- Source: <https://github.com/YosysHQ/eqy>
- Docs: <https://eqy.readthedocs.io> (sources in the repo under `docs/`)
- License: ISC-style permissive (see `COPYING` in the repo)
- Upstream tags name the oldest confirmed Yosys release (`yosys-0.47` at
  pin time); we pin HEAD and pair it with Yosys HEAD, verified by an
  in-image LEC smoke test at build-PR time.

## In This Folder

- [Usage Guide](usage.md) — `.eqy` file format, strategies, worked examples.
