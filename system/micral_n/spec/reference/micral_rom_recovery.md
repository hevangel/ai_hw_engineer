# Micral N original ROM recovery

The platform ships the original 1973/74 R2E firmware: the boot EPROM
(`src/rom/micral_bootloader.bin`, 256 bytes at 0x0000–0x00FF) and the MIC-01
monitor (`src/rom/micral_monitor.bin`, 2048 bytes at 0x3800–0x3FFF), composed
into a full memory image by `scripts/prepare_rom_image.py`.

## Provenance

The dumps were made 5 April 2021 by Jean-François Del Nero (hxc2001) with a
custom Intel 1702A dumper during the restoration of a Micral N, and published
on [the restoration page](https://hxc2001.pages-perso.free.fr/micral-n/index.html)
together with the [MO5 association's analysis](https://mo5.com/site/lecture-et-sauvegarde-des-roms-du-micral-n/).
The restoration page publishes CRC32/MD5/SHA-256 for every EPROM and serves
the images from its `roms/` directory. Both files downloaded from there match
all three published checksums:

| File | Size | CRC32 | MD5 | SHA-256 |
|---|---|---|---|---|
| `micral_bootloader.bin` (`MIC_1_EPROM_CARTE_MEM_4K.BIN`) | 256 | 922ECF5C | `87fda1ea8240905e300e9d44b3a5d953` | `19d8fcbbd326a6ba08d7dcad5b2ab173be9b4a90ca36d8d3fdd50fe8424d31db` |
| `micral_monitor.bin` (`MIC_38_3F.BIN`) | 2048 | 8D212125 | `30238d34cf20bab5c6b0344a8d43df27` | `781db385d40582f187b4b2f70c2441743ffb90da06259908e99954467cf1cc57` |

No license statement accompanies the dumps; they are treated as the MO5 /
hxc2001 restoration project's preservation material. The R2E manual (chapter
II.2.2) independently confirms the monitor's location: "MIC 01 MONITOR is
stored in ROM between 3800 to 3FFF".

## Memory map and entry points

| Region | Address | Contents |
|---|---|---|
| Boot EPROM | 0x0000–0x00FF | 12400/SB memory-card 1702A overlay; starts `C0 44 48 00` = `LAA; JMP $0048` (floppy loader) |
| Monitor ROM | 0x3800–0x3FFF | eight 1702A EPROMs = the MIC-01 monitor |
| Monitor workspace | 0x07E0–0x07FF | RAM the monitor owns (manual II.2.2) |

- **Initial monitor entry**: `JMP $3B30`, injected from the front panel in
  SUBstitute mode as `44 30 3B` over the fetches at PC 0/1/2 (manual II.3.1).
  The stub saves the registers on the Pile card, then the monitor builds its
  warm-restart vector at 0x07FD–0x07FF from two Pile pops and continues to
  the regular entry.
- **Regular entry**: `JMP $3B49`.

## Verification on this platform

`tb/tb_monitor.sv` boots the monitor through the manual's panel procedure and
checks the documented teletype protocol byte-for-byte: the prompt line
(CR, LF, space — the monitor sends CR as 0x8D, i.e. with its software parity
bit), a command letter echoed and followed by `: `, `?` for an unknown
command, CR echoing with parity and cancelling the `M` command's address
entry, and the prompt returning. `scripts/test_backend.py` repeats the same
flow over HTTP. Both regressions fail if the ROM bytes change.

## Modeled and unmodeled board devices

- **Modeled**: the ASR-33 teletype via the 11100/SC async card (input group
  0: byte 0 data, byte 1 status with bit 0 input-ready and bit 7
  output-ready; OUT 8 transmits) and the Pile card (byte LIFO: OUT 30 pushes
  the accumulator, INP group 6 pops; empty reads return zero).
- **Not modeled**: the floppy system (so the boot EPROM's loader path halts
  with no disk — the boot is bypassed exactly as the manual prescribes), the
  real-time clock / RST 7 interrupt, and the Canal card.
