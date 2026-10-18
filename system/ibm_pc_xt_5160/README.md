# IBM PC XT 5160 with Intel 8087

Functional RTL virtual platform: 8088 bus adapter/shared 8086 execution unit,
8087 floating-point coprocessor, 256 KiB RAM, CGA, two diskette drives and the
original IBM/Xebec fixed-disk interface with a writable 10 MB disk.

IBM introduced the XT in **1983**. Its fixed disk made larger applications and
files practical without swapping diskettes; the optional 8087 accelerated
numeric software. Historical and hardware context follows the manufacturer's
[April 1983 Technical Reference](https://minuszerodegrees.net/manuals/IBM_5160_Technical_Reference_APR83.pdf).
Firmware artifacts and independent controller references are pinned to
[PCjs commit 1a91d38](https://github.com/jeffpar/pcjs/tree/1a91d38eb12e5fdf91116b21ad9ef1935710a496/machines/pcx86/ibm/5160),
with original DOS 2.00 media from the
[PCjs diskette archive](https://github.com/jeffpar/pcjs-diskettes/tree/cd3433748b09837a4c60ca7066f3642772b2d711/pcx86/sys/dos/ibm/2.00).

## Run

From the repository root in the hardware-toolchain container:

```sh
bash system/ibm_pc_xt_5160/scripts/run_system.sh
```

Publish container port **8089** to localhost and open <http://localhost:8089>.
Power on, allow original RAM POST to finish, then enter a DOS date and time.
The initial disk boots PC DOS 2.00 on C:. A: starts empty; B: contains the
original DOS utilities diskette. The keyboard, CGA screen, speaker, pause,
single step and waveform capture operate on the running RTL machine.

The fixed disk is `work/harddisk.img`, exactly **10,653,696 bytes**
(306 cylinders, four heads, 17 sectors of 512 bytes). Writes persist across
reset and process restart. Image preparation preserves an existing nonblank
disk. `IBM_XT_DISK` selects another image; the front panel exports a copy.
The initial FAT12 partition uses original DOS boot code and system files;
only the disk geometry and filesystem metadata are prepared by the builder.
ROMs and disk images are downloaded, hash checked and cached in `work/`;
they are not redistributed in this repository.

## Verification and boundaries

Run `bash scripts/run_all.sh` within this folder. Cold software regressions
execute the original XT BIOS, fixed-disk ROM, DOS and BASIC; they also create
files, run an assembled 8087 DOS application and restart against the persisted
disk. No host CPU emulation or BIOS interrupt interception is used.

This is a functional reconstruction. The 8087 uses the core's transactional
ESC interface rather than native queue snooping pins. Its numerical accuracy
limits remain documented in the [8087 report](../../design/intel_8087/report/final_report.md).
Disk bytes are decoded sectors, without MFM flux or mechanical timing.
The CPU/bus, keyboard and CGA boundaries follow the [5150 platform](../ibm_pc/README.md).

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification report](report/final_report.md)
- [Escaped fixed-disk diagnostic defect](../../failure_notes/2026-10-16-xt-fixed-disk-sector-buffer.md)
