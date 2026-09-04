# Systems

Functional reconstructions of complete historical *systems*, built from the
chip designs in [`design/`](../design/). Where a chip design is a component,
a system wires real chips together, runs authentic firmware/peripherals, and
exposes a human interface — virtual-platform style: hardware in the xezim
simulator, front panel as a web app, connected over DPI-C.

| System | Year | Chips used | Folder |
|---|---|---|---|
| BUSICOM 141-PF printing calculator | 1971 | 4004, 5×4001, 2×4002, 3×4003 | [busicom_141pf/](busicom_141pf/) |

Each `system/<name>/` folder follows the chip-design layout (`spec/`,
`plans/`, `src/`, `tb/`, `scripts/`, `report/`) plus `host/` (web app and
DPI bridge). The `spec/` folder also stores downloaded reference material
under `spec/reference/`.
