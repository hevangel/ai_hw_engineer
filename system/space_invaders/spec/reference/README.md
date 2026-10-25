# Reference provenance

Sources for the Space Invaders virtual platform. Originals are cited by
URL; committed copies live in this folder. The copyrighted ROM set is
**not** committed: `scripts/fetch_roms.py` downloads the four PCjs archive
files into the ignored `work/` folder, verifies the pinned git-blob hashes
and cross-checks the ROM CRC-32 values against the canonical MAME driver
checksums.

| File | What it is | Origin |
|---|---|---|
| [invaders.asm](invaders.asm) | David Levy's fully annotated Space Invaders disassembly (ASMX listing), hosted by Computer Archeology. Code-level ground truth: ISR entry points at 0008h/0010h, the `IN 1`/`IN 2` bit masks the game tests, the sound-port latches, the watchdog feeds, the score/credit RAM locations and the famous shield-miss coordinate bug. | <https://www.computerarcheology.com/Arcade/SpaceInvaders/invaders.asm> |
| [invaders.lay](invaders.lay) | MAME color-gel overlay layout (CC0-1.0): red band y 32–62, green y 184–240, partial-width green y 240–260, white base — used verbatim by the web screen. | <https://raw.githubusercontent.com/mamedev/mame/master/src/mame/layout/invaders.lay> |
| INVADERS-{H,G,F,E}.json5 | PCjs archive containers of the original Taito ROM images (2 KiB each), fetched at build time into ignored `work/reference/` | <https://www.pcjs.org/machines/arcade/invaders/rom/>, pinned to jeffpar/pcjs git revision `7d1795cf263f7f63bb6df3cef616a17fa0068f75` |
| Computer Archeology hardware page | Memory map (ROM 0000h–1FFFh, work RAM 2000h–23FFh, VRAM 2400h–3FFFh, 4000h+ mirror), shift-register semantics with the 00→AA→FF example, port definitions, interrupt vector decode `0xC7|(64V<<4)|(!64V<<3)`, screen geometry | <https://www.computerarcheology.com/Arcade/SpaceInvaders/Hardware.html> |
| superzazu i8080 | The independent C emulator driving `scripts/oracle_board.c` (already vendored with license at `design/amd_am9080/references/superzazu/`); the same external oracle used by the intel_8080 chip design | <https://github.com/superzazu/invaders> (emulator core) |
