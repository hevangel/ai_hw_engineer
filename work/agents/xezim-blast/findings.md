# xezim blast radius — 74-series testbench oracles

Date: 2026-10-28
Area: `design/ttl_74xx/tb` (1165 `*.sv`, 1161 per-chip testbenches)
Scratch: `work/agents/xezim-blast/`

## Executive summary

| Question | Answer |
|---|---|
| Total testbench files | **1165** (1161 per-chip + 4 support files) |
| (a) function + `for` + variable bit-select | **4** — `74x677`, `74x678`, `74x679`, `74x680` |
| (b) function + any `for` | **4** (same files) |
| (c) accumulator (`m &=`) inside such a loop | **4** (same files) |
| (d) `if`/`else` inside such a loop | **4** (same files) |
| Strict `!==` in the exposed class | **4 of 4** |
| Sampled testbenches failed | **1 of 10** (`ttl_74x679`) — recorded baseline, not re-run here |
| Highest-risk file beyond `ttl_74x679` | **`tb_ttl_74x678.sv`** |

The blast radius is **four files**. Every one of them is a 74x677/678/679/680
threshold comparator and every one compares with `!==`, so the suite fails
loudly rather than passing silently. No second, independent oracle style in the
library can produce this x.

## Verification status (read this first)

**No command-execution tool was available in this session.** There is no shell,
no `docker`, and no Python interpreter reachable from the tool set, so:

- `classify.py` was written but **not run**;
- **no xezim simulation was performed by me**;
- the run results quoted in section 3 are **read from the recorded full-library
  baseline** at `work/agents/baseline-library.log`, not produced now.

Everything in sections 1, 2 and 4 is static analysis that I did perform, by
exhaustive grep enumeration plus source reads. I have marked inference where it
is inference.

## 1. Oracle-style census

### Method

1. Enumerated every `*.sv` in `tb/`.
2. Listed every `function automatic` declaration in ten filename buckets
   (`74x0*` … `74x9*`, `74[0-9]*`, `74h*`, `74l*`, `74s*`). The union is
   **96 files**: 95 per-chip TBs plus `tb_exhaustive.sv`.
3. Checked for non-`automatic` functions (`function new`, `function logic`, …):
   the only hits are UVM methods in `alu_74181_uvm_pkg.sv`. No chip testbench
   has a non-`automatic` function.
4. Read one exemplar of **every distinct oracle template** and decided whether
   its function body contains a `for` loop, and whether that loop indexes a
   vector with the loop variable.

### Result

Only four testbenches put a `for` loop inside a function at all:

| File | Functions with loops | Shape |
|---|---|---|
| `tb_ttl_74x677.sv` | `ref_y`, `match_addr` | `for i=1..16`, `m &= (aa[i]==0/1)`; `aa[i] = …` |
| `tb_ttl_74x678.sv` | `ref_match`, `match_addr` | `for i=1..16`, `m &= (aa[i]==0/1)` |
| `tb_ttl_74x679.sv` | `ref_y` | `for i=1..12`, `m &= (aa[i]==0/1)` |
| `tb_ttl_74x680.sv` | `ref_match`, `match_addr` | `for i=1..12`, `m &= (aa[i]==0/1)` |

Every other function in the library is a case table or a one-line expression:

| Template | Files | Loop in function |
|---|---|---|
| 74181 datasheet case table (`reference_logic/_arithmetic/_x/_y`, `ref_logic/ref_arith`) | 3 + `tb_exhaustive.sv` | no |
| Passive-switch topology table (`reference_edge`, `reference_weak`) | 31 | no |
| Memory pattern generator (`pattern`) | 21 | no |
| Counter decode table (`table_b`) | 5 | no |
| 7-segment font table (`decode_ah`, `exp_font`, `expect_y`, `bcd_to_7seg`, `tpf`) | 9 | no |
| Register/counter next-state expression (`exp_q`, `exp_rco`, `q_exp`, `casc_exp`, `q15_exp`) | 14 | no |
| Latch read (`dataf`, `yf`, `wf`), keycode, parity, preset, element mux | 7 | no |
| Loop oracle (`ref_y`, `ref_match`, `match_addr`) | **4** | **yes** |

The loop-body scan also confirms categories (c) and (d): all four loop
functions use the accumulator `m &= …` and an `if (i <= pp) … else …` inside
the loop. `match_addr` is a write-only loop without an accumulator; `ref_*`
carries all four properties.

Cross-check: a whole-corpus grep for compound AND (`&=`) returns 13 lines in
9 files — the four comparators (two lines each) plus five open-collector
accumulators (`7453`, `74h53`, `74x23`, `74x50`, `74x55`) that sit in `initial`
blocks, not functions. Nothing else in the library accumulates.

### Non-function population

1161 − 95 = **1066 per-chip testbenches declare no function**. Their expectation
is computed inline in an `initial` block, a task, or `always_comb`, so
categories (a)–(d) are false by construction. This is why the census is exact
rather than sampled: a function-based oracle cannot exist in a file with no
function.

### Definition caveat worth knowing

The bug is documented as an *automatic function* defect, and categories (a)–(d)
are defined on functions. If the real mechanism is "automatic subroutine + loop
+ variable bit-select", then `task automatic` bodies are equally exposed and the
radius is larger: the 31 passive-switch testbenches run nested loops over
`label[port_index]` inside `task automatic check_topology`, and the memory
testbenches loop over `reference[i]`/`data_out_n` inside `task automatic check`.
Those tasks do not return an oracle value — they drive and compare directly —
so an x there would still surface as a failed check, not a silent pass. I did
not classify task bodies; this is a boundary of the brief, not a finding.

## 2. Would the suite notice?

### Operators

- `!==` (case inequality): returns 1 for any difference, including `x` versus
  `0`/`1`. An x expectation **always** trips the check.
- `!=` / `==` (logical equality): return `x` when either operand is `x`; `if (x)`
  takes the false branch, so an x expectation is **silently ignored**.

All four exposed files use `!==` and then `$fatal` on a non-zero error count:

```systemverilog
if (y !== ref_y(g_n, p, a)) begin ... errors++; end
...
if (errors != 0) $fatal(1, "tb_ttl_74x679: %0d mismatches", errors);
```

Template-level inspection of every distinct oracle style found `!==` as the
check operator throughout (comparators, 74181 case tables, memory patterns,
passive-switch topology, counter expressions, 7-segment, keycode). The only hit
from the inverted-check sweep (`if (… == …)` followed by `errors++`/`$fatal`)
is:

```
tb_ttl_74x962.sv:28:  if (q_a == q_b) errors++;
```

which asserts that two complementary outputs *differ* — a legitimate check, not
an x-tolerant pass.

**Not verified:** a machine-counted per-file operator histogram for all 1165
files. The regex sweeps that stop at 100 hits could not be completed without a
runner. `classify.py` produces it in one pass.

### The one silent path that survives `!==`

`!==` catches `x`, but not a **stale but legal** return. The 679 evidence
records both modes ("`x`, and in some cases a stale value"). If the oracle
returns the *previous* vector's expectation and that bit happens to equal the
DUT output, `!==` passes. For random data that is roughly a coin flip per
affected vector, so a stale-return bug can hide in any of the four files even
with strict compares. That is an inference from the stated failure mode, not
something I measured.

## 3. Sampled runs

I could not execute xezim. The table below is extracted from the recorded
full-library baseline (`work/agents/baseline-library.log`, 3483 checks =
1161 × lint/sim/synth; final line `3482/3483 checks passed`), which contains a
`sim` verdict for every per-chip testbench.

| # | Testbench | Family / why sampled | Recorded sim |
|---|---|---|---|
| 1 | `tb_ttl_74x677.sv` | same accumulator oracle, 16-bit | PASS |
| 2 | `tb_ttl_74x678.sv` | same accumulator oracle, 16-bit + latch | PASS |
| 3 | **`tb_ttl_74x679.sv`** | the known failure | **FAIL** |
| 4 | `tb_ttl_74x680.sv` | same accumulator oracle, 12-bit + latch | PASS |
| 5 | `tb_ttl_74x681.sv` | ALU, case-table oracle | PASS |
| 6 | `tb_ttl_74x716.sv` | counter, expression oracle | PASS |
| 7 | `tb_ttl_74x44.sv` | decoder, case-table oracle | PASS |
| 8 | `tb_ttl_74x85.sv` | magnitude comparator, inline oracle | PASS |
| 9 | `tb_ttl_74x189.sv` | memory, pattern-function oracle | PASS |
| 10 | `tb_ttl_74x16209.sv` | passive switch, table-function oracle | PASS |

**1 of 10 failed, and it is the same failure** (`FAIL sim ttl_74x679` at log
line 1811). The log carries no message text, so I cannot confirm from it that
the failure signature is the oracle x; the signature is established by the
probes already in `work/agents/`.

The three sibling comparators passing is informative: their oracle is the same
construction, so either the trigger is not reached at their vector counts
(677 ≈ 1k oracle calls, 678/680 ≈ 2.1k) or the 16-bit/12-bit latch variants
differ in codegen. 679 calls the oracle 131 072 times. That is consistent with
a rare per-call codegen fault rather than a wrong rule.

To close this gap, run:

```bash
bash work/agents/xezim-blast/run_sample.sh
```

and, for a same-scale stress of the 678 oracle:

```bash
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest \
  sh -c 'cd design/ttl_74xx && xezim --simulate --sv2017 --error-exit --max-time 100ms \
  -s tb_xezim_blast_678 src/ttl_74x678.sv ../work/agents/xezim-blast/probe_siblings_stress.sv'
```

The stress bench sweeps 2^20 vectors and reports `x_returns` separately from
`mismatches`, which is the measurement needed to tell "not triggered" from
"triggered but coincidentally matching".

## 4. Opposite risk: PASS with a broken oracle

Checks performed over `tb/*.sv`:

| Check | Result |
|---|---|
| Soft errors (`$error`, `$warning`) that would let PASS print anyway | **none** — zero matches library-wide |
| Unconditional PASS marker (no `if (errors != 0)` guard and no preceding `$fatal`) | **none found** by the sweeps below; every template read guards PASS with `$fatal` |
| `break` in a loop that could skip the checks | 3 files: `tb_ttl_74x912.sv:124`, `tb_ttl_74x913.sv:109`, `tb_ttl_74x917.sv:111` |
| `if (a == b) errors++` (inverted check) | 1 file: `tb_ttl_74x962.sv:28`, legitimate complementary-output check |

The three `break` sites are "wait until the scanner freezes on digit 1" loops:

```systemverilog
for (t = 0; t < 6 * (CPD + 1); t++) begin
    #1;
    if (digit === 6'b000001) begin ose_n = 1; break; end
    step();
end
assert (ose_n === 1'b1 && digit === 6'b000001) else $fatal(1, "failed to freeze on D1");
```

They exit early on the *success* condition and are followed by an assertion
that the condition really happened, so an early exit cannot manufacture a PASS.

`tb_ttl_74x1071.sv` / `tb_ttl_74x1073.sv` print PASS at line 14 after inline
`$fatal` checks — guarded, not unconditional.

**Conclusion:** no testbench was found that would report PASS with a broken
oracle. This is a negative result from targeted sweeps plus template reads, not
a per-file proof; `classify.py` emits `pass_unconditional_candidate` for every
file to make it exhaustive. The failure direction of this bug is a false FAIL
(red CI), not a false PASS, except for the stale-value coincidence described in
section 2.

## 5. Highest-risk file beyond `tb_ttl_74x679.sv`

**`tb_ttl_74x678.sv`.**

- Byte-for-byte the same oracle construction as 679 (`m &= (aa[i] == …)`,
  `for (int i = 1; i <= 16; i++)`, `int'(pp)`), plus a second loop function
  `match_addr` that 679 does not have.
- 16-bit A field, so the loop runs 16 iterations and the `p >= 16` alias case
  never arises — a different corner from 679's 12-bit `p >= 12` aliasing, but
  the same codegen path.
- Drives ~2 100 oracle calls (17 directed steps × 3 + 2 000 random), the
  largest oracle call count of the three passing siblings.
- Currently green in the baseline, so it is latent exposure rather than a live
  defect; it is the file most likely to turn red if the xezim fault is
  call-count or vector dependent.

Runner-up: `tb_ttl_74x680.sv` (identical structure, 12-bit, same `p >= 12`
alias domain as 679).

## 6. What remains unknown

1. **Whether 677/678/680 can trigger the fault at all.** Needs the stress run
   above; the baseline only proves they pass at their current vector counts.
2. **Library-wide operator histogram.** Template-level only; run `classify.py`.
3. **A second fault mode.** All evidence is from one binary (xezim 0.11.3,
   commit 058f2bba) on one machine; I did not test other constructs (loops in
   tasks, `always_comb` with variable selects, packed-array indexing).
4. **RTL correctness of 677/678/680.** Their oracles share the documented rule;
   only 679's rule has an independent mask-form proof
   (`work/agents/oracle_679_equiv.py`, 12-bit, 131 072 vectors). A shared
   misreading of `P >= width` for the 16-bit parts would not be caught by these
   testbenches. This is an inference, not a finding.

## Reproduction

```bash
# full per-file classification (writes inventory.generated.json)
python3 work/agents/xezim-blast/classify.py \
  --root design/ttl_74xx/tb \
  --out work/agents/xezim-blast/inventory.generated.json

# the ten-testbench xezim sample
bash work/agents/xezim-blast/run_sample.sh
```
