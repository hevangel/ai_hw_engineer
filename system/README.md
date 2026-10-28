# Systems

Functional reconstructions of complete historical *systems*, built from the
chip designs in [`design/`](../design/). Where a chip design is a component,
a system wires real chips together, runs authentic firmware/peripherals, and
exposes a human interface: hardware in RTL simulation, a web front panel,
and a host bridge for external storage, media and user input.

| System | Year | Chips used | Folder |
|---|---|---|---|
| MITS Altair 8800 | 1975 | Intel 8080, 88-SIO, front panel, 16 KiB RAM | [altair_8800/](altair_8800/) |
| Space Invaders arcade | 1978 | Intel 8080, hardware shift register, 8 KiB ROM, 1 KiB RAM + 7 KiB VRAM | [space_invaders/](space_invaders/) |
| Apple IIe functional virtual platform | 1983 | NMOS 6502, IIe MMU, IOU, timing PAL, 128 KiB RAM | [apple_iie/](apple_iie/) |
| Apple II revision-0 (functional; fidelity validation ongoing) | 1977 | MOS 6502 plus 82 support IC packages | [apple_ii/](apple_ii/) |
| BUSICOM 141-PF printing calculator | 1971 | 4004, 5×4001, 2×4002, 3×4003 | [busicom_141pf/](busicom_141pf/) |
| Micral N | 1973 | Intel 8008, 16 KiB memory, I/O bus | [micral_n/](micral_n/) |
| SCELBI 8B (SCELBAL BASIC + Shooting Stars) | 1975 | Intel 8008, 16 KiB RAM, bit-banger serial console | [scelbi_8b/](scelbi_8b/) |
| IBM PC 5150 | 1981 | 8088 bus adapter/shared 8086 EU, 8259, 8253, 8255, 8237, 8272, CGA | [ibm_pc/](ibm_pc/) |
| IBM PC XT 5160 | 1983 | 8088, 8087, 256 KiB RAM, CGA, IBM/Xebec 10 MB fixed disk | [ibm_pc_xt_5160/](ibm_pc_xt_5160/) |
| IBM PS/2 Model 30 | 1987 | Native 8086, planar gate arrays, 8259, 8253, 8237, 8272, MM58167-compatible RTC, MCGA, integrated DBA fixed-disk controller | [ibm_ps2_model30/](ibm_ps2_model30/) |
| Super Nintendo Entertainment System (NTSC/PAL) | 1990 | Ricoh 5A22 (65C816) CPU, 5C77/5C78 PPUs, Sony S-SMP (SPC700) and S-DSP, 128 KiB work RAM, 64 KiB VRAM and audio RAM, LoROM/HiROM cartridges, two pads | [snes/](snes/) |

The requested Atari 2600, Commodore 64 and Nintendo NES reconstructions
are queued after the chip work in the
[MOS series ledger](../plans/mos_historical_series.md); they are not yet
implemented systems. The Super Nintendo is listed above.

Each `system/<name>/` folder follows the chip-design layout (`spec/`,
`plans/`, `src/`, `tb/`, `scripts/`, `report/`) plus `host/` (web app and
storage/media bridge). The `spec/` folder records reference provenance;
generated artifacts and copyrighted firmware downloads stay in ignored
`work/` directories where required by the individual system's manifest.

Run `./scripts/new_system.sh <system_name>` from the repository root to copy
the shared scaffold. Use the [system README template](TEMPLATE.md) for system overviews. Each
system README includes a **Web interface and waveform** section with a real
browser screenshot showing captured signals where supported, or an explicit
note identifying the missing web-interface or waveform feature. Screenshot
assets live in each system's `assets/` folder.

The Micral N year follows the [Computer History Museum catalog](https://www.computerhistory.org/revolution/artifact/297/1147). Its reconstruction and documented limits are in the [system overview](micral_n/README.md).

The SCELBI 8B year (1975) follows SIMH's SCELBI notes ("a SCELBI-8B from about 1975"); the 8H predecessor was announced in March 1974 (QST). Its reconstruction, the authentic SCELBAL boot, and documented limits are in the [system overview](scelbi_8b/README.md).

The IBM PC year follows [IBM's manufacturer history](https://www.ibm.com/history/personal-computer).
Its original BIOS/BASIC/PC DOS firmware, RTL hardware, front panel, CPU waveform viewer and functional
boundaries are described in the [system overview](ibm_pc/README.md).

The Altair 8800 year follows the [Popular Electronics January 1975
announcement](https://www.americanradiohistory.com/hdgrpx/Popular-Electronics/70s/Popular-Electronics-1975-01.pdf).
Its no-ROM front-panel operation, original 4K BASIC 3.2 boot through the
88-SIO tape reader and functional boundaries are described in the
[system overview](altair_8800/README.md).

Space Invaders is dated 1978 (Taito; Midway licensed release the same
year). Its original-ROM attract/coin/play regression, two 60 Hz RST
interrupts, hardware shift register and independent-oracle agreement are
described in the [system overview](space_invaders/README.md).

The original Model 30's 1987 introduction and 8086/MCGA configuration follow
IBM's [Technical Reference scan](../references/model30tr.pdf) (with a [clean text extraction](ibm_ps2_model30/spec/reference/model30tr.txt)) and the [IBM archive](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf)
and [April 1987 product reference](https://bitsavers.org/pdf/ibm/pc/PS2_and_IBM_PC_Product_Reference_Version_4.0_Apr87.pdf).
Its native 8086 bus, planar devices, 720K media and waveform viewer are in
the [Model 30 overview](ibm_ps2_model30/README.md).
