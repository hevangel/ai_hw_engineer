# PCE-286 oracle loop

A repeatable loop for finding and fixing 80286 protected-mode defects by
comparing the RTL with the PCE-286 emulator (`external/pce-286`, pinned
submodule). It is written so that an agent can run it unattended.

## What it compares

`scripts/pce_oracle_scenarios.py` generates memory images (scenarios). Each
is run from RESET by two programs:

- `tb/pce_oracle/pce286_oracle.c`: the PCE-286 CPU core, built from the
  submodule.
- `tb/pce_oracle/replay.cpp`: `intel_80286` under Verilator.

`scripts/pce_oracle_run.py` then requires, per scenario, the same
architectural state at every instruction boundary (CS, IP, defined FLAGS
bits, the eight registers, ES/SS/DS, MSW, halt/shutdown state), the same
port writes, and the same final value of every written memory byte. The
memory check covers stack frames, error codes, TSS images, and descriptor
accessed and busy bits.

Every IDT vector `v` points at `0038:(4*v)`, a single HLT. A final
`cs=0038 ip=4v+1` therefore means "vector v was delivered"; the report prints
it as `vector v`.

## Commands

Run inside the tool image, from `design/intel_80286`, with the submodule
fetched (`git submodule update --init --checkout --depth 1 external/pce-286`).
Give each concurrent run its own evidence directory.

```sh
export INTEL_80286_WORK_DIR=$PWD/work/<your-run-name>
sh scripts/run_pce_oracle.sh                    # all scenarios
sh scripts/run_pce_oracle.sh -k 'tasks.*'       # one family or pattern
```

Outputs under `$INTEL_80286_WORK_DIR/pce_oracle/`:

- `report.txt`: totals per family and mismatch groups, largest first.
- `mismatch/<scenario>.txt`: first differing boundary (oracle and RTL state,
  RTL event vector and error code) and differing memory bytes.
- `scn/<scenario>.scn`, `trace/<scenario>.oracle`, `trace/<scenario>.rtl`.

The script exits 1 while any unwaived mismatch remains.

## The loop

1. Run the family you own. Pick the largest mismatch group.
2. Read one `mismatch/*.txt` from the group, the scenario's generator code,
   and both traces. Work out which instruction diverges and why.
3. **Classify before changing anything.** PCE-286 is a third-party emulator,
   not ground truth. Decide which of these applies, using Intel 210498-005
   (Appendix B instruction pages, Tables 7-4, 8-1, 8-2, chapter 9) first and
   86Box (`external/86box/86Box/src/cpu/x86seg.c`, `386_common.c`, `808x.c`)
   as a second opinion:
   - **RTL defect**: Intel's text supports the oracle. Fix `src/`.
   - **Oracle defect or undefined behavior**: Intel's text supports the RTL,
     or does not define the case. Do not change the RTL. Add a waiver.
   - **Scenario defect**: the scenario does not test what its name says, or
     depends on something neither side should define. Fix the generator.
   - **Harness artifact**: a reporting difference with no architectural
     meaning. Fix the driver or comparer, and say why in a comment.
4. For an RTL fix: change the smallest piece of logic that explains the whole
   group, rerun the family, then rerun everything to check for regressions.
   Agreement with PCE alone is not a reason to change RTL that an Intel table
   or a physical capture already pins.
5. Repeat until the family has no unwaived mismatch.

## Waivers

`tb/pce_oracle/waivers.json` is a list of
`{"match": "<fnmatch on scenario name>", "reason": "...", "source": "..."}`.
`source` must name the Intel page/table, physical capture or 86Box location
that justifies it. Keep patterns narrow. A waiver is a recorded disagreement
with the oracle, not a pass.

## Rules

- Follow `AGENTS.md`, in particular the escaped-defect rules: any behavior
  Intel does not state gets an `ASSUMPTION:` comment and a spec entry; no
  fault rule may be invented from a "must be zero for 80386" note.
- Do not copy PCE or 86Box source into this repository (both are GPL-2.0).
  Read them, and describe behavior in your own words.
- Do not weaken the comparer (masks, skips) to make a mismatch disappear.
  A new mask needs the same justification as a waiver.
- Every RTL fix needs a line in the run's findings list: scenario group, old
  and new behavior, Intel citation, and the scenario names that now agree.
- Before the work is called done: strict lint
  (`verilator --lint-only -Wall --top-module intel_80286 src/*.sv`) and
  `scripts/run_sim.sh` must pass. Existing directed tests that encoded the
  old behavior are updated with the citation, never deleted silently.
- Extending coverage is part of the job: add scenarios for neighbouring
  cases (other CPLs, rings 1 and 2, LDT selectors, expand-down segments)
  when a fix suggests them.

## Limits

- No external interrupt, NMI or single-step scenarios yet: aligning their
  timing between an instruction-stepped emulator and the RTL needs a
  boundary-indexed injection scheme.
- No 80287 model on either side; `npx_msw` covers only the MSW-controlled
  exception 7 decision.
- Bus-cycle order and timing are not compared.
- Undefined FLAGS results are not masked per instruction; scenarios avoid
  instructions that leave flags undefined.
