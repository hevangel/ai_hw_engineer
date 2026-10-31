# Reachable CPL3 selector-query verification

**Date:** 2026-10-28 14:18 UTC  
**Scope:** VERR, VERW, LAR and LSL query execution at CPL3  
**Issue checkpoint:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6471331193)

## Result

Added a directed regression that loads LDTR/TR at ring 0, enters CPL3 through a
real outer IRET, then executes register-source and `DS:[0020]` memory-source
forms of VERR, VERW, LAR and LSL against GDT/LDT selectors. It queries DPL0
conforming code at RPL0/RPL3, every defined 286 system/gate type, and null or
out-of-limit selectors. A visible P=0 writable data descriptor also passes all
four queries. All 160 CPL3 runs pass across both READY policies. The test does
not seed CPL or hidden segment caches.

The matrix checks DPL3 successes, DPL0 visibility denial, readable versus
writable data behavior, and the Intel conforming-code rule: VERR/LAR/LSL accept
DPL0 conforming code from CPL3 with RPL0 or RPL3, while VERW rejects code. For
system descriptors, LAR accepts types 1–7, LSL accepts available/busy TSS and
LDT types 1–3 but rejects gates, and VERR/VERW reject them. A DPL0 TSS fails
LAR/LSL visibility at CPL3. Register and DS:[0020] forms include TSS and
call-gate cases. A P=0 writable-data descriptor succeeds in VERR/VERW/LAR/LSL;
LAR returns its P=0 access bit. Null GDT selectors and complete descriptors
beyond GDT/LDT limits clear ZF without descriptor reads; memory-source cases
still read the selector operand. The matrix also checks exact ZF-only changes,
LAR/LSL results, destination preservation on failure, LDT selection, selector
reads through the ring-3 DS cache, all eight descriptor-byte reads when
permitted, no descriptor writes, and exact instruction successor flow. No
fault or development stop is accepted.

The new cases pass with the pre-existing RTL; this checkpoint changes the
directed verification harness, not processor RTL. It validates this bounded
query slice and does not establish complete protected mode or CPU completion.

## Reproduction and identity

Run from the worktree root in `ai-hw-engineer:latest`:

```sh
docker run --rm \
  -v B:/ai_hw_engineer/worktree/intel-80286:/work \
  -w /work \
  -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/selector_ring3_20261028 \
  ai-hw-engineer:latest sh design/intel_80286/scripts/build_runner.sh

docker run --rm \
  -v B:/ai_hw_engineer/worktree/intel-80286:/work \
  -w /work \
  ai-hw-engineer:latest \
  /work/design/intel_80286/work/selector_ring3_20261028/sim/Vintel_80286 --selector-exec
```

The strict runner build passed with Verilator 5.052 and g++ 15.2. The focused
`--selector-exec` run passed its full slice: 2 SLDT/STR/LLDT/LTR executions,
10 selector #GP/#NP deliveries, 24 reachable CPL1–3 LLDT/LTR privilege cases,
2 null-LDTR recoveries, 82 existing protected selector-query cases, and the
160 reachable CPL3 query cases.

Runner fingerprint: `12650523275bbda9e7b1c4bdeb6cc231d7316df618410a4a8bcd7b5bcf74f269`  
Binary SHA-256: `653364e855f9065009b021d9173670af443d72b9394ddb36330bbe0d80224b10`  
Core SHA-256: `76fd741ef595cede3a3eff85cab952361eeae0fe484921af257e68992872c553`  
Bootstrap SHA-256: `aa9e16abb695c1f7513cfd8b4ee0f2ecee9bb5b29fba640a7657f611d1615bac`

## Source and remaining limits

Expected selector-query semantics follow Intel, *80286 and 80287 Programmer's
Reference Manual*, order 210498-005, §11.3 and Appendix B; see the source link
in [`selector_execution.md`](../spec/selector_execution.md). The scanned §11.3
pages (printed 11-3–11-4; PDF pages 189–190) were visually inspected through
Playwright CLI. They state that conforming code may be accessed from any RPL or
CPL; VERR skips the privilege comparison for conforming segments, while VERW
requires writable data and therefore rejects code. Later x86 behavior was not
used as authority.

Still open for this instruction family: broader selector fault/restart cases
across more CPL/RPL combinations. At 14:18:30 UTC, the separate whole-core PDR
was still active on an earlier 21-file snapshot at frame 61 with 321/411
outputs proven and 61 timeout retries; it is not evidence for this source. The
full formal audit, whole-core release
gate, independent software closure and native timing remain separate
requirements.
