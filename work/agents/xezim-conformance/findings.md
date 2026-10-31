# 74x679 `ref_y` — conformance finding

**Question.** Is `ref_y` in `design/ttl_74xx/tb/tb_ttl_74x679.sv` legal SystemVerilog with
correct expectations, or is xezim 0.11.3 right to return `x` for 43 of 131072 vectors?

**Date.** 2026-10-28
**Scope.** Conformance of the testbench oracle only. The RTL
(`design/ttl_74xx/src/ttl_74x679.sv`) and the xezim root cause are other agents' scope.

---

## 0. Status — execution blocked, do not read this as a simulator run

**No independent simulator was executed for this report.** The execution environment
available to me this turn exposed no shell, process or container tool: `tool_search`
returned zero hits for every execution-related query (`shell`, `bash`, `docker`,
`exec`, `python`), and `tool_invoke` rejected both `shell_exec` and `run_command` with
*"only a tool a tool_search hit explicitly answers with callVia `tool_invoke` is
callable here"*. There is therefore no path from this session to
`docker run … ai-hw-engineer:latest`.

Consequently:

| Item the brief asked for | State |
|---|---|
| Verilator run of a standalone `ref_y` harness | **not run** — harness written, command given, unexecuted |
| Icarus Verilog run | **not run** — and `iverilog` is not in the image at all (§1) |
| Full 131072 sweep under a second tool | **not run** |
| Hand-computed truth for the 11 disputed vectors | **done and complete** (§4) |
| Verdict on legality and correctness of expectations | **done** (§3, §8) |

The verdict below rests on (a) exact hand arithmetic from the documented rule, and
(b) a contradiction *inside xezim's own recorded output*. Both are independent of any
simulator I could not run. A Verilator run would confirm the verdict; per the brief's
own standard it would convert "sound" into "corroborated by a second tool", and it is
still worth doing — see §6.

---

## 1. Tool inventory (verified from sources in the repo, not from a `which`)

| Tool | Present? | Evidence |
|---|---|---|
| Verilator **5.052 2026-09-05 rev v5.052** | yes | `work/agents/docker-build.log:13778` — `#36 0.543 Verilator 5.052 2026-09-05 rev v5.052` from the pinned image's own build-time sanity check |
| Yosys 0.69 (git 9f75ca1f9) | yes | `work/agents/docker-build.log:13781` |
| xezim 0.11.3, git 058f2bba | yes | shared task context; confirmed by `Dockerfile:237` PATH and `Dockerfile:262-264` |
| SBY v0.69 | yes | `work/agents/docker-build.log:13783` |
| **Icarus Verilog (`iverilog`/`vvp`)** | **no** | `Dockerfile` contains no occurrence of `iverilog`, `vvp` or `ghdl`. The only `apt-get install` package lists are `libgmp-dev` (line 134-136) and `python3-click` (line 222-224). The `PATH` set at line 237 is `/opt/verilator/bin:/opt/yosys/bin:/opt/sby/bin:/opt/yices/bin:/opt/eqy/bin:/opt/xezim/bin:/opt/surfer/bin:/opt/verible/bin:/opt/z3/bin`, and the final sanity `RUN` (line 250-275) tests exactly those tools. |
| **GHDL** | **no** | same evidence |

**Consequence:** the brief's step 4 ("if Icarus is present, do the same there") cannot be
satisfied by this image. Two-independent-tools corroboration needs a second simulator
added to the image (Icarus, or a second Verilator major revision). Note that
`verilator --lint-only` and `verilator --binary` are the *same* front end, so they are
not two independent tools — Verilator lint plus Verilator sim would corroborate
legality and simulation separately, not cross-check one simulator against another.

---

## 2. The function under test

`design/ttl_74xx/tb/tb_ttl_74x679.sv:17-25`:

```systemverilog
function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                input logic [12:1] aa);
    logic m;
    m = 1'b1;
    for (int i = 1; i <= 12; i++)
        if (i <= int'(pp)) m &= (aa[i] == 1'b0);
        else               m &= (aa[i] == 1'b1);
    return gn ? 1'b1 : ~m;
endfunction
```

Call site, `tb_ttl_74x679.sv:35-43`: `{g_n, p, a} = v[16:0]; #1; if (y !== ref_y(g_n, p, a))`,
where `v` is an `int` looping `0 .. (1<<17)-1`.

Documented rule (`design/ttl_74xx/src/ttl_74x679.sv:19-23`, `spec/chips/ttl_74x679.md`):

```
match = (A1..Ak all 0) & (A(k+1)..A12 all 1),  k = P
y     = g_n ? 1'b1 : ~match
```

---

## 3. Why `ref_y` has exactly one legal value per input — and it is never `x`

This is the whole conformance argument, and it needs no simulator.

1. **Every variable is written before it is read.** `m` is assigned `1'b1` as the first
   statement of the function body. `i` is the loop control variable. Nothing in the
   function reads a variable that was not just written. So `ref_y` is a pure function of
   `gn`, `pp`, `aa` *under any reading of the variable-lifetime rules* — the question
   "is `m` automatic or static?" never has to be answered, because `m` is overwritten on
   entry either way. (I initially intended to cite the LRM clause on automatic function
   storage here; a web search for grounding returned only forum and Scribd material, so I
   dropped the citation. The argument does not need it.)

2. **No operand can be `x` or `z`.** In the call site, `v` is an `int` assigned by a
   `for` loop counter, so every bit of `v` is 0 or 1. `v[16:0]` is a part-select of a
   fully-known value, and `{g_n,p,a} = v[16:0]` is 1+4+12 = 17 fully-known bits.
   `int'(pp)` zero-extends a known 4-bit value. `(aa[i] == 1'b0)` is a 4-state equality
   of two known bits, hence 0 or 1. `m &= …` is a 1-bit bitwise AND of 0/1 values.
   `~m` of a 0/1 value is 0/1. Therefore the result is 0 or 1 for all 131072 vectors.

3. **The constructs are all legal SystemVerilog.** Specifically: nested `for` with a
   loop-scope `int` declaration; `int'(pp)` static cast; `&=` on a 1-bit `logic`;
   a `return` of a conditional expression from a `logic`-returning function; `!==` at the
   call site (4-state case inequality); `#1` inside `initial` with a `timescale`. None of
   these is deprecated, tool-specific or ambiguous. The only lint-level complaint in this
   area is `TIMESCALEMOD` because the RTL file carries no `timescale` — a warning about
   the design file, already recorded as pre-existing in `work/agents/pr-body-679.md:67-70`,
   and not a legality defect in the testbench.

4. **`gn = 1` short-circuits to 1.** `return gn ? 1'b1 : ~m;` returns `1'b1` regardless
   of `m` when `gn` is 1. So no vector with `v[16] = 1` can legally produce anything but
   1. (All 11 disputed vectors happen to have `v[16] = 0`, so this clause is not what
   decides them — noted only because it strengthens the general claim.)

**Conclusion of §3:** `ref_y(g,p,a)` is a deterministic total function into `{0,1}` on
the testbench's input domain. Any simulator that returns `x` for it on a known input is
deviating from IEEE 1800-2017 semantics. There is no legal reading of this source under
which `exp x` is the correct expectation.

### 3a. A second, independent argument that does not depend on my arithmetic

`work/agents/pr-body-679.md:15-16` records xezim's own output:

```
Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got 1 exp x
Mismatch v=4095: g_n=0 p=0000 a=111111111111 -> got 0 exp x
```

`got` is the **RTL output** — xezim's evaluation of the `always_comb` block, which is
the same rule written as a procedural block. My hand computation (§4) gives `Y=1` for
4094 and `Y=0` for 4095. So *within a single xezim run*, the same predicate evaluated
as an `always_comb` block produced exactly the hand-computed value, while the same
predicate evaluated as a function call produced `x`. xezim contradicts itself on these
two vectors; my arithmetic sides with its RTL path. That rules out both "the RTL is
wrong" and "the testbench expectation is wrong" without needing a third tool.

Caveat on the printed `exp`: the failing branch calls `ref_y` **twice** — once in the
`!==` condition and once in the `$display` argument list. So a printed `exp x` proves
only that the *second* call returned `x`; the first call may have returned something
else. This is legal code and in a conforming simulator the two calls are identical, but
it means the log cannot by itself tell us whether the comparison failed on `x` or on a
stale 0/1. Worth knowing when reading the 43-line log.

---

## 4. Hand computation of the 11 disputed vectors

Encoding, confirmed against `work/agents/oracle_679_equiv.py:14-16`:
`g_n = (v>>16)&1`, `p = (v>>12)&0xF`, `a = v&0xFFF` with `bit0 = A1 … bit11 = A12`.

Rule applied: `A1..Ak` must be 0 and `A(k+1)..A12` must be 1, `k = p`; then
`y = g_n ? 1 : ~match`. For `p >= 12` every `i <= p` holds, so every A must be 0.

All eleven vectors have `g_n = 0` (all are `< 65536`), so `y = ~match` in every row.

| v | hex | p | `a[12:1]` | forced-low set `A1..Ap` | forced-high set `A(p+1)..A12` | violation | match | **y** |
|---|---|---|---|---|---|---|---|---|
| 4094 | 0x00FFE | 0 | 0xFFE | — | A1..A12 | A1=0, must be 1 | 0 | **1** |
| 4095 | 0x00FFF | 0 | 0xFFF | — | A1..A12 | none | 1 | **0** |
| 8188 | 0x01FFC | 1 | 0xFFC | A1 | A2..A12 | A2=0, must be 1 | 0 | **1** |
| 8189 | 0x01FFD | 1 | 0xFFD | A1 | A2..A12 | A1=1, must be 0 | 0 | **1** |
| 8190 | 0x01FFE | 1 | 0xFFE | A1 | A2..A12 | none | 1 | **0** |
| 8191 | 0x01FFF | 1 | 0xFFF | A1 | A2..A12 | A1=1, must be 0 | 0 | **1** |
| 12280 | 0x02FF8 | 2 | 0xFF8 | A1,A2 | A3..A12 | A3=0, must be 1 | 0 | **1** |
| 12284 | 0x02FFC | 2 | 0xFFC | A1,A2 | A3..A12 | none | 1 | **0** |
| 16368 | 0x03FF0 | 3 | 0xFF0 | A1..A3 | A4..A12 | A4=0, must be 1 | 0 | **1** |
| 45056 | 0x0B000 | 11 | 0x000 | A1..A11 | A12 | A12=0, must be 1 | 0 | **1** |
| 61441 | 0x0F001 | 15 | 0x001 | A1..A12 | — | A1=1, must be 0 | 0 | **1** |

Bit expansions used (LSB = A1):

```
0xFFE = 1111 1111 1110   A1=0, A2..A12=1
0xFFF = 1111 1111 1111   all 1
0xFFC = 1111 1111 1100   A1=0, A2=0, A3..A12=1
0xFFD = 1111 1111 1101   A1=1, A2=0, A3..A12=1
0xFF8 = 1111 1111 1000   A1=A2=A3=0, A4..A12=1
0xFF0 = 1111 1111 0000   A1..A4=0, A5..A12=1
0x000 = 0000 0000 0000   all 0
0x001 = 0000 0000 0001   A1=1, A2..A12=0
```

Cross-check by a different route — the mask form of the same rule
(`low[i] = (i <= p)`, `match = (a & low)==0 && (a & ~low)==~low`, cf.
`conformance_679.sv:mask_y`) gives the same column, e.g. `p=1` ⇒ `low=0x001` ⇒
`A1=0 ∧ A2..A12=1`, and `p=15` ⇒ `low=0xFFF` ⇒ `match = (a==0)` so `a=0x001` ⇒ `match=0`.

**Observation for whoever owns the root cause** (inference, not a finding): the three
vectors with truth 0 — 4095, 8190, 12284 — are exactly the unique `match=1` vectors of
the `p=0`, `p=1`, `p=2` blocks (`a = 0xFFF, 0xFFE, 0xFFC`). The eight with truth 1 are
`a`-values immediately adjacent to those patterns. A plausible mechanism is a
loop-carried or block-cached value that survives exactly where the iteration count
crosses the `i <= p` boundary, but I did not test this and it should not be relied on.

---

## 5. Results table

Legend — the provenance of each cell matters more than the number:

- **RTL y**: `rec` = recorded from xezim's own `got` field in `work/agents/pr-body-679.md`;
  `der` = hand-derived from the RTL source text, which is the same rule as §4 (the RTL
  was not simulated by me).
- **xezim `ref_y`**: `rec` = recorded; `—` = not recorded anywhere in the workspace (only
  the count "43" is recorded).
- **other-sim `ref_y`**: **no cell is filled.** Not run, per §0.

| vector | p | a[12:1] | RTL y | xezim `ref_y` | other-sim `ref_y` | hand truth |
|---|---|---|---|---|---|---|
| 4094 | 0 | 0xFFE | 1 `rec` | `x` `rec` | **not obtained** | **1** |
| 4095 | 0 | 0xFFF | 0 `rec` | `x` `rec` | **not obtained** | **0** |
| 8188 | 1 | 0xFFC | 1 `der` | — | **not obtained** | **1** |
| 8189 | 1 | 0xFFD | 1 `der` | — | **not obtained** | **1** |
| 8190 | 1 | 0xFFE | 0 `der` | — | **not obtained** | **0** |
| 8191 | 1 | 0xFFF | 1 `der` | — | **not obtained** | **1** |
| 12280 | 2 | 0xFF8 | 1 `der` | — | **not obtained** | **1** |
| 12284 | 2 | 0xFFC | 0 `der` | — | **not obtained** | **0** |
| 16368 | 3 | 0xFF0 | 1 `der` | — | **not obtained** | **1** |
| 45056 | 11 | 0x000 | 1 `der` | — | **not obtained** | **1** |
| 61441 | 15 | 0x001 | 1 `der` | — | **not obtained** | **1** |

Reading of the two fully-recorded rows: RTL agrees with hand truth (1, 0). xezim's
`ref_y` does not (x, x). On these rows the deviation is xezim's function evaluation and
nothing else. On the other nine rows only the hand truth is established; the recorded
evidence for them is the aggregate "43 mismatches".

Existing independently-produced corroboration already in the workspace, reported (not
re-run by me): `work/agents/issue4-comment.md:37-45` reports
`vectors=131072  rule_vs_mask_mismatches=0` from `work/agents/oracle_679_equiv.py`,
i.e. the documented per-bit rule and the mask form are equivalent over the whole input
space, with no simulator involved.

---

## 6. Exact commands — written, NOT executed

Harnesses (two files, so neither top drags in the other's dependencies):

- `work/agents/xezim-conformance/conformance_679.sv` — top `conf_679_func`,
  function only, no DUT, no delays.
- `work/agents/xezim-conformance/conformance_679_dut.sv` — top `conf_679_dut`,
  the committed testbench construct verbatim against the real RTL.

### Verilator 5.052 (present in the image)

Function-only sweep — the decisive one, since it isolates `ref_y` from all DUT
scheduling:

```sh
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest sh -c 'set -e
  verilator --version
  verilator --binary --timing -Wall -Wno-fatal -Wno-TIMESCALEMOD -j 4 \
    --top-module conf_679_func -Mdir work/agents/xezim-conformance/obj_func \
    work/agents/xezim-conformance/conformance_679.sv
  ./work/agents/xezim-conformance/obj_func/Vconf_679_func'
```

Expected, if the verdict in §8 is right: eleven `VEC` lines whose `ref` and `mask`
columns both equal the hand-truth column of §5, then
`RESULT vectors=131072 func_vs_mask_mismatches=0` and `PASS: conf_679_func`.

Exact-reproduction sweep (the shape xezim fails on):

```sh
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest sh -c 'set -e
  verilator --binary --timing -Wall -Wno-fatal -Wno-TIMESCALEMOD -j 4 \
    --top-module conf_679_dut -Mdir work/agents/xezim-conformance/obj_dut \
    design/ttl_74xx/src/ttl_74x679.sv work/agents/xezim-conformance/conformance_679_dut.sv
  ./work/agents/xezim-conformance/obj_dut/Vconf_679_dut'
```

Notes on the flags, so they are not cargo-culted: `--binary` makes Verilator generate,
compile and wrap a C++ model into an executable; `--timing` is required for the `#1`
delay in the `conf_679_dut` top (and harmless for `conf_679_func`); `-Wno-TIMESCALEMOD`
suppresses the pre-existing missing-`timescale` warning from `src/ttl_74x679.sv`
(`work/agents/pr-body-679.md:67-70`); `-Wno-fatal` would mask real warnings, so prefer
the targeted `-Wno-TIMESCALEMOD` and drop `-Wno-fatal` once the sweep is clean. The
built executable is `V<top-module>` inside `-Mdir`.

Cross-check with xezim on the same harness, for a like-for-like comparison:

```sh
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest sh -c 'set -e
  xezim --simulate --sv2017 -s conf_679_func --error-exit --max-time 500ms \
    work/agents/xezim-conformance/conformance_679.sv'
```

### Icarus Verilog — cannot be run in this image

If a second simulator is added, the equivalent commands are:

```sh
iverilog -g2012 -s conf_679_func -o conf_func.vvp work/agents/xezim-conformance/conformance_679.sv
vvp conf_func.vvp
iverilog -g2012 -s conf_679_dut -o conf_dut.vvp \
  design/ttl_74xx/src/ttl_74x679.sv work/agents/xezim-conformance/conformance_679_dut.sv
vvp conf_dut.vvp
```

Icarus support for `$isunknown` is not guaranteed; if it rejects the input-`x` guard,
replace `$isunknown({g_n, p, a})` with `(^{g_n, p, a}) === 1'bx`, which is equivalent
here because a reduction-XOR of a fully-known vector is known.

---

## 7. Raw output excerpts that exist in the workspace

From `work/agents/pr-body-679.md:13-18` (recorded xezim run, pinned image, xezim 0.11.3):

```
FAIL sim   ttl_74x679
Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got 1 exp x
Mismatch v=4095: g_n=0 p=0000 a=111111111111 -> got 0 exp x
...
** Fatal: tb_ttl_74x679: 43 mismatches
```

Decoding the `a` field: `111111111110` is 12 chars for `a[12:1]`, leftmost = A12,
rightmost = A1. So `a=111111111110` ⇒ A1=0, A2..A12=1 — identical to my `0xFFE`. The
log and my hex notation agree, which is a useful guard against an endianness slip in §4.

From `work/agents/issue4-comment.md:37-45` (recorded, different script):

```
vectors=131072  rule_vs_mask_mismatches=0
```

I searched for any recorded Verilator or Icarus run of `tb_ttl_74x679` or of a
`ref_y` harness and **found none** — `grep -r "Mismatch v=" work/` yields only the two
lines above plus the `.sv` probe sources, and no `sim.log` exists under
`work/library/ttl_74x679/`. So there is no pre-existing second-tool evidence to lean on.

---

## 8. Verdict

**xezim 0.11.3 deviates from IEEE 1800-2017 semantics; the testbench is legal and its
expectations are correct.**

Grounds, in descending strength:

1. `ref_y` writes every variable before reading it and operates only on 0/1 operands, so
   it is a pure total function into `{0,1}` on this input domain. `x` is not a legal
   result for any of the 131072 vectors (§3.1-3.3). This alone settles the conformance
   question without a simulator.
2. On both vectors for which xezim's own output is recorded, xezim's RTL path produces
   exactly the hand-computed truth (1 and 0) while its function path produces `x`
   (§3a, §5). The same simulator, same run, same predicate, two implementations, two
   answers — and the hand computation agrees with the RTL one.
3. The hand computation of all eleven disputed vectors from the documented rule is
   complete and self-consistent with the mask form (§4).

**What would change this verdict:** a Verilator (or any conforming) run of
`conformance_679.sv` in which `conf_679_func` reports a nonzero
`func_vs_mask_mismatches`, or in which any `VEC` line's `ref` column differs from the
hand-truth column of §5. I consider that very unlikely, but it is the test I could not
run, and the brief's standard is a second tool.

**What would *not* change it:** finding more `x` values in the 43-vector log. The count
is not the argument; the existence of a single legal-input `x` is.

---

## 9. Evidence tiers

| Claim | Tier |
|---|---|
| Tool versions; Icarus/GHDL absent from the image | **verified** from `work/agents/docker-build.log` and `Dockerfile` |
| I could not execute anything this turn | **verified** — `tool_search` empty, `tool_invoke` rejected both candidate names |
| Hand truth for the 11 vectors (§4) | **verified** — arithmetic, reproducible by hand from the table's own bit expansions |
| `ref_y` is pure and cannot legally return `x` (§3) | **verified** — from the source text |
| The testbench constructs are legal SV (§3.3) | **verified** by reading the source; *not* independently confirmed by a lint run |
| xezim's two recorded rows show RTL≠function for the same predicate | **verified** — quoted from `work/agents/pr-body-679.md` |
| `rule_vs_mask_mismatches=0` over 131072 vectors | **reported by a previous agent** in `work/agents/issue4-comment.md`; not re-executed by me |
| xezim's `ref_y` value for the other 9 disputed vectors | **unknown** — not recorded anywhere I could find |
| Any second-simulator result | **unknown** — could not run |
| Mechanism of the xezim defect (loop-carried / cached value) | **inference only**, §4 observation; not tested |
| LRM clause number for automatic function storage | **not established** — web search returned only forum/Scribd material, and the argument does not need it |

---

## 10. Out of scope, flagged for the owning agents

- Adding a second simulator (Icarus, or a pinned second Verilator revision) to
  `Dockerfile` is the only way this repo can ever satisfy "two independent tools agree"
  for oracle disputes. Verilator lint + Verilator sim is one tool, not two.
- The double `ref_y(...)` call in the failing branch (condition and `$display`) is legal
  but makes the log ambiguous about which call produced `x`; a testbench that assigns the
  expectation to a variable first would log the value the comparison actually used.
  (`probe_679_exp.sv` already does this and still shows 43 errors, so it is a
  logging-clarity point, not the defect.)
- `src/ttl_74x679.sv` has no `timescale`, which is the source of the `TIMESCALEMOD`
  warning under `--timing`. Pre-existing, unrelated to this verdict.
- The 43-vector root cause in xezim (loop-carried state, block caching, or JIT
  miscompilation of the function body) belongs to whichever agent owns the xezim
  investigation; §4's pattern note is offered as a lead, not a claim.
