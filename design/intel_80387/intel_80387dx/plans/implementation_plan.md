# Implementation plan: Intel 80387 (DX and SX)

Canonical issue: https://github.com/hevangel/ai_engineer/issues/115 (DX #276, SX #277).

| Milestone | Scope | Status |
| --- | --- | --- |
| M1 | 80387 architecture on the shared controller (`VARIANT = 2`): every Appendix C difference except the transcendental range extensions; FUCOM family, FPREM1, stack faults, 16- and 32-bit real and protected images, tag recomputation, rounding-controlled constants | Done (this report) |
| M2 | FSIN, FCOS, FSINCOS and full-range FPTAN/FPATAN/F2XM1, with exact 66-bit-π reduction; tolerance comparison against the host | Done (≤ 8 ULP bound; see report) |
| M3 | Native 386DX coprocessor interface: I/O ports 800000F8h–800000FEh, PEREQ, BUSY#, ERROR#, NPS1#/NPS2, CMD0#, STEN, 32-bit data; connect it to the 80386 core when that core's coprocessor paths exist | Planned |
| M4 | 387SX profile: the same as M3 with a 16-bit data bus (see ../intel_80387sx) | Planned |
| M5 | RESET signature (IE/ES set so ERROR# indicates a 387, A3), and original 387 software running on a 386 system model | Planned |
