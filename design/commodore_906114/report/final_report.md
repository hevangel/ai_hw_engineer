# Commodore 906114-01 verification report

Command: `sh design/commodore_906114/scripts/run_all.sh` (all gates pass,
2026-10-27). Tools in the build container: Verilator 5.020, Icarus Verilog,
Yosys 0.33 and the YoWASP SymbiYosys/Yosys 0.70 build with the smtbmc z3
engine (`SBY=yowasp-sby`); the repository image pins its own tool builds.

| Gate | Result |
|---|---|
| Lint | `verilator --lint-only -Wall` clean |
| Formal | BMC depth 1 (the design is combinational) proves: ROM/I/O selects one-hot-or-none; any select implies CASRAM high; CAS idle keeps CASRAM and GR/W high; VIC cycles select no CPU device; CPU writes never select a ROM; no cartridge means no ROML/ROMH; GR/W implies a CPU write in $Dxxx; I/O reads need BA. Twelve covers reached (each select, each memory mode) |
| Simulation | Verilator and Icarus dumps identical; 32,632 VICE-mapped words (8,056 CPU reads, 8,192 CPU writes, 16,384 VIC fetches) match; 32,768 CAS-high and 136 BA-low I/O-read words follow the ledger rules |
| Mutants | 9 of 9 detected (BASIC in Ultimax, LORAM term in CHAROM, I/O read without BA, ROML on writes, VIC bank polarity, Ultimax $C000 mapped, VIC ROMH keeps RAM, GR/W ignores CAS, 16K KERNAL dropped) |
| Synthesis | 142 cells, `check -assert` 0 problems |
| System | Original BASIC/KERNAL boot on the C64 board matches VICE x64sc in RAM image, IRQ entry cycles and instruction traces (see the [system report](../../../system/commodore_64/report/final_report.md)) |

CPU-read words VICE leaves to device handlers outside the tables (the
Ultimax $Dxxx handler) are excluded from the table comparison and covered by
the I/O terms and the formal properties instead.

Limits: function only, per the ledger: no 82S100 timing, term-slot order or
electrical behavior is claimed. Cartridge modes are verified against VICE's
tables, not against cartridge hardware.
