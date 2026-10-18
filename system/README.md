# Systems

Functional reconstructions of complete historical *systems*, built from the
chip designs in [`design/`](../design/). Where a chip design is a component,
a system wires real chips together, runs authentic firmware/peripherals, and
exposes a human interface — virtual-platform style: hardware in the xezim
simulator, front panel as a web app, connected over DPI-C.

| System | Year | Chips used | Folder |
|---|---|---|---|
| Apple II (in progress) | 1977 | MOS 6502 | [apple_ii/](apple_ii/) |
| BUSICOM 141-PF printing calculator | 1971 | 4004, 5×4001, 2×4002, 3×4003 | [busicom_141pf/](busicom_141pf/) |
| Micral N | 1973 | Intel 8008, 16 KiB memory, I/O bus | [micral_n/](micral_n/) |
| IBM PC 5150 | 1981 | 8088 bus adapter/shared 8086 EU, 8259, 8253, 8255, 8237, 8272, CGA | [ibm_pc/](ibm_pc/) |
| IBM PC XT 5160 | 1983 | 8088, 8087, 256 KiB RAM, CGA, IBM/Xebec 10 MB fixed disk | [ibm_pc_xt_5160/](ibm_pc_xt_5160/) |

Each `system/<name>/` folder follows the chip-design layout (`spec/`,
`plans/`, `src/`, `tb/`, `scripts/`, `report/`) plus `host/` (web app and
DPI bridge). The `spec/` folder also stores downloaded reference material
under `spec/reference/`.

The Micral N year follows the [Computer History Museum catalog](https://www.computerhistory.org/revolution/artifact/297/1147). Its reconstruction and documented limits are in the [system overview](micral_n/README.md).

The IBM PC year follows [IBM's manufacturer history](https://www.ibm.com/history/personal-computer).
Its original BIOS/BASIC/PC DOS firmware, RTL hardware, front panel, CPU waveform viewer and functional
boundaries are described in the [system overview](ibm_pc/README.md).
