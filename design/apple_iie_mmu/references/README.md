# Apple IIe MMU source cache

Original manufacturer documentation is the specification oracle. The OCR text
layer of the *Apple IIe Technical Reference Manual, 2nd edition* (© Apple
Computer 1985) is cached locally for offline study; the scan itself and all
third-party sources are used as references only.

| File / item | Source | Notes |
|---|---|---|
| `Apple_IIe_TRM_2nd_ed_ocr.txt` | [archive.org item `Apple_IIe_Technical_Reference_Manual`](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) (OCR `*_djvu.txt` derivative) | Chapter 4 memory organization, Chapter 6 I/O memory, Chapter 7 custom ICs, Appendix I Monitor listing. Local copy kept out of Git; re-download from the item page if absent. |
| [AppleWin](https://github.com/AppleWin/AppleWin) `Memory.cpp`, `LanguageCard.cpp` | GitHub, GPL | Reference artifact for the soft-switch map, reset state and the prewrite rule (cites Sather *Understanding the Apple IIe* p.5-23). Not redistributed. |
| [frozen-signal Apple_IIe_MMU_IOU](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) | GitHub, CC0 | Schematic-derived, hardware-validated reimplementation; source of the `MA12` interleave equation, CXXXOUT/RW245/CASEN equations, MPON detector and $C08x state machine. Independent work here starts from the TRM tables and uses it only to pin undocumented details. |
| [Wikipedia: Apple IIe](https://en.wikipedia.org/wiki/Apple_IIe) and [Centre for Computing History: Apple IIe](https://www.computinghistory.org.uk/det/209/Apple-IIe) | web | Introduction date (January 1983); exact day not asserted. |

The MMU (Apple 341-0266) and IOU (341-0267) are Synertek full-custom DIP-40
parts introduced with the Apple IIe in January 1983. The IOU and PAL are
candidates for separate designs; the MMU here is specified so a future
`system/apple_iie` build can wire it to the existing `mos_6502` core and the
Apple II board inventory.
