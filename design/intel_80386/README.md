# Intel 80386 family — 386DX and 386SX

Canonical family issue: [#116](https://github.com/hevangel/ai_engineer/issues/116). One family folder and one public timeline card, with one native sub-issue per physical chip.

| Chip | Member issue | Implementation / sourced history |
| --- | --- | --- |
| Intel 80386DX (1985) | [#274](https://github.com/hevangel/ai_engineer/issues/274) | [intel_80386dx](intel_80386dx/README.md): owns the shared execution core |
| Intel 80386SX (1988) | [#275](https://github.com/hevangel/ai_engineer/issues/275) | [intel_80386sx](intel_80386sx/README.md): the same core behind a 16-bit external data bus (bus unit not yet built) |

The DX and SX run the same 32-bit architecture. They differ in their external bus: the DX has a 32-bit data bus and 32-bit addresses, the SX a 16-bit data bus and 24-bit addresses. The execution core lives in the DX member folder and the SX profile links it rather than copying it. Each chip gets its own native bus unit; pin timing and memory-controller behaviour need separate evidence for each.

The IBM 386SLC is a separate chip issue and is not the Intel 386SL. The 486 and later opcodes are out of scope.

Historical dates, sources, verification evidence and limits are kept in the member READMEs and in the [design index](../README.md).
