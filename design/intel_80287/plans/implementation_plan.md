# Implementation plan: Intel 80287

Canonical issue: https://github.com/hevangel/ai_engineer/issues/113

| Milestone | Scope | Status |
| --- | --- | --- |
| M1 | Architectural 80287 on the shared x87 controller (`VARIANT = 1`): FSETPM protected-mode pointer images, FSTSW AX, FENI/FDISI as no-ops, ERROR# semantics, 8087 numerics | Done (this report) |
| M2 | Native interface. The 80286 sends the opcode to port 00F8h, sends or receives operand words through 00FAh/00FCh, and transfers environment words, using PEREQ/PEACK#, BUSY#, ERROR#, CMD0/CMD1 and NPS1#/NPS2. Connect it to the 80286 core's existing processor-extension channel and run the IBM AT BIOS math-coprocessor POST. | Planned |
| M3 | Physical-chip numeric evidence (a 287 capture or original 287 software with known results) to test assumption P-A1 | Planned |
| M4 | 80287XL member (CHMOS, 387-class numerics) as a separately sourced profile | Planned |

M1 reuses the shared RTL in `design/intel_8087/src` with no copy. Variant differences are parameterized and cited in that source.
