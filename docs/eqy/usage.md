# EQY Usage Guide

## Basic Invocation

```bash
eqy -f design.eqy          # partition + prove, remove work dir first
eqy design.eqy             # same, but reuse the work dir (incremental)
```

EQY reads a `.eqy` configuration file describing the two designs and the
proof strategy, then drives Yosys (and optionally SBY) to prove every
collected group equivalent. Output lands under `work/` next to the config;
pass `-d <dir>` to relocate it.

## The .eqy File

| Section | Purpose |
|---------|---------|
| `[options]` | Global options (left empty in most configs) |
| `[gold]` | Yosys script reading the known-good design (`read -formal`/`read_verilog -sv`, `prep -top <top>`) |
| `[gate]` | Yosys script reading the design under test (often `synth -top <top>` for RTL-vs-netlist checks) |
| `[collect *]` | Grouping rules applied to both designs: `group <pattern>` (same name must exist in both), `join <pattern>` (merge matching cells into one group), `match <gold> <gate>` (pair differently named cells) |
| `[strategy <name>]` | Proof engine for the groups it matches; `use sat` runs the solverless Yosys SAT engine (with its own `depth N` bound), `use sby` runs a SBY task (uses the image's SBY + z3/yices) |

Minimal RTL-vs-synthesis check (from upstream's `examples/simple`):

```text
[options]

[gold]
read_verilog counter.sv
prep -top counter

[gate]
read_verilog counter.sv
synth -top counter

[strategy simple]
use sat
depth 10
```

Run it: `eqy -f counter.eqy` — every group prints `PASS`/`FAIL`, and EQY
exits nonzero if anything failed or was left unproved. A counterexample
VCD is written under the work dir for `FAIL` groups.

## Worked Example: Prove a Refactor Equivalent

```text
[gold]
read_verilog -sv nerv.sv
prep -top nerv
memory_map

[gate]
read_verilog -sv nerv_change.sv
prep -top nerv
memory_map

[collect *]
group regfile*
join imm_*
join insn*

[strategy sby]
use sby
engine smtbmc z3
depth 20
```

`group` proves identically-named logic together without re-analysis;
`join` merges matched cells into one proof unit. The famous
SHIFTER_BUG (one extra address bit in the shift amount) is caught as a
`FAIL` with a counterexample — an LEC setup that can only answer PASS is
not trustworthy, so break a design on purpose once and confirm the FAIL
lands.

## Strategies

- `use sat` — Yosys' built-in SAT solver; no external solver needed.
  Best for small/medium combinational and shallow-sequential groups.
- `use sby` — full SBY task per group; use for deep sequential groups.
  Engines and options follow the `[engines]`/`[options]` sections of an
  `.sby` file; the image provides `z3` and `yices` SMT solvers.

Depth (`depth N`) bounds how many cycles of sequential equivalence are
proven; unbounded sequential equivalence needs an induction-friendly
`[collect]` grouping or the sby strategy with `mode prove`.

## In This Repo

- Formal property proofs (does design X satisfy spec S): see
  [SymbiYosys](../yosys-symbiyosys/) and each design's `formal/` suite.
- Equivalence proofs (is design X == design Y): this tool. Useful when
  touching shared RTL or synthesis scripts — regenerate the netlist and
  LEC it against the previous golden.
