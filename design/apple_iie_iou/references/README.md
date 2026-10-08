# Apple IIe IOU source cache

Original manufacturer documentation is the specification oracle. The OCR text
layer of the *Apple IIe Technical Reference Manual, 2nd edition* (© Apple
Computer 1985) is cached locally for offline study (repo-root
`references/Apple_IIe_TRM_1982_text.txt`, untracked); the scan itself and all
third-party sources are used as references only.

| File / item | Source | Notes |
|---|---|---|
| *Apple IIe TRM* OCR text | [archive.org item `Apple_IIe_Technical_Reference_Manual`](https://archive.org/details/Apple_IIe_Technical_Reference_Manual) (OCR `*_djvu.txt` derivative) | Chapter 2 (soft switches Table 2-10, keyboard Table 2-2), Chapter 7 (IOU pinouts Figure 7-3/Table 7-7, RAM address multiplexing Table 7-9, video counters, display address mapping Tables 7-11/7-12/7-13, Figures 7-10 and 2-8 display maps). Local copy kept out of Git. |
| [frozen-signal Apple_IIe_MMU_IOU](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) | GitHub, CC0-1.0 | Schematic-derived, hardware-validated VHDL reimplementation. Source of the address-latch trick (RA-bus row-phase capture), the 74LS138 C0xx decode equations, the scanner counter structure (HPE' reload, TC vertical load values), the character-ROM RA9'/RA10' gates and the keyboard auto-repeat chain. Its `IOU_TB_SCANNER_MUX_TEXT/HIRES` testbenches pin the full-frame expected address sequences (citing Sather *Understanding the Apple IIe* pp. 5-9, 5-15..5-18) adopted here as behavioral ground truth. Independent work here starts from the TRM tables and uses it only to pin details the manual garbles in OCR. |
| Jim Sather, *Understanding the Apple IIe* | (via the above) | The Σ-fold addition (p. 5-9) and the display maps (pp. 5-15..5-18). |
| [Wikipedia: Apple IIe](https://en.wikipedia.org/wiki/Apple_IIe) and [Centre for Computing History: Apple IIe](https://www.computinghistory.org.uk/det/209/Apple-IIe) | web | Introduction date (January 1983); exact day not asserted. |

The IOU (341-0267) and MMU (341-0266) are Synertek full-custom DIP-40 parts
introduced with the Apple IIe in January 1983. IOUDIS/DHIRES (Enhanced IIe)
are implemented from the TRM alone (the CC0 reference predates them); see
assumption A5 in [the spec](../spec/spec.md).
