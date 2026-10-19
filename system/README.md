# Systems

Functional reconstructions of complete historical *systems*, built from the
chip designs in [`design/`](../design/). Where a chip design is a component,
a system wires real chips together, runs authentic firmware/peripherals, and
exposes a human interface: hardware in RTL simulation, a web front panel,
and a host bridge for external storage, media and user input.

| System | Year | Chips used | Folder |
|---|---|---|---|
| Apple IIe functional virtual platform | 1983 | NMOS 6502, IIe MMU, IOU, timing PAL, 128 KiB RAM | [apple_iie/](apple_iie/) |
| Apple II revision-0 (functional; fidelity validation ongoing) | 1977 | MOS 6502 plus 82 support IC packages | [apple_ii/](apple_ii/) |
| BUSICOM 141-PF printing calculator | 1971 | 4004, 5×4001, 2×4002, 3×4003 | [busicom_141pf/](busicom_141pf/) |
| Micral N | 1973 | Intel 8008, 16 KiB memory, I/O bus | [micral_n/](micral_n/) |
| IBM PC 5150 | 1981 | 8088 bus adapter/shared 8086 EU, 8259, 8253, 8255, 8237, 8272, CGA | [ibm_pc/](ibm_pc/) |
| IBM PC XT 5160 | 1983 | 8088, 8087, 256 KiB RAM, CGA, IBM/Xebec 10 MB fixed disk | [ibm_pc_xt_5160/](ibm_pc_xt_5160/) |
| IBM PS/2 Model 30 | 1987 | Native 8086, planar gate arrays, 8259, 8253, 8237, 8272, MM58167-compatible RTC, MCGA, integrated DBA fixed-disk controller | [ibm_ps2_model30/](ibm_ps2_model30/) |

Each `system/<name>/` folder follows the chip-design layout (`spec/`,
`plans/`, `src/`, `tb/`, `scripts/`, `report/`) plus `host/` (web app and
storage/media bridge). The `spec/` folder records reference provenance;
generated artifacts and copyrighted firmware downloads stay in ignored
`work/` directories where required by the individual system's manifest.

Use the [system README template](TEMPLATE.md) for system overviews. Each
system README includes a **Web interface and waveform** section with a real
browser screenshot showing captured signals where supported, or an explicit
note identifying the missing web-interface or waveform feature. Screenshot
assets live in each system's `assets/` folder.

The Micral N year follows the [Computer History Museum catalog](https://www.computerhistory.org/revolution/artifact/297/1147). Its reconstruction and documented limits are in the [system overview](micral_n/README.md).

The IBM PC year follows [IBM's manufacturer history](https://www.ibm.com/history/personal-computer).
Its original BIOS/BASIC/PC DOS firmware, RTL hardware, front panel, CPU waveform viewer and functional
boundaries are described in the [system overview](ibm_pc/README.md).

The original Model 30's 1987 introduction and 8086/MCGA configuration follow
IBM's [Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf)
and [April 1987 product reference](https://bitsavers.org/pdf/ibm/pc/PS2_and_IBM_PC_Product_Reference_Version_4.0_Apr87.pdf).
Its native 8086 bus, planar devices, 720K media and waveform viewer are in
the [Model 30 overview](ibm_ps2_model30/README.md).
