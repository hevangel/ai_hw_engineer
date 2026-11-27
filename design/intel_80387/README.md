# Intel 80387 family — 387DX and 387SX

Canonical family issue: [#115](https://github.com/hevangel/ai_engineer/issues/115). One family folder and one public card, with a native sub-issue for each physical chip.

| Chip | Member issue | Implementation / sourced history |
| --- | --- | --- |
| Intel 80387DX (1987) | [#276](https://github.com/hevangel/ai_engineer/issues/276) | [intel_80387dx](intel_80387dx/README.md): owns the 80387 tests, spec and report |
| Intel 80387SX (by November 1988) | [#277](https://github.com/hevangel/ai_engineer/issues/277) | [intel_80387sx](intel_80387sx/README.md): same architecture, 16-bit 386SX host bus (bus unit not built) |

Both chips run the 80387 architecture on the shared x87 controller in [design/intel_8087](../intel_8087/README.md), built with `VARIANT = 2`; the RTL is linked, not copied. The DX and SX differ only in their host bus and package. Those interfaces are separate later milestones, and the two are not pin-compatible.
