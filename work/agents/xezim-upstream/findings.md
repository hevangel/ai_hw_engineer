# xezim upstream identification + issue search + code-path narrowing

Task: identify the upstream project behind `xezim 0.11.3 (git 058f2bba)`, determine
whether the "automatic function returns `x` on some vectors in a long loop" failure
is a known bug, and narrow the suspected code path using xezim's own introspection.

Date: 2026-10-28. Author: upstream-identification agent.

---

## 0. Execution blocker (read first)

**I could not run xezim in this session.** The tool set available to me contains no
shell/exec surface: `tool_search` returns only the two domain skills
(`design-core-rules`, `legal-core-rules`) and there is no `bash`, `exec`, `subagent`
or `docker` tool. Every other agent instruction in the task assumed
`docker run ... ai-hw-engineer:latest sh -c '...'`.

Consequences, stated plainly:

- No `xezim -V`, no `strings`, no `--parse --dump-ast`, no `--sim-debug`, no
  `--profile`, no `--compile`, no `--max-time` sweep was executed by me.
- **Section 6 (AST/debug observations) is empty of first-hand output.** I did not
  fabricate any. What I substituted is in section 5: the introspection surface that
  the *pinned binary itself* documents, recovered from the image build log.
- Everything in sections 1-4 is either a primary web source, a workspace artifact, or
  arithmetic on a recorded vector. Each claim is tagged.

Tag legend: **[V]** verified from a primary source or a workspace artifact ·
**[I]** inference (reasoning, not observation) · **[?]** unknown / not established.

---

## 1. Project identity — [V]

| Item | Value | Source |
| --- | --- | --- |
| Upstream repo | https://github.com/aionhw/xezim | README fetched 2026-10-28 |
| Sibling repo (parser/elaboration) | https://github.com/aionhw/xezim-core | README + build log |
| License | Apache License 2.0 | README "License" section |
| Language / nature | Rust, 4-state event-driven SystemVerilog simulator | README |
| Former name | `sisSIM` (renamed in place; "behavior is unchanged") | README blockquote |
| Docs site | https://github.com/aionhw/xezim/blob/main/docs/dpi-guide.md (docs/ tree) | web search hit |

README architecture statement (quoted): the repo is "a bytecode interpreter
(this repo, binary: xezim)"; `xezim-core` is "shared library: parser, elaboration,
value, SDF, VCD sink". The simulator is described as "an event-driven VM over a
bytecode lowering of cont_assigns and always blocks".

### Pinned build provenance — [V], from `work/agents/docker-build.log`

The docker image builds xezim from source, so the exact revision is recorded:

```
#24 [xezim-build 1/1] RUN git clone --filter=blob:none https://github.com/aionhw/xezim.git /opt/xezim-src &&
    git -C /opt/xezim-src checkout --detach "058f2bba58648452e5799d17572356ebcae7d163" &&
    cd /opt/xezim-src && cargo build --release --features jit --bin xezim && ...
#24 7.980 HEAD is now at 058f2bba Refresh release benchmark figures
#24 66.91 Compiling xezim v0.11.3 (/opt/xezim-src)
#24 93.60 Compiling xezim-core v0.11.3 (https://github.com/aionhw/xezim-core.git?rev=48820a89e113df68687a10831e7051fbeb97340e#48820a89)
```

- Local `058f2bba` == upstream `058f2bba58648452e5799d17572356ebcae7d163`,
  commit subject "Refresh release benchmark figures". [V]
- Built with `--features jit` (Cranelift/wasmtime crates compiled in), but per
  `docs/xezim/native-compilation.md` the JIT is **opt-in at runtime** via
  `XEZIM_JIT=1`; a plain run stays on the bytecode interpreter. [V]
- Dependency `xezim-core` pinned at `48820a89e113df68687a10831e7051fbeb97340e`. [V]

`xezim -V` and `strings /opt/xezim/bin/xezim` were **not** run (section 0). The
identity above rests on the build log, the README, and the repo's own docs — not on
the binary banner. The local doc `docs/xezim/overview.md` independently names
`github.com/aionhw/xezim` as the source, and it is maintained in-repo.

---

## 2. Issue-tracker search — [V] for the hits, [I] for the match verdict

Repository has ~20 open issues and a large closed corpus (searches below returned
28-67 hits each). Search URLs actually fetched:

| Query | URL | Hits |
| --- | --- | --- |
| `is:issue function automatic` | https://github.com/aionhw/xezim/issues?q=is%3Aissue+function+automatic | 67 |
| `is:issue function returns x` | https://github.com/aionhw/xezim/issues?q=is%3Aissue+function+returns+x | 28 |
| `is:issue loop in function` | https://github.com/aionhw/xezim/issues?q=is%3Aissue+loop+in+function | 30 |
| `is:issue pure function` | https://github.com/aionhw/xezim/issues?q=is%3Aissue+pure+function | 14 |
| `is:issue constant fold` | https://github.com/aionhw/xezim/issues?q=is%3Aissue+constant+fold | 9 |
| open issues (all) | https://github.com/aionhw/xezim/issues | 20 |

Two further attempts (`...?q=is:issue+bytecode+function`, `...?q=is:issue+is:open+function`)
returned `fetch_content_invalid_response`; not retried more than once. So the sweep is
broad but not exhaustive — closed issues whose titles avoid the words I searched are
not covered. Distinct closed titles actually read across those five result pages: roughly
100 (the 148 hits overlap heavily).

### Verdict: no exact known-issue match — **NO** (with caveats)

None of the 20 open issues and none of the ~150 distinct closed titles I saw describe
"an automatic function returns `x`/a stale value for a small subset of arguments when
called from a loop". Open issues #592/#593 are function-related but are about
sensitivity-list inference and argument sizing, not values; #589/#587 are struct/assignment
pattern issues. This looks like an **unreported** defect at this revision.

### Near-miss precedents (all closed, but they define the machinery)

| Issue | Title (abridged) | Why it matters here |
| --- | --- | --- |
| [#413](https://github.com/aionhw/xezim/issues/413) | "Bit-select writes to static subroutine locals are lost: a static function that builds a value bit by bit returns its input (§6.21, §11.5.1)" | Closest **mechanism**. Body: "A variable like this has a **live shared cell, which every read uses, and a copy in the call frame**. A whole-variable write updates both; a select write changes only the frame copy, which the next read ignores." Also lists "compound assignments, concatenation targets and output arguments". Scoped to *static* locals; our `m` is `automatic` — but the dual-storage shape is exactly what an `x`-returning accumulator looks like. |
| [#376](https://github.com/aionhw/xezim/issues/376) | "An **inlined function's** input formal takes the actual's signedness, not its declared type (§13.5.1)" | Functions are inlined at least on some paths, and formal binding is a place where bugs live. |
| [#268](https://github.com/aionhw/xezim/issues/268) | "**Bytecode compiler** panics on **early return in a descending loop**" | Confirms `for`-loop + `return` bodies are lowered by the bytecode compiler. |
| [#278](https://github.com/aionhw/xezim/issues/278) | "**Unrolled for loop** binds a signed int loop variable as unsigned and runs zero times" | Confirms loop unrolling exists as a transformation. |
| [#146](https://github.com/aionhw/xezim/issues/146) | "**Purity walker** has no arms for while/do-while/repeat, branding loop-based **pure helpers impure**" | The single most informative issue — see section 3. |
| [#129](https://github.com/aionhw/xezim/issues/129) | "Continuous assign calling a real-returning function never compiles to bytecode" | Confirms function calls have a compiled bytecode form at all. |
| [#355](https://github.com/aionhw/xezim/issues/355) | "Unpacked arrays, queues and associative arrays of a static task or function are new on every call (§6.21)" | Storage-lifetime bugs in subroutine locals are a recurring class. |
| [#351](https://github.com/aionhw/xezim/issues/351) | "Implicitly static variables with initializers act as automatic" | Same class: wrong storage class for subroutine locals. |

The repo's own docs record two earlier xezim defects of the same *shape* — small
standalone repro does not fail, context-dependent trigger, version-pinned
(`docs/xezim/overview.md`, "Observed Discrepancies"). [V]

---

## 3. The architecture fact that reframes the symptom — [V], quoted from primary sources

From issue #146 (maintainer's own write-up):

> "the walker handles `Null / VarDecl / BlockingAssign / Return / Foreach / SeqBlock /
> If / For / Case` and then `_ => false` — so a pure function whose body uses
> `while`, `do-while`, or `repeat` ... is branded impure and **every call stays on the
> AST path**."

> "`XEZIM_COMPILE_FAIL_STATS=1` reports `1 Expr_Call_impure`, and the
> `COMPILE_FAIL_SAMPLE` shows a body whose free names are all formals/locals"

> "the compile side already handles these loops (`compile_stmt` compiles `while` with
> backward branches)"

So there are **two execution paths for a function call**: compiled bytecode (when the
purity walker accepts the body) and the AST interpreter (when it does not), gated by
`fn_is_pure_in_ext` / `stmt_ok` in `xezim-core`.

`ref_y`'s body is `BlockingAssign` + `For` + `If` + `Return`, with `VarDecl` for `m`
and `i`; its only free names are formals (`gn`, `pp`, `aa`) and locals (`m`, `i`).
**[I]** By the #146 description this body is *fully whitelisted*, so `ref_y` should be
judged pure and compiled to bytecode — not interpreted. That is a prediction the tool
can confirm in one command (`XEZIM_COMPILE_FAIL_STATS=1`), and it is the first thing
to check.

Second lever, from the pinned binary's own `--help` (captured verbatim in
`work/agents/docker-build.log`, line ~13813 ff.): **[V]**

> `--wave  Compile the model WITH waveform support ... Off by default: an active dump
> **forces loops onto the slower AST path** and builds a per-signal trace table, so a
> run that never dumps should not pay for it.`

That is a documented, tool-owned switch that moves loop execution from the compiled
path to the AST path — i.e. a free A/B test for path identity, no source edits needed.

Also from `--help`: `--sim-debug` "Enable simulator [DEBUG]/[OPT] output", and
`--verbose` emits "compile-time optimisation notes", `[FUSE]`, `[EVENT-EDGE]`, `[COV]`
counters, and `--compile`'s design summary. `--profile` prints a `[PROF]` end-of-run
report (edge-block, settle, timing counters). `--show-env-avail` prints every
`XEZIM_*` variable with a description — that is where a "force AST path" or
"disable optimisation" toggle would be discoverable. **[V]** for the option text.

---

## 4. What the recorded failure vector already tells us — [I], but arithmetically forced

Recorded line (`work/agents/pr-body-679.md:15`):

```
Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got 1 exp x
```

For that vector: `gn = 0`, `pp = 0`, `aa[12:1] = 111111111110` (bit 1 = 0, bits 2..12 = 1).

- `i <= pp` is false for every `i` in 1..12, so **all twelve iterations take the
  `else` branch**: `m &= (aa[i] == 1'b1)`.
- `aa[1] == 0` → at `i = 1`, `m = 1 & 0 = 0`; for `i = 2..12`, `aa[i] == 1` → `m &= 1`
  leaves `m = 0`. Therefore `~m = 1`, and the correct `ref_y` is **1** — which is
  exactly what the RTL produced (`got 1`).
- The reported expectation was `x`. `~m` is `x` only when `m` is `x`.

So on this vector **every input bit is known, every branch is known, and the only way
to get `x` is an `x` read of the function's own state** — either the local `m` (which
the first statement `m = 1'b1` should have made `1`) or the bits of the formal `aa`.

This rules out a whole family of candidate causes, cheaply:

- A wrong branch decision, a skipped iteration, an off-by-one in the loop bound, or an
  unrolled-loop index bug would return **0 or 1**, never `x`. Those bugs cannot produce
  this vector. (They could still explain other failing vectors.)
- A constant-folding/CSE bug would have to fold to `x` — possible only if it folded an
  uninitialised value.

The signature is **"read of a cell that was never written on this call"**, which is
precisely the shape #413 described (shared cell read vs frame copy written) and the
shape #351/#355 describe (wrong storage class / wrong lifetime for subroutine locals).

Caveat, stated as such: this reasons about the *reported* expectation value taken from
the log. It does not prove where the `x` originates inside the tool; only running the
tool can show that (section 7, step 2).

---

## 5. Introspection surface available on the pinned binary — [V], not executed

Substituting for the AST run I could not perform, here is what the pinned 0.11.3
binary documents (from its own `--help`, captured in the build log), filtered to
what would answer the questions in the brief:

| Question | Flag / env | Where documented |
| --- | --- | --- |
| How is `ref_y` represented after parse? | `--parse --dump-ast`, `--dump-tokens` | `--help` |
| Does elaboration warn about the function? | `--compile` (no simulation) + `--verbose` (design summary, optimisation notes) | `--help` |
| Is the function compiled or interpreted? | `XEZIM_COMPILE_FAIL_STATS=1`, `COMPILE_FAIL_SAMPLE` | issue #146 body |
| Any inlining / optimisation note? | `--sim-debug` (`[DEBUG]`/`[OPT]`), `--verbose` (`[FUSE]`, optimisation notes) | `--help` |
| Was the native backend used? | `XEZIM_JIT=1` is opt-in; `XEZIM_JIT_VERBOSE=1` prints compile stats | `docs/xezim/native-compilation.md` |
| Run profile (settle/edge counters) | `--profile`, `[PROF]` | `--help` |
| Force the AST path | `--wave` (documented to force loops onto the AST path) | `--help` |
| Any other internal toggle | `--show-env-avail` (lists every `XEZIM_*`) | `--help` |
| Which signal goes `x` and who drives it | `--x-warn`, `--x-warn-limit` | `--help` |
| Time-dependence vs call-count dependence | `--max-time` | `--help` |

---

## 6. AST / debug observations

**None obtained.** No `--dump-ast`, `--sim-debug`, `--profile` or `--compile` output
exists in this session, and I will not describe imagined output. Section 7 is the
exact procedure that would produce it.

For completeness: I searched the workspace for any prior capture of such output
(`grep -r 'dump-ast|sim-debug|--profile|\[OPT\]|Expr_|FunctionDecl' work/`). The only
hits are (a) the `--help` text inside `work/agents/docker-build.log`, (b) the one
mismatch line in `work/agents/pr-body-679.md`, and (c) unrelated C++ "inlined from"
compiler warnings from the Yosys/slang build stage. **No AST dump has ever been
captured in this workspace.** [V]

---

## 7. Ranked hypothesis for the code path

Ordered by how well each explains *this* vector (`x` from all-known inputs) plus the
established asymmetries (correct in a short loop; wrong once the result is compared
against the DUT output; `&=`/cast/hoisting all ruled out already).

### H1 — Automatic local `m` reads a cell that the call never writes (dual storage) — most likely

`m = 1'b1` and the twelve `m &= ...` updates go to one storage location while
`return gn ? 1'b1 : ~m` reads another, so the read sees the previous call's value or
`x`. This is the exact mechanism #413 documented for *static* subroutine locals
("live shared cell ... and a copy in the call frame"); H1 says the same split survives
for `automatic` locals on the path this testbench takes. It predicts `x` on this
vector, and predicts "stale value" on others — both observed.

Code path **[I]**: the subroutine frame/slot resolution used by the compiled call
sequence in `src/compiler/bytecode.rs` (and its frame/slot table), or the
`automatic`-local allocation in `xezim-core` elaboration that feeds it; the #413 fix
touched the select-write store path, not necessarily whole-variable writes on every
call path.

Discriminators (in order of cost):
1. `$display("m=%b aa=%b", m, aa);` immediately before `return` in `ref_y`. If `m` is
   `x` *inside* the callee at v=4094 while the same call in the short probe shows
   `m=0`, the callee's own storage is at fault → H1.
2. Change `logic m; m = 1'b1;` to `logic m = 1'b1;` (declaration initialiser). If the
   failure disappears, the plain blocking write to an automatic local is the broken
   step → H1, narrowed to one assignment kind.
3. Make the accumulator module-scope (`logic m;` at module level, function writes it).
   If the failure disappears, automatic-local storage is confirmed as the culprit.

### H2 — Formal `aa` (non-zero-based `[12:1]`) is read through a stale/partial copy

`aa[i]` unknown → `m` becomes `x` on the first `&=` with an unknown. Predicts `x` on
this vector equally well. Supported by #376 (inlined formal binding is buggy) and by
the repo's own earlier `[3:1]`/`[6:5]` port-range X report in
`docs/xezim/overview.md` (which was later found non-deterministic — relevant caveat).

Code path **[I]**: formal-to-actual binding for an inlined call with a non-zero-based
packed range, in `xezim-core` elaboration / the inliner.

Discriminator: `$display("aa=%b", aa)` as the first statement of `ref_y`. If `aa` is
partially `x` at v=4094, it is H2, and the existing zero-based-port workaround should
be tested on `aa` (`input logic [11:0] aa` receiving `a`).

### H3 — Loop lowering in the bytecode compiler (`compile_stmt` For/If) corrupts the temp

If the compiled `for`+`if/else` accumulate reads an unwritten temp when the `else`
edge is taken twelve times in a row, the result is `x` rather than a wrong 0/1.
Weaker than H1/H2 because it needs the temp to be uninitialised exactly on this shape,
but it is the path #268 and #278 both sit on, and it is the one the purity gate selects
for this function.

Discriminator: `--wave` (documented to force loops onto the AST path). If the 43
mismatches vanish under `--wave`, the compiled path is implicated → H3 (or H1 as
implemented in compiled frames). If they persist, the AST path is implicated → H1/H2.

### H4 — Native/JIT backend

Only reachable if the failing runs set `XEZIM_JIT=1` (opt-in per
`docs/xezim/native-compilation.md`). Nothing in the brief suggests they do, and the
image merely *builds* with `--features jit`. Low probability; listed for completeness.

Discriminator: check the run environment / `--show-env-avail`; re-run with
`XEZIM_JIT` unset.

### Explicitly not supported at this revision

- "Known upstream issue" — no matching report found (section 2).
- "Constant folding / CSE" — no issue, no evidence, and folding cannot invent `x`
  from known constants on this vector.
- "`&=` / `int'()` cast / hoisting into a variable" — already falsified by the probes
  in the brief (`probe_679_nocast.sv`, plain `m = m & ...`, `probe_679_exp.sv`).

---

## 8. Exact commands to run next (not executed by me)

PowerShell 7, from `B:\ai_hw_engineer`. Single-quote the `sh -c` payload.

```powershell
# 0. Identity / licence strings (the two checks I could not run)
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim -V; strings /opt/xezim/bin/xezim | grep -i -m 40 "github\|xezim\|license"'

# 0b. Every internal toggle the binary knows about
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --show-env-avail'

# 1. Is ref_y compiled or interpreted?  (decisive for H3 vs H1/H2)
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'XEZIM_COMPILE_FAIL_STATS=1 xezim --simulate -s probe_679_exp \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv'

# 2. AST shape of the function and its call site
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --parse --dump-ast -s probe_679_exp \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv > work/agents/xezim-upstream/ast_exp.txt 2>&1'

# 3. Elaboration warnings + optimisation/inline notes
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --compile --verbose -s probe_679_exp \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv 2>&1 | tail -80'

# 4. Path A/B: --wave is documented to force loops onto the AST path
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --simulate -s probe_679_exp --wave \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv'

# 5. Time vs call-count dependence
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --simulate -s probe_679_exp --max-time 200ns \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv'

# 6. Profile + debug trace
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace ai-hw-engineer:latest `
  sh -c 'xezim --simulate -s probe_679_exp --sim-debug --profile \
    work/agents/probe_679_exp.sv design/ttl_74xx/src/ttl_74x679.sv > work/agents/xezim-upstream/debug_exp.txt 2>&1'
```

Note the top module for the probes is `probe_679_exp` (no `-s` needed if it is the
only module without an instance parent, but pinning it avoids the auto-detect path).

What each outcome would mean:

- Step 1 prints a compile-fail entry (`Expr_Call_impure`, `Stmt_*`) → `ref_y` is on the
  **AST path**; H3 is demoted and H1/H2 (frame storage / formal binding) lead.
  No entry → compiled; H3 alive, and step 4 decides.
- Step 4 removes the 43 mismatches → **compiled path** is where the bug lives.
  Step 4 keeps them → **AST path**; compare its frame handling against #413's fix.
- Step 5 changes the mismatch count with `--max-time` → the trigger is simulated time /
  scheduling, not call count (cf. the `mos_6567` non-determinism note in
  `docs/xezim/overview.md`).
- Step 3 printing any `[OPT]`/inline note naming `ref_y` is the single most useful
  artifact for whoever files the issue.

---

## 9. Open questions I could not settle — [?]

1. Where the `x` enters: `m`, `aa`, or a temp. Only the `$display` probes or a debug
   trace can say.
2. Why exactly 43 of 131072 vectors, and why the failing set changes when the result is
   merely printed (`probe_679_loop.sv` passes at the same v values). Any hypothesis must
   predict the count; none of H1-H3 does yet.
3. Whether the failing set is stable across runs (deterministic) or scheduling-dependent.
   The `mos_6567` precedent in `docs/xezim/overview.md` shows this matters: a bug that
   did not re-trigger was recorded as non-deterministic rather than fixed.
4. Whether the same defect reproduces on upstream `main`. The tracker has moved on to
   #606 while the pinned binary is at `058f2bba`, so it may already be fixed on `main`;
   checking that before filing saves a duplicate.

## 10. Suggested next actions (out of scope for this agent)

- File an upstream issue only after steps 1-4 produce evidence; the tracker's convention
  is a minimal `.sv` reproducer plus a §-citation and a Verilator comparison — and this
  project's own rule (`docs/xezim/overview.md`) is to record version-pinned,
  reproducible results, not impressions.
- The local `docs/xezim/overview.md` "Observed Discrepancies" section is the natural
  home for a 0.11.3 entry once the cause is pinned; I did not touch it (tracked file,
  read-only for this task).
