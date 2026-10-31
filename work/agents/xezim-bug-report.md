# xezim 0.11.3: miscompiled bit-select on a non-zero-based packed formal

Debugging report, 2026-10-28; updated 2026-10-29 with the Verilator cross-check and
the full reproducer listing. Tool: `xezim 0.11.3`, git `058f2bba`, upstream
[`aionhw/xezim`](https://github.com/aionhw/xezim), built from
`058f2bba58648452e5799d17572356ebcae7d163` with `--features jit` (see `Dockerfile`,
`xezim-build` stage). All results below were produced in the pinned
`ai-hw-engineer:latest` image on this host.

## Verdict

The `ttl_74x679` testbench failure is **a xezim defect, not a testbench defect and
not an RTL defect**. A side-effect-free `automatic` function that bit-selects a
parameter whose declared packed range does not start at zero can return `x` or a
wrong bit. The same rule, written so that no such select is performed, is correct
on every vector.

A 60-line reproducer with no DUT is verified failing:
`work/agents/xezim-repro/minimal_repro.sv` → **43 mismatches over 65536 vectors**.
**The same file, unmodified, under Verilator 5.052 gives 0 mismatches.**

```
# xezim 0.11.3
minimal_repro: 43 mismatches over 65536 vectors

# Verilator 5.052
minimal_repro: 0 mismatches over 65536 vectors
```

Both functions implement the identical rule; a Python transcription of the documented
per-bit rule and the mask rule agree on all 131072 vectors. So on one input space,
with one legal source file and no DUT, two tools disagree, and the tool that disagrees
with the arithmetic is xezim.

```
MISMATCH p=0 a=111111111110 got=x want=1
MISMATCH p=0 a=111111111111 got=x want=0
MISMATCH p=1 a=111111111100 got=x want=1
MISMATCH p=1 a=111111111101 got=x want=1
MISMATCH p=1 a=111111111110 got=1 want=0
minimal_repro: 43 mismatches over 65536 vectors
```

The two functions in the reproducer implement the identical rule. `ref_direct` takes
`input logic [12:1] a` and does `a[i]` inside a loop; `ref_mask` copies its zero-based
argument and tests with masks. Only the first is wrong.

## What is established

| Observation | Evidence |
|---|---|
| The failure is independent of native codegen | identical 43 mismatches with `XEZIM_JIT=0`, `XEZIM_JIT=1`, and default |
| Not the elaboration cache | identical with `XEZIM_NO_CACHE=1` |
| Not the compiled-vs-AST execution path | identical with `--wave`, which the tool documents as forcing loops onto the slower AST path |
| Not the language mode | identical with and without `--sv2017` |
| Not `&=` compound assignment | `m = m & …` still fails |
| Not the `int'(pp)` cast | `i <= pp` still fails |
| Not constant folding of the arguments | reproduced with variable actuals, no literals |
| Not X-propagation from uninitialised storage | instrumenting inside the callee shows `m=0` and `aa` fully defined at the failing vector |
| Zero-based evasions are correct | copy the formal into `logic [11:0] b` and index `b[i-1]` → 0 errors; a `[11:0]` formal with `bb[i-1]` → 0 errors |
| Mask evasions are correct | the mask oracle → 0 errors on all 131072 vectors |

The failure set is systematic rather than random: every failing vector sits on the
`P`/`P+1` boundary — the two bits that decide the comparison flip — and the returned
value is `x` in 32 of the 43 cases and a wrong `0/1` in the other 11. That signature
matches an indeterminate or misplaced read of the selected bit, not a wrong branch
decision.

## What is *not* established

I could not reduce the trigger to a single syntactic condition, and I am not going to
claim one.

- A one-line `function automatic logic f(input logic [12:1] a); return a[1]; endfunction`
  passed in most contexts I built (`probe_min.sv`, `probe_inside.sv`, `probe_pure.sv`,
  `probe_multi.sv`, `probe_scope.sv` — all correct), yet in `probe_align.sv` the same
  shape returned `x` for every input.
- Adding a `$display` inside the callee, changing where the actual is declared, and
  changing how many functions share the expression each changed the outcome in ways I
  could not stabilise.

So the defect is **context-sensitive**, which is consistent with a call-site inlining or
argument-binding decision rather than a semantic misreading of the select. The exact
condition lives in the tool's optimiser, which is a closed binary here; the upstream
maintainers have the source.

The reproducer above is deterministic across repeated runs and does not depend on any
of the ruled-out toggles, so it is a sound artifact to hand upstream even though it is
not the smallest possible one.

## Impact in this repository

Scanning all 1165 testbenches in `design/ttl_74xx/tb` for any subroutine — `function`
**or** `task` — that declares a non-zero-based packed formal gives six declarations in
five files:

| File | Subroutine | Formal | Indexed with a variable? | Result under xezim 0.11.3 |
|---|---|---|---|---|
| `tb_ttl_74x677.sv` | `ref_y` | `aa[16:1]` | yes | PASS (64 directed + 1000 random) |
| `tb_ttl_74x678.sv` | `ref_match` | `aa[16:1]` | yes | PASS (directed + hold + 2000 random) |
| `tb_ttl_74x678.sv` | `step` | `aa[16:1]` | no — forwards whole | not exposed |
| `tb_ttl_74x679.sv` | `ref_y` | `aa[12:1]` | yes | **FAIL, 43 / 131072** |
| `tb_ttl_74x680.sv` | `ref_match` | `aa[12:1]` | yes | PASS (directed + hold + 2000 random) |
| `tb_ttl_74x680.sv` | `step` | `aa[12:1]` | no — forwards whole | not exposed |

So the exposed set is exactly four subroutines in four files, all in the same
677/678/679/680 threshold-comparator family. Nothing else in the library declares a
non-zero-based packed formal, including the 31 passive-switch testbenches whose
`check_topology` tasks loop over `label[port_index]` — those index block-local and
module-scope arrays, not such a formal, so they are outside this defect.

`74x679` is the only one of the four that enumerates its input space exhaustively; the
other three sample a few thousand vectors and would only trip the defect by luck. So the
three passes are **not** evidence that those testbenches are safe — they are latent.

This also means the library's 3483/3483 pass is not proof that no oracle anywhere is
being miscompiled; it is proof that no *reachable* trigger fired on that run.

## What to do about it

1. **Workaround, already applied.** `PR #91` rewrites the 679 oracle as two masked
   compares. That removes the non-zero-based select entirely and is verified equivalent
   to the documented rule on all 131072 vectors. Nothing further is needed for the
   library to pass.
2. **Convention for new testbenches.** Oracles should copy a packed actual into a
   `[N-1:0]` local before indexing, or use a mask/compare form. This costs nothing and
   sidesteps the defect. Worth stating in `docs/xezim/overview.md` alongside the
   existing "Observed Discrepancies" entries.
3. **Upstream report.** The reproducer plus the ruled-out matrix above is the useful
   payload; the context-sensitivity is worth mentioning because it argues against a
   one-line fix. Filing it is a decision for the owner — I have not created an upstream
   issue.
4. **The other three testbenches** should stay as they are until the tool is fixed;
   converting them is optional churn, but a note in each is cheap insurance if their
   random seeds ever reach an unlucky vector.

## Reproducer source

Complete, self-contained, no DUT. Save as `minimal_repro.sv` — nothing else is
needed to see the defect.

```systemverilog
`timescale 1ns/1ps
// Minimal xezim 0.11.3 miscompilation reproducer.
//
// Two functions implement the same 12-bit address-comparator rule. They are
// exhaustively compared against each other over the whole 16-bit input space.
// `ref_direct` takes the address as a [12:1] formal and indexes it with a loop
// variable; `ref_mask` copies it into a [11:0] local and tests it with a mask.
//
// Expected on a conforming simulator: 0 mismatches.
// Observed on xezim 0.11.3 (git 058f2bba): 43 mismatches, most reporting x.
//
// Run:
//   xezim --simulate --sv2017 -s minimal_repro --max-time 500ms minimal_repro.sv

module minimal_repro;
    // non-zero-based packed formal, variable bit-select inside a loop
    function automatic logic ref_direct(input logic [3:0] p, input logic [12:1] a);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= p) m &= (a[i] == 1'b0);
            else        m &= (a[i] == 1'b1);
        return ~m;
    endfunction

    // same rule, zero-based local, no non-zero-based select
    function automatic logic ref_mask(input logic [3:0] p, input logic [11:0] b);
        logic [11:0] low;
        low = (p >= 12) ? 12'hFFF : ((12'h001 << p) - 12'h001);
        return ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    int errors = 0;
    int shown  = 0;

    initial begin
        for (int v = 0; v < (1 << 16); v++) begin
            logic [3:0]  p;
            logic [12:1] a;
            logic        got, want;
            {p, a} = v[15:0];
            got  = ref_direct(p, a);
            want = ref_mask(p, a);
            if (got !== want) begin
                errors++;
                if (shown < 5) begin
                    $display("MISMATCH p=%0d a=%b got=%b want=%b", p, a, got, want);
                    shown++;
                end
            end
        end
        $display("minimal_repro: %0d mismatches over 65536 vectors", errors);
        if (errors != 0) $fatal(1, "xezim miscompiled the [12:1] formal bit-select");
        $finish;
    end
endmodule
```

The only construct that matters is `ref_direct`'s body: a loop-variable read `a[i]`
of a formal declared `logic [12:1]`. Rewriting that read as `b[i-1]` on a `[11:0]`
local, or replacing the loop with the mask expression in `ref_mask`, removes the
failure entirely. The two functions are the same predicate over the same 12 bits, so
any disagreement is the tool's.

## Reproduce

```powershell
# minimal reproducer: expect 43 mismatches on 0.11.3, 0 on a conforming tool
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --simulate --sv2017 -s minimal_repro --max-time 500ms work/agents/xezim-repro/minimal_repro.sv'

# the original failure
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'cd design/ttl_74xx && xezim --simulate --sv2017 --error-exit --max-time 500ms -s tb_ttl_74x679 src/ttl_74x679.sv tb/tb_ttl_74x679.sv'
```

## Evidence index

| File | Contents |
|---|---|
| `work/agents/xezim-repro/minimal_repro.sv` | verified 60-line reproducer, no DUT |
| `work/agents/xezim-probe-disc.sv` | direct vs declaration-init vs zero-based vs mask, in one run |
| `work/agents/xezim-probe-iso.sv` | isolates formal range from index arithmetic |
| `work/agents/xezim-probe-dump.sv` | dumps all 43 failing vectors |
| `work/agents/xezim-probe-align.sv` | the one run where a bare bit-select returned `x` for every input |
| `work/agents/xezim-jit-matrix.ps1`, `xezim-cache-matrix.ps1` | the ruled-out toggles |
| `work/agents/xezim-upstream/findings.md` | upstream identity, issue-tracker sweep, related closed issues |

## Caveat on evidence provenance

Three of the four delegated research threads ran without shell access and therefore
produced no measurements of their own. Every number and observation above comes from
runs I executed in the pinned image; the upstream thread contributed the project
identity, the issue-tracker sweep and the list of candidate toggles, all of which I
then verified by running the binary.
