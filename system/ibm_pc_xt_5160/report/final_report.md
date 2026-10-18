# IBM PC XT 5160 verification report

## Delivered configuration

The platform integrates the existing RTL 8088 adapter/shared 8086 execution
unit, Intel 8087, 256 KiB RAM, CGA, keyboard, 8259/8253/8255/8237/8272 and
an IBM/Xebec DCB fixed-disk adapter. The persistent disk has the original
type-3 geometry: 306 cylinders, four heads, 17 sectors, 512 bytes per sector,
**10,653,696 bytes**. It boots original PC DOS 2.00 on C: through actual
adapter ROM, DMA3 and IRQ5 behavior. The host supplies memory/media bytes
and keyboard input; it does not execute CPU instructions or intercept interrupts.

## Historical artifacts and independent authority

Firmware is unmodified. `prepare_images.py` pins Git object identities and
checks downloads, then records SHA256 in `work/reference/manifest.json`.

| Artifact | Pinned Git blob |
|---|---|
| XT BIOS, November 8 1982 revision | `f75320f4970a8fbcadcda90542f4e3e2e95816f9` |
| Cassette BASIC 1.10 | `897e689b5606d3837ba810e2d4695e8aa0602c09` |
| Original IBM/Xebec 1982 option ROM | `6fbc1b275a345f91842637dc5cf60a1a8bf5c07a` |
| DOS 2.00 disk 1 | `0e834efc93bf0c720bbbfa73aef6964f9b20a477` |
| DOS 2.00 disk 2 | `f728ce4968f6a0cb9aa75aa473b280696665d426` |
| Original DOS MBR | `38f265836be4887fdf0396ae3b558dec65e95070` |

The DOS sources are original 180 KB single-sided media, usable in the
modeled 360 KB drives. Disk preparation retains original boot instructions
and system files, updating the BPB/partition metadata for fixed-disk geometry.
The independent controller interpretation is PCjs `hdc.js`; original XT BIOS
assembly, IBM's technical reference and unchanged option-ROM execution pin
board behavior. Source URLs and commits are in the [overview](../README.md)
and [preparation script](../scripts/prepare_images.py).

## Verification

The complete `run_all.sh` passed on October 16, 2026. The first cold software
run completed at 212,000,000 clocks with 93 fixed-disk commands, 110,080 bytes
read, 5,120 bytes written and seven 8087 instructions. Its separate cold
restart completed at 168,000,000 clocks.

- Strict integrated Verilator `-Wall --assert` build passed.
- Controller BMC, induction proof and non-vacuity covers passed. Properties
  include medium/SRAM bounds, valid lengths, direction and stalled addresses.
  Simulation checks original INIT/REQ phases, DMA reads/writes, separate
  controller SRAM commands, absent-drive sense and final-track formatting.
- The actual CPU ESC/WAIT fixture passed, checking result 42 and exact final
  post-HLT PC. Integrated runs assert exclusive FPU/DMA memory ownership.
- Original DOS performed DIR, created and read `XTTEST.TXT`, ran original
  BASIC 1.10 and calculated 42, ran `FPU8087.COM` (6*7=42, SQRT(169)=13),
  then copied that program to C:. Independent FAT12 extraction compared the
  text and complete executable bytes against their expected content.
- A new simulator process cold-booted the persisted disk, read the created
  file and ran the copied 8087 program from C:. The cold restart reached DOS
  at 161,000,000 clocks and completed persistence checks at 168,000,000.
- HTTP regressions passed power/pause/step, FST capture, disk export and
  invalid-drive rejection. The front panel also cold-booted the original DOS
  using its actual CGA screen and keyboard.
- Existing 8086 UVM control/boundary regression passed all eight scenarios.
  The 8087 execution-enable optimization retained all 246,624 numerical checks;
  controller BMC/prove/stack-cover/bus-cover passed with the documented numeric
  abstraction.
- Yosys hierarchy, process lowering, optimization and structural checks passed
  on the complete platform. This is a technology-independent word-level
  netlist, not a placed device or a timing/area result.

`scripts/run_all.sh` performs cold software testing without debug snapshots.
Pre-option-ROM snapshots were used only to shorten diagnostic iteration;
they restore the whole generated RTL/memory state and are tied to the exact
build. They are not used in normal startup or cold verification.

## Known boundaries

The 8087 is an architectural functional coprocessor with explicit floating-point
datapaths, not a native pin-compatible 8087. ESC transaction wiring replaces
queue snooping; numerical edge cases and approximate transcendentals retain
the [core's stated limits](../../../design/intel_8087/report/final_report.md).
No exhaustive original-silicon equivalence or original cycle-count claim is
made. Disk mechanics, MFM flux and analog ECC faults are not modeled.
CPU/bus scheduling, decoded diskette media and functional CGA/keyboard follow
the existing 5150 platform. Firmware-driven missing sector-buffer support was
fixed and documented in the [failure note](../../../failure_notes/2026-10-16-xt-fixed-disk-sector-buffer.md).
