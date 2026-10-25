# IBM Personal System/2 Model 30 (8086)

The original Model 30 was introduced in **1987**. It combined an 8 MHz
8086 with the PC's 8-bit expansion interface, 3.5-inch diskette drives,
Model M keyboard and MCGA analog video. This reconstruction targets the
**8530-021** with 640 KiB RAM, one 720K floppy and the original integrated
20 MB fixed disk. The Model 30 286 is a different
machine. Historical hardware is documented in IBM's
[Technical Reference](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf)
and [April 1987 product reference](https://bitsavers.org/pdf/ibm/pc/PS2_and_IBM_PC_Product_Reference_Version_4.0_Apr87.pdf). The local [clean text extraction](spec/reference/model30tr.txt) stays with the system; the [PDF scan](../../references/model30tr.pdf) is in shared references.

The original IBM BIOS and PC DOS boot through RTL CPU and peripherals.
Original DOS creates and formats the fixed disk, installs its system files
and boots C: with the floppy ejected. The host supplies external storage,
media and user input. Measured verification and functional limits are
recorded in the report.

- [Specification and assumption ledger](spec/spec.md)
- [Integrated fixed disk, controller and image format](spec/hard_disk.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification report and functional limits](report/final_report.md)
- [Firmware/source manifest](spec/reference/README.md)

Run from the repository root in the `ai-hw-engineer` tool image:

```sh
sh system/ibm_ps2_model30/scripts/run_system.sh
```

Open [the Model 30 front panel](http://localhost:8530/). When running inside
Docker, publish `127.0.0.1:8530:8530` and mount this checkout at `/work`.
`IBM_PS2_MODEL30_PORT` selects another port. The existing
[IBM PC 5150 panel](http://localhost:8088/) runs independently.

Power on starts the original ROM's full RAM test. A fresh clock battery
produces `161-Set Date and Time`; press F1 when the resume prompt appears,
then initialize the battery clock with the original IBM Starter Disk.
DOS DATE/TIME alone can leave a fresh, invalid battery clock unconfigured. The server
keeps battery storage in ignored `work/rtc-<port>.bin`. It saves on pause,
reset, power off and clean exit. The hard disk saves to ignored
`work/harddisk-<port>.m30` on pause, reset, power off and clean exit.
Use Save hard disk to export its complete sector, ID and check-field state;
Raw image exports standard 512-byte sectors. A raw image is 21,307,392 bytes.
An original DOS installation without AUTOEXEC.BAT asks for date/time at boot;
press Enter to accept the configured clock. Mounting a disk pauses the machine. Floppy writes stay in memory; export
any changed floppy before closing the server. `IBM_PS2_MODEL30_NO_HDD=1`
selects the original two-floppy configuration for regression.

To install DOS on a blank fixed disk, boot the DOS floppy and use FDISK to
create a maximum-size active primary partition. After its restart, run
`FORMAT C: /S` and confirm the warning. Eject A and Reset to boot C.
The verification scripts create guest-installed disks under ignored `work/`;
newly created backing stores begin blank.

Click the display to type, or use the 101-key on-screen Model M. Run/Pause
controls simulation; Step retires exactly one instruction. The MCGA display
uses the hardware's 64 KiB video RAM, RGB DAC and loadable character font.
The CPU waveform panel captures 1..65,536 subsequent CPU clocks and pauses
the machine. It includes all general/segment registers, IP/flags and a bus
preset with the native 16-bit lanes, READY, INTA and DMA arbitration.
The hard disk preset shows controller commands, sector position, IRQ5
and channel-3 DMA strobes.
Surfer and FST files are served locally. Trace half-period is 62,500 ps.

Run all verification, including unchanged historical software:

```sh
sh system/ibm_ps2_model30/scripts/run_all.sh
```

The original ROM, DOS 3.30 and IBM Starter Disk are downloaded and checked
against pinned hashes in `work/reference/`; those bytes are not committed.
The aggregate flow runs formal/cover, strict traced build, exact-PC board
and disk fixtures, battery/backend/waveform tests, synthesis and the DOS
application regression. Individual scripts are independently runnable.

## Original application regression

After `scripts/test_harddisk.py` installs DOS, run:

```sh
python3 system/ibm_ps2_model30/scripts/test_real_software.py
```

This boots a private copy of the guest-created disk, executes original
EDLIN and BASICA, and checks application results and DOS-written files.
EDLIN's new/edited file and backup have independent exact-byte checks.
BASICA runs the [prime workload](tb/software/README.md), saves and reloads
it through DOS, and checks software square-root arithmetic. The complete
`run_all.sh` includes this regression after the disk-install test. Detailed
measured outcomes belong in the [verification report](report/final_report.md).
