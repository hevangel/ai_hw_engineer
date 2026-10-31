# Reachable CPL1/CPL2 selector-query verification

**Date:** 2026-10-28 14:33 UTC  
**Scope:** VERR, VERW, LAR and LSL query execution at CPL1 and CPL2  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)

## Result

Added a testbench matrix that reaches CPL1 and CPL2 through an outer IRET and
executes register-source VERR, VERW, LAR and LSL against GDT descriptors. The
768 executions are the product of two privilege levels, three descriptor
classes (writable data, readable nonconforming code and readable conforming
code), every DPL and RPL value from 0 through 3, four query instructions, and
both READY policies.

Every case checks the expected ZF, preservation of all other flags, LAR/LSL
result or failure preservation, BX preservation, the exact three instruction
fetches, all eight ordered descriptor-byte reads, no descriptor writes, and
retirement at the exact following NOP. The test uses real ring transitions and
does not seed CPL or hidden CS/SS caches. All 768 cases pass without a fault or
development stop.

The code is testbench-only: no processor RTL changed for this checkpoint.
Combined with the existing ring-0 and CPL3 query matrices, this materially
widens selector-query coverage but does not establish all selector types,
fault priorities, LDT cases or complete protected-mode behavior at CPL1/CPL2.

## Source and expected behavior

Intel, *80286 and 80287 Programmer's Reference Manual*, order 210498-005,
§11.3, printed pages 11-3–11-4 (scanned PDF pages 189–190), was visually
reviewed with Playwright CLI. For data and nonconforming code, the privilege
check requires DPL to be numerically greater than or equal to both CPL and
selector RPL. Conforming-code visibility skips that comparison for VERR/LAR/LSL;
VERW still rejects code because it requires writable data. The focused
[selector specification](../spec/selector_execution.md) records the broader
query contract and limits.

## Reproduction and identity

From the worktree root, the strict runner build and focused slice were run in
the active `ai-hw-engineer:latest` container:

```sh
docker exec -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/selector_ring12_20261028 \
  -w /work dcd30140a9c0 sh design/intel_80286/scripts/build_runner.sh

docker exec -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/selector_ring12_20261028 \
  -w /work dcd30140a9c0 \
  /work/design/intel_80286/work/selector_ring12_20261028/sim/Vintel_80286 --selector-exec
```

The runner uses Verilator 5.052 (`--Wall`) and g++ 15.2.0. The complete
`--selector-exec` slice passes: 2 selector-register executions, 10 selector
exception deliveries, 24 reachable CPL1–3 LLDT/LTR privilege cases, 2 null-LDTR
recoveries, 82 ring-0 query cases, 160 reachable CPL3 query cases, and these
768 reachable CPL1/CPL2 query cases. The same binary also passes the full
default bootstrap, including the new matrix; its 54-line log has SHA-256
`b8b4f5785f276e9336a009fe23e724073e7d58c3aad5b00b722b478943629d41`.

The focused slice can be rerun with the command above. To rerun the default
bootstrap in the same container:

```sh
docker exec -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/selector_ring12_20261028 \
  -w /work dcd30140a9c0 sh -lc \
  '/work/design/intel_80286/work/selector_ring12_20261028/sim/Vintel_80286'
```

Runner fingerprint: `5a4cb5fdc04702f40664e45a03689ba37a64519569180e15bdf82018d9ec5556`  
Binary SHA-256: `30e74d381e35a5b7001975c4fb68e55918c50df13cbffd9671742382dc6744c9`  
Build manifest SHA-256: `06f321ebb7d40f82fcbb486594e21e33bce266da471037754da56c9f22f55f2b`  
RTL SHA-256: `76fd741ef595cede3a3eff85cab952361eeae0fe484921af257e68992872c553`  
Bootstrap SHA-256: `3e9eaa34f2c0b3d9886be5eed24aaf92845c9ca4f722c497cc18f61692087a26`  
Saved focused-run log SHA-256: `ea6db6323345a4db896b79f53c5d4c409481a8fb246477668274a44492a28c35`

The separate whole-core PDR remains active on an earlier 21-file snapshot.
At 14:35 UTC it reached frame 80, with 321/411 outputs proven and 66 timeout
retries. That run does not verify current source or this testbench change; the
full current-source formal and release gates remain open. Its later 14:39:46
UTC log reached frame 83 with 321/411 outputs proven and 68 timeout retries;
the run still has no terminal result and does not cover this update.
