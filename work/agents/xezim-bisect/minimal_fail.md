# xezim 0.11.3 — automatic-function bisect (74x679 reference model)

Topic: reduce the `ref_y()` misbehaviour in
`design/ttl_74xx/tb/tb_ttl_74x679.sv` to a minimal, DUT-free reproducer and
identify which construct is necessary.

---

## 0. Status of this document — read first

**No xezim run was executed while producing this file.** This Run had no shell
or execution tool: `tool_search` returns an empty tool catalogue (only two
domain skills), and `tool_invoke` rejects `shell` / `run_command`. So the
"Observed" column below contains only two kinds of entries:

| tag | meaning |
|---|---|
| `RECORDED` | quoted from a run recorded earlier in this workspace (source named) |
| `NOT RUN`  | planned experiment; no result exists yet |

Everything in §6 is a **hypothesis**, labelled as such. Nothing here was
verified against the binary by me.

`minimal_fail.sv` is therefore a *candidate* minimal reproducer: it is built to
be the smallest program that still contains every construct the recorded
evidence implicates, but it has not been shown to fail.

---

## 1. Recorded baseline

Command form used for every probe in this workspace:

```sh
xezim --simulate -s <top> --error-exit <top>.sv ../ttl_74xx/src/ttl_74x679.sv
```

Recorded output of the full sweep (`work/agents/pr-body-679.md`, quoting the
`ttl_74x679` sim log; the same two lines are in the task brief):

```
Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got 1 exp x
Mismatch v=4095: g_n=0 p=0000 a=111111111111 -> got 0 exp x
...
** Fatal: tb_ttl_74x679: 43 mismatches
```

`RECORDED`. 43 wrong expectations out of 131072 vectors; the RTL values on both
quoted vectors are correct (`p=0` ⇒ all A high; `v=4094` has A1 low ⇒ `match=0`
⇒ `y=1`; `v=4095` ⇒ `match=1` ⇒ `y=0`).

---

## 2. What the recorded evidence already settles

| # | Fact | Source |
|---|---|---|
| 1 | 43 mismatches over 131072 vectors, first at `v=4094`, all on the *expectation* side | recorded baseline above |
| 2 | The same function called a few times in isolation is correct | `probe_679.sv` (10 calls), `probe_679_loop.sv` (4 calls) |
| 3 | Computing the expectation into a variable first does not help | `probe_679_exp.sv` — still 43 |
| 4 | Removing the `int'(pp)` cast does not help | `probe_679_nocast.sv` — still 43 |
| 5 | `&=` versus `m = m & …` makes no difference | `probe_679_cmp3.sv` |
| 6 | A loop-free mask oracle in the same module, same call sites, is clean | `probe_679_mask.sv` — 0 errors |
| 7 | The rule and the mask form agree on all 131072 vectors, independent of any simulator | `oracle_679_equiv.py` |

Consequence: the defect is inside the function that contains the loop, and it
needs many calls to appear. Facts 3–5 remove the compound assignment, the cast,
and the "call it twice" pattern as causes. Fact 6 removes the surrounding module
topology as a sufficient cause — the mask version runs in the identical
context.

---

## 3. Minimal candidate reproducer

`work/agents/xezim-bisect/minimal_fail.sv` — no DUT, no design files. The
expected value is computed inline from the masked form that
`oracle_679_equiv.py` already proved equivalent to the documented rule over the
whole input space.

```sh
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace \
  ai-hw-engineer:latest sh -c \
  'cd work/agents/xezim-bisect && xezim --simulate -s minimal_fail --error-exit minimal_fail.sv'
```

Expected if xezim is correct: `errors=0` then `PASS: minimal_fail (131072 vectors)`.
Predicted if the bug is present: `errors=43`, first line
`Mismatch v=4094: g_n=0 p=0000 a=111111111110 -> got x exp 1`.

The four ingredients still present, and why each is kept:

1. `automatic` function, called from an `initial` loop 131072 times.
2. One input port declared with a **non-zero-based range**, `[12:1]`.
3. A `for (int i = 1; i <= 12; i++)` loop that indexes that port with the
   **variable** `i`, guarded by an `if (i <= pp) … else …`.
4. A 1-bit local accumulator `m`, initialised to `1'b1` inside the function,
   returned through `gn ? 1'b1 : ~m`.

If this file does **not** reproduce, the next-widening step is to put the
trivial DUT back (a 4-line `always_comb` computing `y` from `g_n,p,a` in the
same module) and compare against `y` instead of the inline oracle — the recorded
`probe_679_exp.sv` shows that configuration does fail.

---

## 4. Bisect matrix

Each file is a standalone top. One change per file, everything else identical
to `minimal_fail.sv`. "Observed" is `NOT RUN` for all of them.

| Axis | File | Single change | Question it answers | Observed |
|---|---|---|---|---|
| — | `minimal_fail.sv` | DUT removed, inline mask oracle | does the function break with no design present? | NOT RUN |
| 1 | `bisect_count.sv` | warm-up count searched by doubling + bisection on a fixed input | smallest failing call count | NOT RUN |
| 2 | `v_w2.sv` | port `[2:1]`, loop 1..2, same total call count | does the threshold scale with *calls* or with *iterations*? | NOT RUN |
| 3 | `v_static.sv` | `function logic` instead of `automatic` | is `automatic` required? | NOT RUN |
| 4b | `v_noif.sv` | `m &= (aa[i] == 1'b1)` only | is the `if/else` required? | NOT RUN |
| 4c | `v_count.sv` | `int c` counter, `~(c == 12)` | is a 1-bit `logic` local required? | NOT RUN |
| 4d | `v_foreach.sv` | `foreach (aa[i])` | is the C-style `for` required? | NOT RUN |
| 5 | `v_zerobase.sv` | port `[11:0]`, `i = 0..11`, `i < pp` | is the non-zero-based range required? | NOT RUN |
| 5 | `v_asc.sv` | port `[0:11]`, oracle mirrored (top bits zero) | range direction | NOT RUN |
| 5 | `v_constidx.sv` | `aa[1]` / `aa[12]` constant selects, x-only detector | is the *variable* bit-select required? | NOT RUN |
| 6 | `v_retm.sv` | `return m;`, `g_n` fixed 0 | is the ternary/inversion required? | NOT RUN |
| 7 | `v_ignoreargs.sv` | function ignores its arguments, returns `1'b1` | argument corruption vs local-state corruption | NOT RUN |
| 8 | `v_xonly.sv` | oracle-free, counts only `=== 1'bx` | are the wrong values x, or also wrong 0/1? | NOT RUN |

Reading rules for the two counters that appear in every file:

* `errors=N` — results that disagree with the independent oracle.
* `xcount=N` — results that are `x`, with **no oracle involved**. The reference
  code can never legally return `x` (all operands are 2-valued, `m` starts at 1),
  so `xcount` is corruption by definition.
* `xcount == errors` ⇒ every wrong result is `x`. `xcount < errors` ⇒ some
  results are wrong 0/1 as well (a stale or mis-selected value).

Run all of them at once:

```sh
docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace \
  ai-hw-engineer:latest sh -c \
  'cd work/agents/xezim-bisect && sh run_all.sh'
```

---

## 5. Arithmetic that constrains the answer (verified by hand, no simulator)

These are deductions from the recorded numbers, not new measurements.

* `v=4094` = `0_0000_1111_1111_1110` ⇒ `g_n=0`, `p=0`, `A1=0`, `A2..A12=1`. With
  `p=0` every A must be high, so `match=0`, `y=~0=1`. The RTL printed `1`;
  only the expectation was `x`.
* `v=4095` ⇒ all A high, `match=1`, `y=0`. The RTL printed `0`; expectation `x`.
* In the failing testbench `ref_y` is called once per iteration, so the first
  wrong result occurs on the **4095th call** — and 4095 = 2^12 − 1, matching
  both the 12-bit port width and the 12 loop iterations. Suspicious, not yet
  meaningful.
* Only 43 of ~131072 calls are wrong. So the trigger is not "everything after
  call N"; it is a per-call corruption that most vectors do not expose.
* `x` cannot be manufactured by the AND itself: `m` starts at `1'b1` and
  `(aa[i] == const)` is 2-valued for a 2-valued `aa[i]`. So `x` must come from
  either (a) `aa[i]` selecting outside the declared range `1..12`, or (b) the
  `m = 1'b1` initialisation not executing on that call. Both are single-call
  state defects, consistent with the sparsity.

---

## 6. Hypotheses (ranked, none verified against the binary)

### H1 — X-propagation from a non-zero-based function port  *(leading)*

`docs/xezim/overview.md`, "Observed Discrepancies", records exactly this class
for 0.11.0 and says the small standalone reproduction did **not** fail:

> **0.11.0, function ports with non-zero-based ranges** … a function declared
> with `input logic [3:1] mem` and `input logic [6:5] cr`, called inside a large
> `always_comb` … returned `X` in exactly the result bits derived from those
> ports, while Verilator and the oracle agreed. A small standalone reproduction
> did not fail. Workaround: declare function ports zero-based (`[2:0]`, `[1:0]`)
> and pass the slice.

`ref_y` has `input logic [12:1] aa`, indexes it with a runtime variable, and the
observed symptom is an `x` result — the same signature. The recorded context
dependence ("a small standalone reproduction did not fail", "nondeterministic,
scheduling-dependent") matches the fact that isolated calls of `ref_y` are
correct while the long loop is not.

Discriminating experiment: `v_zerobase.sv`. If it is clean, the port range is
the necessary construct and this is a re-discovery of the 6567 issue, now with a
deterministic trigger.

### H2 — call-count / tier-up trigger

Something changes state around the 4095th call: a frame allocator, a hot-call
counter, or a recompilation tier. `docs/xezim/native-compilation.md` describes
blocks being lowered to native code and cached, and
`docs/xezim/command-reference.md` lists `XEZIM_TWO_STATE`, `XEZIM_ENABLE_CACHE`
and `XEZIM_PROFILE_REPORT` knobs. An adjacent, publicly filed defect points the
same way: [aionhw/xezim#362](https://github.com/aionhw/xezim/issues/362)
("Compiled code types a typedef'd variable as unsigned, so `for (sint_t i = 3;
i >= 0; i--)` never ends") — a loop induction variable with the wrong width inside
*compiled* code. Not the same bug, but the same failure family. See §8 for the
limits of this external check.

Discriminating experiments: `bisect_count.sv` for the exact count; `v_w2.sv` to
see whether the threshold tracks calls or iterations; then re-run
`minimal_fail.sv` with `XEZIM_TWO_STATE=0`, `XEZIM_ENABLE_CACHE=0`, `--no-cache`,
`XEZIM_JIT_VERBOSE=1` and `--profile` and see whether the first failing index
moves.

### H3 — lost/aliased local frame state

`m` (and/or the induction variable `i`) is not re-initialised on some calls, so
the return value is the previous call's answer (the "stale value" in the brief)
or `x` from an uninitialised read.

Discriminating experiments: `v_static.sv` (static frame vs automatic),
`v_count.sv` (int local instead of 1-bit `logic`), `v_ignoreargs.sv` (no locals
at all). If only the automatic version with a 1-bit local fails, H3 is the
mechanism and H1/H2 explain the timing.

H1 and H3 are not exclusive: H1 names the construct that is mishandled, H3 names
what the wrong value looks like.

---

## 7. What I would report once the matrix is run

Fill in §4, then:

| outcome | conclusion |
|---|---|
| `v_zerobase` clean, everything else as recorded | necessary construct = function port with a non-zero-based range; failure = X-propagation; same root cause as `design/mos_6567` |
| `v_w2` fails at the same *call* index | trigger is call-count/tier, independent of loop length |
| `v_w2` fails only at 12 iterations | trigger is the iteration count (12 = port width) |
| `v_ignoreargs` fails | the call/argument mechanism itself is broken; no local state needed |
| `v_count` fails | accumulator width is irrelevant; it is the frame, not the 1-bit local |
| `v_xonly` count == `errors` | pure X-propagation, no stale 0/1 |

---

## 8. Provenance and limits

* No command in this document was executed in this Run (§0). The only run
  output quoted is from `work/agents/pr-body-679.md` and the task brief.
* `minimal_fail.sv`'s oracle is the masked form, not the loop form; that
  equivalence is established by `work/agents/oracle_679_equiv.py`, which sweeps
  all 131072 vectors of the documented per-bit rule against the mask rule. The
  SV golden in every file here is a line-by-line transcription of that script's
  `mask_match`/`mask_y` (`low = 0xFFF if p >= 12 else (1 << p) - 1`,
  `(a & low) == 0 && (a & ~low) == (0xFFF & ~low)`), checked by reading it — so
  a mismatch can only come from `ref_y`.
* `.sv` files here are untested by me; they are near-copies of probes that are
  known to elaborate (`probe_679_exp.sv`, `probe_679_mask.sv`), but a compile
  error is still possible and should be treated as mine, not as a finding.
* `run_all.sh` assumes `xezim` is on `PATH` inside `ai-hw-engineer:latest`
  (`/opt/xezim/bin/xezim`).
* `run.sh` is a one-line helper (`xezim --simulate -s <top> <files>`);
  `s1_nodut.sv` is a superseded first draft. Neither is part of the matrix.

### External check (web)

I searched the public tracker at `github.com/aionhw/xezim` for this signature.
`is:issue non-zero-based range function port` returned **0 results**, and
the multi-call/local-state phrasings returned nothing matching. So there is no
public issue record of *this* defect that I could find — an empty result, not
evidence that none exists. The adjacent hits I did see (`#362` compiled-code loop
variable width, `#584` variable index inside a function) are cited as context in
H2, not as proof.
