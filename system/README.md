# Systems

Functional reconstructions of complete historical *systems*, built from the
chip designs in [`design/`](../design/). Where a chip design is a component,
a system wires real chips together, runs authentic firmware/peripherals, and
exposes a human interface â€” virtual-platform style: hardware in the xezim
simulator, front panel as a web app, connected over DPI-C.

| System | Year | Chips used | Folder |
|---|---|---|---|
| Apple II revision 0 (in progress) | 1977 | 83 IC packages; 6502 transistor reference, 4116, ROM, 2513, TTL, timers, 741 | [apple_ii/](apple_ii/) |
| BUSICOM 141-PF printing calculator | 1971 | 4004, 5Ã—4001, 2Ã—4002, 3Ã—4003 | [busicom_141pf/](busicom_141pf/) |

Each `system/<name>/` folder follows the chip-design layout (`spec/`,
`plans/`, `src/`, `tb/`, `scripts/`, `report/`) plus `host/` (web app and
DPI bridge). The `spec/` folder also stores downloaded reference material
under `spec/reference/`.

The Apple II physical-package model uses Icarus/VPI for resolved motherboard buses and the optional transistor CPU reference; its individual digital package tests use Xezim. Original Monitor command execution and its serialized display pass, as do
text/lores/hires and mixed-mode digital video comparisons. Electrical fidelity and completion of the authored 6502 remain outstanding; see its [verification report](apple_ii/report/final_report.md).
