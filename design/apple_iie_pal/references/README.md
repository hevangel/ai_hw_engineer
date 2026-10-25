# Apple IIe PAL source cache

Original manufacturer documentation is the specification oracle. The scan of
the *Apple IIe Technical Reference Manual, 2nd edition* (© Apple Computer 1985)
is cached at repo-root
[`references/Apple_IIe_TRM_1985.pdf`](../../../references/Apple_IIe_TRM_1985.pdf)
for offline study. A separate 1987 edition is also available at
[`references/Apple_IIe_TRM_1987.pdf`](../../../references/Apple_IIe_TRM_1987.pdf).
The scan and third-party sources are reference material; the design
specification remains the implementation contract.

| File / item | Source | Notes |
|---|---|---|
| [*Apple IIe TRM*, 2nd edition (1985) PDF](../../../references/Apple_IIe_TRM_1985.pdf) | [Internet Archive scan `a2etrm`](https://archive.org/details/a2etrm) | Table 7-5 (65C02 timing signals: Q3 "2.045 MHz with asymmetrical duty cycle", VID7M "40-column dot clock"), Table 7-8 (the PAL's complete pinout and signal descriptions), Table 7-10 (Q3 "alternate RAM/column-address strobe"), Figure 7-1 (the 280 ns + 210 ns = 490 ns phase decomposition pinning Q3's 4/3-tick split), Chapter 2/Chapter 7 text (LDPS' cadence: once per microsecond in 40-column; twice, once per clock phase, in 80-column). OCR text can lose symbols; inspect the scan for complement bars. |
| Jim Sather, *Understanding the Apple IIe* | (under copyright; not redistributed) | Source of the statement that the SEGB, gated GR', VID7 and 80COL' inputs feed only the LDPS'/VID7M generation. The fuse-level equations are **not** reproduced here; their absence is the boundary of this reconstruction (spec A4/A5). |
| [frozen-signal Apple_IIe_MMU_IOU](https://github.com/frozen-signal/Apple_IIe_MMU_IOU) | GitHub, CC0-1.0 | Does not cover the PAL; cited for the row/column RA-bus phase convention shared with the MMU/IOU designs and for the Q3-fall timing comments in its RA mux. |
| [Wikipedia: Apple IIe](https://en.wikipedia.org/wiki/Apple_IIe) and [Centre for Computing History: Apple IIe](https://www.computinghistory.org.uk/det/209/Apple-IIe) | web | Introduction date (January 1983); exact day not asserted. |

The PAL16R8 is Apple-programmed and was shipped only in IIe-family machines
(the European "PAL IIe" uses different equations, out of scope per spec A1).
