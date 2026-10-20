# Firmware and character-ROM provenance

The fetcher pins AppleWin commit
736a12b0a2d59d122ec3d7257497d4ff1fc5c029, resource directory:
https://github.com/AppleWin/AppleWin/tree/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/resource

- Original Apple2e.rom: 16,384 bytes, SHA-256
  1fb812584c6633fa16b77b20915986ed1178d1e6fc07a647f7ee8d4e6ab9d40b.
- Apple2e_Enhanced_Video.rom: 4,096 bytes, SHA-256
  52c3b87900ac939f6525402cab1ccfd8f8259290fc6df54da48fb4c98ae3ed0f.

Historical firmware remains copyrighted by its original owners. Neither
image is committed or relicensed. The fetcher verifies size and SHA-256 on
every run; files and generated hex remain in ignored work/. No external CPU
executes instructions. The renderer's address convention is grounded in
Sather Table 8.3 and cross-checked against AppleWin's NTSC_CharSet.cpp at the
same pinned revision (https://github.com/AppleWin/AppleWin/blob/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/source/NTSC_CharSet.cpp).
No emulator source is linked or copied into the runtime. The external font
is an enhanced representation; original-IIe mask-font identity is not claimed.
