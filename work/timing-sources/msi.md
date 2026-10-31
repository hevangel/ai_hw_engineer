# 74LS MSI propagation delays — datasheet provenance (Apple II board timing)

Scope: the 15 MSI parts listed in the task. One `typ`/`max` pair per cited datasheet row, at
VCC = 5 V, TA = 25 °C, CL = 15 pF where the manufacturer publishes that condition.

**Evidence tier for this file:** every row below was read by me from the rendered page image of
the cited PDF page (crops in `work/timing/crops/`), not from memory or from a product page.
Rows marked *UNVERIFIED* were not readable in this run.

**Fetch note (important):** `fetch_content` on `https://www.ti.com/lit/ds/symlink/*.pdf` returns
`fetch_content_invalid_response` in this environment, so no PDF could be re-downloaded today.
I read the TI PDFs already cached in `work/timing/ds/` (downloaded in a prior run of this batch);
their identity was checked against the page headers printed in the scans (`SN54LSxxx/SN74LSxxx`)
and, for 74LS74, against TI's document-viewer header (`SDLS119`, 5 content pages). The `url`
column is the download source recorded for that cached file.

**Conventions**
- `page` = PDF page number inside the cited file (the printed folio where the crop shows one).
- Where a device has several delay rows, all material rows are listed. The **bold** row is the
  slowest published MAX at CL = 15 pF and is the value to use as T_PD.
- `doc id` = TI literature number when it is actually printed/visible; "not visible" means the
  scan's header was cut in the page image and I did not verify a number.
- In the quote column, `\|` marks a cell boundary of the original table (so the quote keeps the
  datasheet's column order).

| part | from->to | typ | max | load | doc id | section | page | url | verbatim quote |
|---|---|---|---|---|---|---|---|---|---|
| 74LS74 | **CLR, PRE or CLK -> Q or Q̄ (tPHL)** | 25 | 40 | RL = 2 kΩ, CL = 15 pF | SDLS119 | switching characteristics, VCC = 5 V, TA = 25°C (see note 3) | 5 | https://www.ti.com/lit/ds/symlink/sn74ls74a.pdf | `tPHL \| CLR, PRE or CLK \| Q or Q̄ \| RL = 2 kΩ, CL = 15 pF \| 25 \| 40 \| ns` |
| 74LS74 | CLR, PRE or CLK -> Q or Q̄ (tPLH) | 13 | 25 | RL = 2 kΩ, CL = 15 pF | SDLS119 | switching characteristics, VCC = 5 V, TA = 25°C (see note 3) | 5 | https://www.ti.com/lit/ds/symlink/sn74ls74a.pdf | `tPLH \| CLR, PRE or CLK \| Q or Q̄ \| RL = 2 kΩ, CL = 15 pF \| 13 \| 25 \| ns` |
| 74LS138 | **Binary Select -> Any, 2 levels of delay (tPHL)** | 18 | 41 | RL = 2 kΩ, CL = 15 pF | not visible (TI SN54LS138/SN74LS138) | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls138.pdf | `tPHL \| Binary Select \| Any \| 2 \| RL = 2 kΩ, CL = 15 pF, See Note 2 \| 18 \| 41 \| ns` |
| 74LS138 | Binary Select -> Any, 2 levels (tPLH) | 11 | 20 | RL = 2 kΩ, CL = 15 pF | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls138.pdf | `tPLH \| Binary Select \| Any \| 2 \| 11 \| 20 \| ns` |
| 74LS138 | Binary Select -> Any, 3 levels (tPHL / tPLH) | 20 / 21 | 39 / 27 | RL = 2 kΩ, CL = 15 pF | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls138.pdf | `tPLH \| Binary Select \| Any \| 3 \| 21 \| 27 \| ns` ; `tPHL \| Binary Select \| Any \| 3 \| 20 \| 39 \| ns` |
| 74LS138 | Enable -> Any, 2 / 3 levels (tPHL, slower enable path) | 20 / 13 | 32 / 38 | RL = 2 kΩ, CL = 15 pF | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls138.pdf | `tPHL \| Enable \| Any \| 2 \| 20 \| 32 \| ns` ; `tPHL \| Enable \| Any \| 3 \| 13 \| 38 \| ns` |
| 74LS139 | **Binary Select -> Any, 3 levels of delay (tPHL)** | 25 | 38 | RL = 2 kΩ, CL = 15 pF | not visible (TI SN54LS139A/SN74LS139A) | switching characteristics, VCC = 5 V, TA = 25°C (see Note 2) | 3 | https://www.ti.com/lit/ds/symlink/sn74ls139a.pdf | `tPHL \| Binary Select \| Any \| 3 \| RL = 2 kΩ, CL = 15 pF \| 25 \| 38 \| ns` |
| 74LS139 | Binary Select -> Any, 2 levels (tPHL / tPLH) | 22 / 13 | 33 / 20 | RL = 2 kΩ, CL = 15 pF | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 3 | https://www.ti.com/lit/ds/symlink/sn74ls139a.pdf | `tPLH \| Binary Select \| Any \| 2 \| 13 \| 20 \| ns` ; `tPHL \| Binary Select \| Any \| 2 \| 22 \| 33 \| ns` |
| 74LS139 | Enable -> Any, 2 levels (tPHL / tPLH) | 21 / 16 | 32 / 24 | RL = 2 kΩ, CL = 15 pF | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 3 | https://www.ti.com/lit/ds/symlink/sn74ls139a.pdf | `tPLH \| Enable \| Any \| 2 \| 16 \| 24 \| ns` ; `tPHL \| Enable \| Any \| 2 \| 21 \| 32 \| ns` |
| 74LS151 | **A, B or C (4 levels) -> Y (tPLH, '151A column)** | 25 | 38 | CL = 15 pF, RL = 400 Ω | not visible (table device columns are `'150` and `'151A`) | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls151.pdf | `tPLH \| A, B, or C (4 levels) \| Y \| CL = 15 pF, RL = 400 Ω, See Note 4 \| 25 \| 38 \| ns` ('151A columns; '150 columns blank) |
| 74LS151 | A, B or C (4 levels) -> Y (tPHL) | 25 | 38 | CL = 15 pF, RL = 400 Ω | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls151.pdf | `tPHL \| A, B, or C (4 levels) \| Y \| 25 \| 38 \| ns` |
| 74LS151 | Strobe Ḡ -> Y (tPHL / tPLH) | 22 / 21 | 33 / 33 | CL = 15 pF, RL = 400 Ω | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls151.pdf | `tPLH \| Strobe Ḡ \| Y \| 21 \| 33 \| ns` ; `tPHL \| Strobe Ḡ \| Y \| 22 \| 33 \| ns` |
| 74LS151 | D0 thru D7 -> Y (tPHL / tPLH) | 18 / 13 | 27 / 20 | CL = 15 pF, RL = 400 Ω | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls151.pdf | `tPLH \| D0 thru D7 \| Y \| 13 \| 20 \| ns` ; `tPHL \| D0 thru D7 \| Y \| 18 \| 27 \| ns` |
| 74LS153 | **Select -> Y (tPHL)** | 25 | 38 | CL = 15 pF, RL = 2 kΩ | not visible (TI SN54LS153/SN74LS153) | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls153.pdf | `tPHL \| Select \| Y \| CL = 15 pF, RL = 2 kΩ, See Note 3 \| 25 \| 38 \| ns` |
| 74LS153 | Select -> Y (tPLH) | 19 | 29 | CL = 15 pF, RL = 2 kΩ | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls153.pdf | `tPLH \| Select \| Y \| 19 \| 29 \| ns` |
| 74LS153 | Strobe Ḡ -> Y (tPHL / tPLH) | 21 / 16 | 32 / 24 | CL = 15 pF, RL = 2 kΩ | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls153.pdf | `tPLH \| Strobe Ḡ \| Y \| 16 \| 24 \| ns` ; `tPHL \| Strobe Ḡ \| Y \| 21 \| 32 \| ns` |
| 74LS153 | Data -> Y (tPHL / tPLH) | 17 / 10 | 26 / 15 | CL = 15 pF, RL = 2 kΩ | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls153.pdf | `tPLH \| Data \| Y \| 10 \| 15 \| ns` ; `tPHL \| Data \| Y \| 17 \| 26 \| ns` |
| 74LS161 | UNVERIFIED | — | — | — | SDLS060 (cached file header) | switching characteristics not located | — | not recorded (cached as work/timing/ds/74LS161.pdf) | no table found; see notes |
| 74LS166 | **Clear -> output (tPHL)** | 19 | 30 | CL = 15 pF, RL = 2 kΩ | not printed in this scan (SN54LS166A/SN74LS166A) | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls166a.pdf | `tPHL \| Propagation delay time, high-to-low-level output from clear \| CL = 15 pF, RL = 2 kΩ, See Figure 1 \| 19 \| 30 \| ns` |
| 74LS166 | Clock -> output (tPHL) | 14 (min 7) | 25 | CL = 15 pF, RL = 2 kΩ | not printed in this scan | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls166a.pdf | `tPHL \| Propagation delay time, high-to-low-level output from clock \| 7 \| 14 \| 25 \| ns` |
| 74LS166 | Clock -> output (tPLH) | 11 (min 5) | 20 | CL = 15 pF, RL = 2 kΩ | not printed in this scan | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls166a.pdf | `tPLH \| Propagation delay time, low-to-high-level output from clock \| 5 \| 11 \| 20 \| ns` |
| 74LS174 | **Clear -> output (tPHL, 'LS174 column)** | 23 | 35 | CL = 15 pF, RL = 2 kΩ | SDLS068A | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls174.pdf | `tPHL Propagation delay time, high-to-low-level output from clear \| 'LS174: 23 \| 35 \| 'LS175: 20 \| 30 \| ns` |
| 74LS174 | Clock -> output (tPHL / tPLH) | 21 / 20 | 30 / 30 | CL = 15 pF, RL = 2 kΩ | SDLS068A | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls174.pdf | `tPLH \| ... from clock \| 'LS174: 20 \| 30 \| 'LS175: 13 \| 25 \| ns` ; `tPHL \| ... from clock \| 'LS174: 21 \| 30 \| 'LS175: 16 \| 25 \| ns` |
| 74LS175 | **Clear -> output (tPLH / tPHL, 'LS175 column)** | 20 | 30 | CL = 15 pF, RL = 2 kΩ | SDLS068A | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls175.pdf | `tPLH Propagation delay time, low-to-high-level output from clear \| 20 \| 30 \| ns` ; `tPHL ... from clear \| 'LS175: 20 \| 30 \| ns` |
| 74LS175 | Clock -> output (tPLH / tPHL) | 13 / 16 | 25 / 25 | CL = 15 pF, RL = 2 kΩ | SDLS068A | switching characteristics, VCC = 5 V, TA = 25°C | 5 | https://www.ti.com/lit/ds/symlink/sn74ls175.pdf | `tPLH \| ... from clock \| 'LS175: 13 \| 25 \| ns` ; `tPHL \| ... from clock \| 'LS175: 16 \| 25 \| ns` |
| 74LS194 | **Clear -> output (tPHL)** | 19 | 30 | CL = 15 pF, RL = 2 kΩ | not visible (TI SN54LS194A/SN74LS194A) | switching characteristics, VCC = 5 V, TA = 25°C | 7 | https://www.ti.com/lit/ds/symlink/sn74ls194a.pdf | `tPHL \| Propagation delay time, high-to-low level output from clear \| CL = 15 pF, RL = 2 kΩ, See Figure 1 \| 19 \| 30 \| ns` |
| 74LS194 | Clock -> output (tPLH / tPHL) | 14 / 17 | 22 / 26 | CL = 15 pF, RL = 2 kΩ | not visible | switching characteristics, VCC = 5 V, TA = 25°C | 7 | https://www.ti.com/lit/ds/symlink/sn74ls194a.pdf | `tPLH \| Propagation delay time, low-to-high level output from clock \| 14 \| 22 \| ns` ; `tPHL \| ... from clock \| 17 \| 26 \| ns` |
| 74LS195 | **MR -> output (tPHL)** | 19 | 30 | VCC = 5.0 V, CL = 15 pF | none printed (ON Semiconductor SN74LS195A) | AC CHARACTERISTICS (TA = 25°C) | 4 | https://www.sycelectronica.com.ar/semiconductores/74LS195.pdf | `tPHL \| Propagation Delay, MR to Output \| 19 \| 30 \| ns` (Test Conditions: VCC = 5.0 V, CL = 15 pF) |
| 74LS195 | Clock -> output (tPLH / tPHL) | 14 / 17 | 22 / 26 | VCC = 5.0 V, CL = 15 pF | none printed (ON Semiconductor SN74LS195A) | AC CHARACTERISTICS (TA = 25°C) | 4 | https://www.sycelectronica.com.ar/semiconductores/74LS195.pdf | `tPLH \| Propagation Delay, Clock to Output \| 14 \| 22 \| ns` ; `tPHL \| Propagation Delay, Clock to Output \| 17 \| 26 \| ns` |
| 74LS251 | **A, B or C (4 levels) -> Y (tPLH)** | 29 | 45 | CL = 15 pF, RL = 2 kΩ | SDLS085 | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls251.pdf | `tPLH \| A, B, or C (4 levels) \| Y \| CL = 15 pF, RL = 2 kΩ, See Note 2 \| 29 \| 45 \| ns` |
| 74LS251 | A, B or C (4 levels) -> Y (tPHL) | 28 | 45 | CL = 15 pF, RL = 2 kΩ | SDLS085 | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls251.pdf | `tPHL \| A, B, or C (4 levels) \| Y \| 28 \| 45 \| ns` |
| 74LS251 | Ḡ -> Y, output enable (tPZH / tPZL) | 30 / 26 | 45 / 40 | CL = 15 pF, RL = 2 kΩ | SDLS085 | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls251.pdf | `tPZH \| Ḡ \| Y \| 30 \| 45 \| ns` ; `tPZL \| Ḡ \| Y \| 26 \| 40 \| ns` |
| 74LS251 | Ḡ -> W, output disable (tPHZ / tPLZ) | 37 / 15 | 55 / 25 | **CL = 5 pF**, RL = 2 kΩ | SDLS085 | switching characteristics, VCC = 5 V, TA = 25°C | 6 | https://www.ti.com/lit/ds/symlink/sn74ls251.pdf | `tPHZ \| Ḡ \| W \| CL = 5 pF, RL = 2 kΩ, See Note 2 \| 37 \| 55 \| ns` |
| 74LS257 | **S -> Zn (max only; no TYP published)** | — | 21 | CL = 15 pF (54/74LS column) | none printed (Signetics 54S/74S257, 54LS/74LS257) | AC CHARACTERISTICS: VCC = +5.0 V, TA = +25°C | 3 | https://www.datasheets.pl/elementy_czynne/IC/7/74LS257.pdf | `tPLH / tPHL \| Propagation Delay S to Zn \| 54/74S: 15 / 15 \| 54/74LS: — / 21 \| ns \| Figs. 3-1, 3-20` |
| 74LS257 | In -> Zn (max only) | — | 18 | CL = 15 pF (54/74LS column) | none printed | AC CHARACTERISTICS: VCC = +5.0 V, TA = +25°C | 3 | https://www.datasheets.pl/elementy_czynne/IC/7/74LS257.pdf | `tPLH / tPHL \| Propagation Delay In to Zn \| 54/74S: 7.5 / 6.5 \| 54/74LS: — / 18 \| ns \| Figs. 3-1, 3-5` |
| 74LS257 | Output enable / disable, LS (max only) | — | 30 / 30 / 25 | enable: RL = 2 kΩ; disable: CL = 5 pF, RL = 2 kΩ | none printed | AC CHARACTERISTICS: VCC = +5.0 V, TA = +25°C | 3 | https://www.datasheets.pl/elementy_czynne/IC/7/74LS257.pdf | `tPZH / tPZL \| Output Enable Time \| 54/74LS: 30 / 30 \| ns \| RL = 2 kΩ ('LS257)` ; `tPHZ / tPLZ \| Output Disable Time \| 54/74LS: 30 / 25 \| ns \| RL = 2 kΩ, CL = 5 pF ('LS257)` |
| 74LS257 (TI B rev, reference) | Select -> Any (CL = 45 pF only) | 16 / 17 | 21 / 24 | **CL = 45 pF**, RL = 667 Ω | SDLS148 | switching characteristics, VCC = 5 V, TA = 25°C, RL = 667 Ω | 4 | https://www.ti.com/lit/ds/symlink/sn74ls257b.pdf | `tPLH \| Select \| Any \| CL = 45 pF, See Note 3 \| 16 \| 21 \| ns` ; `tPHL \| Select \| Any \| 17 \| 24 \| ns` |
| 74LS259 | **Data -> Any Q (tPLH)** | 19 | 30 | CL = 15 pF, RL = 2 kΩ | SDLS086 | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls259b.pdf | `tPLH \| Data \| Any Q \| CL = 15 pF, RL = 2 kΩ, See Note 3 \| 19 \| 30 \| ns` |
| 74LS259 | Address -> Any Q (tPLH / tPHL) | 17 / 14 | 27 / 20 | CL = 15 pF, RL = 2 kΩ | SDLS086 | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls259b.pdf | `tPLH \| Address \| Any Q \| 17 \| 27 \| ns` ; `tPHL \| Address \| Any Q \| 14 \| 20 \| ns` |
| 74LS259 | CLR / Ḡ -> Any Q | 12 / 15 | 18 / 24 | CL = 15 pF, RL = 2 kΩ | SDLS086 | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls259b.pdf | `tPHL \| CLR \| Any Q \| 12 \| 18 \| ns` ; `tPLH \| Ḡ \| Any Q \| 15 \| 24 \| ns` ; `tPHL \| Ḡ \| Any Q \| 15 \| 24 \| ns` |
| 74LS283 | **C0 -> Any Σ (tPLH)** | 16 | 24 | CL = 15 pF, RL = 2 kΩ | SDLS095A | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls283.pdf | `tPLH \| C0 \| Any Σ \| CL = 15 pF, RL = 2 kΩ, See Note 3 \| 16 \| 24 \| ns` |
| 74LS283 | Ai or Bi -> Σi (tPLH / tPHL) | 15 | 24 | CL = 15 pF, RL = 2 kΩ | SDLS095A | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls283.pdf | `tPLH \| Ai or Bi \| Σi \| 15 \| 24 \| ns` ; `tPHL \| Ai or Bi \| Σi \| 15 \| 24 \| ns` |
| 74LS283 | C0 -> C4 (tPHL / tPLH) | 11 | 22 / 17 | CL = 15 pF, RL = 2 kΩ | SDLS095A | switching characteristics, VCC = 5 V, TA = 25°C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls283.pdf | `tPLH \| C0 \| C4 \| 11 \| 17 \| ns` ; `tPHL \| C0 \| C4 \| 11 \| 22 \| ns` |

## Per-part notes

- **74LS74** — TI's LS part datasheet is the `A` revision (`sn74ls74a.pdf`, SDLS119). The table
  lists one FROM/TO block (`CLR, PRE or CLK` → `Q or Q̄`) with two rows; the asymmetric pair is
  tPLH 13/25 and tPHL 25/40. Worst case 25/40.
- **74LS138** — the *select* path is the slow one (max 41 ns at 2 levels of delay), not the enable
  path (max 32 ns at 2 levels, 38 ns at 3 levels). Do not substitute an "enable is slower" rule here.
- **74LS139** — datasheet is the `A` revision. Worst row is 3-level select tPHL 25/38; the enable
  path is 21/32 and is *not* slower.
- **74LS151** — the TI datasheet's device columns are `'150` and `'151A`; every value above is the
  `'151A` column. I could not confirm that a plain SN74LS151 is the same die/revision, so treat
  these as an A-revision bound and flag them if the board carries an older SN74LS151.
- **74LS161** — **UNVERIFIED.** TI SDLS060 (cached `work/timing/ds/74LS161.pdf`, 40 pages) was
  checked at pages 2, 3, 5, 7, 10 and 11: those pages carry logic symbols, logic diagrams and
  timing waveforms, and no switching-characteristics table was found in the pages I could read. The prior run's
  `work/timing/ls_logic.json` records a Fairchild DM74LS161A value (max 30 ns, **no TYP column**,
  from `https://eater.net/datasheets/74ls161.pdf`, DS006397 p.6, clock→ripple-carry tPHL), but I
  could not re-read that page in this run, so it is *not* promoted into the table above.
- **74LS166** — TI scan prints no SDLS number on the page. Clock rows publish MIN as well
  (7/14/25 and 5/11/20 ns), so for a delay model use TYP/MAX only, per the table convention.
- **74LS174 / 74LS175** — one combined TI table (SDLS068A p.5) with separate `'LS174` and `'LS175`
  column groups. 74LS174's worst row is clear→Q tPHL 23/35; 74LS175's is clear→Q 20/30 (clock→Q is
  faster: 13/25 and 16/25). A separate ON Semiconductor SN74LS175 page (`work/timing/crops/74LS175_p4.png`)
  independently shows MR→output 20/30 and clock 13/25, 16/25, i.e. it agrees.
- **74LS194** — worst row is clear→output tPHL 19/30; clock→output is 14/22 (tPLH) and 17/26 (tPHL).
- **74LS195** — no TI copy was readable. Source is an ON Semiconductor SN74LS195A datasheet (PDF
  hosted on a third-party mirror, no literature number printed). Values are at TA = 25 °C,
  VCC = 5.0 V, CL = 15 pF with **no RL stated** in the AC table. Worst row MR→output 19/30.
- **74LS251** — at CL = 15 pF the slowest published MAX is 45 ns on both the select path (29/45)
  and the enable path (tPZH 30/45). The absolute worst number in the table, 55 ns, belongs to
  Ḡ→W disable at **CL = 5 pF** and must not be used as a 15 pF T_PD. A second slow path worth
  knowing: select 3-level is 20/33, D→Y is 17/28.
- **74LS257** — TI's SN74LS257B (SDLS148) specifies **CL = 45 pF, RL = 667 Ω**, so it does not meet
  the 15 pF condition; the 15 pF data comes from the Signetics 54/74LS257 datasheet, which publishes
  **Min/Max only (no TYP)** and leaves RL unstated for the In→Zn / S→Zn rows (RL = 2 kΩ is given only
  on the enable/disable rows). Use max 21 ns (S→Zn); TYP is not published.
- **74LS259** — worst row is data→Q tPLH 19/30; the address path (17/27) and enable (15/24) are faster.
- **74LS283** — worst row is C0→Σ tPLH 16/24; carry-out paths are faster (C0→C4 max 22).
- All TI `page` values were cross-checked against the OCR page files in `work/timing/ocr2/`, whose
  first line carries the device header for that page (e.g. `SN54LS174,SN54LS175,SN74LS174,SN74LS175`).

## What I could not verify

1. **74LS161** — no switching-characteristics table located (see note).
2. **TI literature numbers for 74LS138, 74LS139, 74LS151, 74LS153, 74LS166, 74LS194** — the scan's
   header band is outside the page crops I could read, so the `doc id` column says "not visible".
   A prior run's OCR of page 1 recorded SDLS014 / SDLS013A / SDLS054 / SDLS055A / (none) / SDLS075
   respectively; I did not re-verify those numbers and did not print them as facts.
3. **PDF re-download** — `fetch_content` cannot read `ti.com/lit/ds/symlink/*.pdf` here
   (`fetch_content_invalid_response`), so the cached copies were used instead of a fresh fetch.
