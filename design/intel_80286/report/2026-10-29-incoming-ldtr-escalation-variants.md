# Incoming-LDTR selector variants through double-fault delivery

**Date:** 2026-10-29 02:38 UTC  
**Branch/worktree:** `design/intel-80286` in
`B:\ai_hw_engineer\worktree\intel-80286`.  
**Reference:** Intel 80286 Programmer's Reference Manual, order 210498-005,
Table 8-1 rows 4–5, printed page 8-6 (PDF page 156). The table was captured
and visually checked with `playwright-cli`; see the
[page-156 screenshot](../work/incoming_ldtr_escalation_variants_20261029_21/table-8-1-page156-playwright-cli.png).

Rows 4–5 require the incoming task's LDT selector to name a valid GDT entry
and the LDT descriptor to be present. The processor reports an invalid-TSS
`#TS` with the incoming LDTR selector as its error code. The existing direct
matrix covered five selector failures in both READY modes: TI set, wrong
descriptor type, wrong type with selector RPL bits, not-present LDT, and a
selector beyond the GDT limit.

The nested escalation tests now carry all five cases through both outcomes:

- **Shutdown:** after incoming-LDTR `#TS`, a malformed vector-10 gate raises
  `#GP`; an invalid vector-8 gate then enters sticky shutdown with null-error
  `#DF`. Tests check the transferred-task context, the exact two gate lookups,
  selector-appropriate descriptor read/skip behavior, and shutdown
  quiescence. All five variants pass with READY immediate and stalled (10
  executions).
- **Successful `#DF` task delivery:** the same five invalid-LDTR categories
  reach a valid vector-8 task gate and execute its exact HLT successor in
  both READY modes. Tests check the faulting task's saved LDTR and other TSS
  words, backlink and busy bits, and both gate lookups (10 executions). The
  not-present case uses selector `0078` in this path because the vector-8
  handler TSS occupies GDT selector `0070`; its descriptor is explicitly
  configured as a not-present LDT. The shutdown path retains the direct
  matrix selector `0070`.

## Verification

- `scripts/preflight.py`: pass.
- Exact-source Verilator 5.052 `-Wall` runner build: pass; fingerprint
  `7f0d6fb935548ee9bb7c431017674c8c7f1a57b8a6b477656057d27b3fd6805b`.
- Runner binary SHA-256:
  `7b8e8c1677a9bd05f20d46bc74e15c8ee6bcb3a81b004c6c7f3c3b5624a7f47c`.
- Focused `Vintel_80286 --iopl-controls`: pass.
- Full `scripts/run_sim.sh`: 195 `PASS:` lines; zero `FAIL:` and `ERROR:`
  markers. The run reached and completed the protected-mode replay step.
- Protected replay manifest: `PASS`, 79 cases in unstalled and READY-stalled
  modes. The manifest records current source/tool hashes.
- Testbench SHA-256:
  `d99569faffe671c2481dc3252719e8c708d42e762158987b9312a0971fa6f3b2`.
- Full-run log SHA-256:
  `fb281e009a2e231d8db08fbd5da523ebe7427da37525a2788689ac23ea17d067`.
- Protected replay manifest SHA-256:
  `639c9c99c773baab246d1af5130c42b1f60954b6071e1f8fecafc182b162c347`.
- Playwright CLI source screenshot SHA-256:
  `bff7df44409cb863233728a4ad311e94667847c16f6b5b1f1be511b9302f1b91`.

Evidence is under
`design/intel_80286/work/incoming_ldtr_escalation_variants_20261029_21/`.
Only the testbench changed; no RTL or synthesis inputs changed.
The checkpoint was posted and read back in
[issue comment 6486405063](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6486405063).

The preserved whole-core ABC PDR is still active on its older source snapshot.
Its latest solver line remains frame 118 with 343/411 outputs proved and 50
timeout retries; the saved top-level core and code-load module differ from
current source. It is not current-source proof. Current-source connected-core
formal, authentic software execution on the RTL, remaining task-entry fault
phases, and whole-CPU acceptance remain open.
