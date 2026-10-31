# 74LS gate propagation delays — datasheet evidence

Source-of-truth table for `T_PD` per 74LS gate package on the Apple II rev-0 board.
Every number below was read from the cited TI datasheet page, not inferred.

Conditions: **VCC = 5 V, TA = 25 °C, CL = 15 pF**, as printed in each switching-characteristics table.
Where a device publishes more than one propagation row (different input, or "other input" state),
the row with the largest MAX is used in the table and every other row is listed under *Notes*.

Legend for the `doc id` column: a literature number is given only where it is printed in
machine-readable text on the TI PDF. `not printed on sheet` means the scan's running header
carries only part numbers and the title — no SDLS number appears anywhere in that document.

Legend for the `verbatim quote` column: entries prefixed `[text]` are the extractor's literal output
(word spacing collapses in that extraction). Entries prefixed `[img]` are my transcription of the
printed table on the rendered page image, with cells separated by `/`; the numbers and conditions
are as printed, the punctuation is mine.

| part | tPLH typ | tPLH max | tPHL typ | tPHL max | load | doc id | section | page | url | verbatim quote |
|---|---|---|---|---|---|---|---|---|---|---|
| 74LS00 | 9 | 15 | 10 | 15 | RL = 2 kΩ, CL = 15 pF | SDLS025D | 6.9 Switching Characteristics: SNx4LS00 | 7 | https://www.ti.com/lit/ds/symlink/sn74ls00.pdf | [text] "tPLHAorB Y RL=2kΩandCL=15pF9 15nstPHL 10 15" |
| 74LS02 | 10 | 15 | 10 | 15 | RL = 2 kΩ, CL = 15 pF | not printed on sheet | switching characteristics, VCC = 5 V, TA = 25°C (see note 3) | 4 | https://www.ti.com/lit/ds/symlink/sn74ls02.pdf | [img] "tPLH / A or B / Y / RL = 2 kΩ, CL = 15 pF / 10 15 ns" ; "tPHL / 10 15 ns" |
| 74LS04 | 9 | 15 | 10 | 15 | RL = 2 kΩ, CL = 15 pF | SDLS029C | switching characteristics, VCC = 5 V, TA = 25 °C (see Figure 2) | 6 | https://www.ti.com/lit/ds/symlink/sn74ls04.pdf | [text] "tPLHA Y RL = 2 k Ω, CL = 15 pF915nstPHLA Y RL = 2 k Ω, CL = 15 pF1015ns" |
| 74LS08 | 8 | 15 | 10 | 20 | RL = 2 kΩ, CL = 15 pF | SDLS033 | switching characteristics, VCC = 5 V, TA = 25°C (see note 2) | 4 | https://www.ti.com/lit/ds/symlink/sn74ls08.pdf | [img] "tPLH / A or B / Y / RL = 2 kΩ, CL = 15 pF / 8 15 ns" ; "tPHL / 10 20 ns" |
| 74LS11 | 8 | 15 | 10 | 20 | RL = 2 kΩ, CL = 15 pF | SDLS131 | switching characteristics, VCC = 5 V, TA = 25°C (see note 2) | 3 | https://www.ti.com/lit/ds/symlink/sn74ls11.pdf | [img] "tPLH / A, B or C / Y / RL = 2 kΩ, CL = 15 pF / 8 15 ns" ; "tPHL / 10 20 ns" |
| 74LS20 | 9 | 15 | 10 | 15 | RL = 2 kΩ, CL = 15 pF | not printed on sheet | switching characteristics, VCC = 5 V, TA = 25°C (see note 2) | 4 | https://www.ti.com/lit/ds/symlink/sn74ls20.pdf | [img] "tPLH / Any / Y / RL = 2 kΩ, CL = 15 pF / 9 15 ns" ; "tPHL / 10 15 ns" |
| 74LS32 | 14 | 22 | 14 | 22 | RL = 2 kΩ, CL = 15 pF | not printed on sheet | switching characteristics, VCC = 5 V, TA = 25°C (see note 3) | 4 | https://www.ti.com/lit/ds/symlink/sn74ls32.pdf | [img] "tPLH / A or B / Y / RL = 2 kΩ, CL = 15 pF / 14 22 ns" ; "tPHL / 14 22 ns" |
| 74LS51 | 12 | 20 | 12.5 | 20 | RL = 2 kΩ, CL = 15 pF | SDLS113 | switching characteristics, VCC = 5 V, TA = 25°C (see note 3) | 5 | https://www.ti.com/lit/ds/symlink/sn74ls51.pdf | [img] "tPLH / Any / Y / RL = 2 kΩ, CL = 15 pF / 12 20 ns" ; "tPHL / 12.5 20 ns" |
| 74LS86 | 20 | 30 | 13 | 22 | RL = 2 kΩ, CL = 15 pF, see note 3 | SDLS124 | switching characteristics, VCC = 5 V, TA = 25 °C | 4 | https://www.ti.com/lit/ds/symlink/sn74ls86a.pdf | [img] "tPLH / A or B / Other input high / CL = 15 pF, RL = 2 kΩ / 20 30 ns" ; "tPHL / 13 22 ns" |

Units: ns. `load` is the test condition printed on the same row as the numbers.

## Notes

- **74LS00** — new-template sheet, genuine text layer; table 6.9 sits on printed page 7 (per the
  document's own table of contents). Both rows use RL = 2 kΩ, CL = 15 pF; the TYP/MAX pair 9/15
  is tPLH and 10/15 is tPHL. Worst row is tPHL, so 10/15 is the board value.
- **74LS02** — full table: tPLH 10/15, tPHL 10/15, "A or B" → Y. Worst row 10/15.
- **74LS04** — the sheet prints one MIN/TYP/MAX group covering both SN54LS04 and SN74LS04:
  tPLH 9/15, tPHL 10/15, "A" → Y. Page 6 follows the printed footer numbering: p.3 is the logic
  diagram, p.4 the schematics, p.5 absolute maximum + SN5404 tables, p.6 SN5404 switching +
  SN54LS04/SN74LS04 tables, p.7 the SN54S04 tables.
- **74LS08** — tPLH 8/15, tPHL 10/20, "A or B" → Y. Worst row 10/20.
- **74LS11** — tPLH 8/15, tPHL 10/20, "A, B or C" → Y. Worst row 10/20.
- **74LS20** — tPLH 9/15, tPHL 10/15, "Any" → Y. Worst row 10/15. The page also carries
  separate SN54LS20 / SN74LS20 columns for the electrical table, but a single TYP/MAX group for
  switching, i.e. the same delays for both temperature grades.
- **74LS32** — tPLH 14/22, tPHL 14/22, "A or B" → Y. Both edges identical.
- **74LS51** — tPLH 12/20, tPHL 12.5/20, "Any" → Y. Worst row tPHL 12.5/20.
- **74LS86** — two condition rows, both CL = 15 pF and RL = 2 kΩ:
  *other input low* tPLH 12/23, tPHL 10/17; *other input high* tPLH 20/30, tPHL 13/22.
  Worst pair 20/30 (tPLH, other input high), so that row is tabulated; 13/22 is its tPHL.

## How each number was read (evidence tier)

- **Text layer, directly quotable:** 74LS00 (`SDLS025D`), 74LS04 (`SDLS029C`). The extractor
  returns the switching table itself, and the quotes above are its literal output (word spacing
  collapses in that extraction, which is why the 74LS04 quote reads `pF915ns`).
- **Page image, transcribed:** 74LS02, 74LS08, 74LS11, 74LS20, 74LS32, 74LS51, 74LS86. TI's PDFs
  for these parts are image-only scans: `fetch_content` returns just the running headers and the
  package addendum, no table text. Values were read from 300 dpi renders of the exact TI pages,
  kept as `work/timing/crops/ti_74LS02_p4.png`, `ti_74LS08_p4.png`, `ti_74LS11_p3.png`,
  `t_74LS20_p4.png`, `t_74LS32_p4.png`, `t_74LS51_p5.png`, `t_74LS86_p4.png`, and cross-checked
  against the per-page OCR dumps in `work/timing/ocr/` and `work/timing/ocr2/`.
  These transcriptions agree, part for part, with the rows already in
  `work/timing/ls_logic.json`.
- **Page numbers** are printed page numbers; `ti_74LS08_p4.png` shows the printed footer "4",
  which fixes the convention used for the other crops from the same render batch.

## Open item: unconfirmed literature numbers

The TI scans for 74LS02, 74LS20 and 74LS32 print **no** SDLS number in their running headers, and
OCR of every page of those three PDFs finds none. `work/timing/build_json.py` nevertheless records
`SDLS027` (74LS02), `SDLS079` (74LS20) and `SDLS100` (74LS32). Those three literals are **not
corroborated by anything in the TI documents** and should be treated as unverified until checked
against a paper databook or a TI page that prints the number. The delays themselves are unaffected:
they were read off the page images, and those pages are cited by URL + printed page above.

## What was tried for the image-only sheets

- `https://www.ti.com/lit/ds/symlink/sn74ls{02,08,11,20,32,51}.pdf` and `.../sn74ls86a.pdf` —
  reachable, but body pages carry no text layer (headers/addendum only).
- Mirrors of the same TI documents (`docs.rs-online.com/0402/A700000011300733.pdf`,
  `pdf.direnc.net/upload/sn74ls08-datasheet.pdf`) — identical image-only body.
- `https://www.ti.com/document-viewer/SN74LS32/datasheet`, `https://www.ti.com/lit/gpn/SN74LS32`,
  `https://www.ti.com/lit/gpn/SN74LS02`, `https://www.ti.com/lit/pdf/sdls033`,
  `https://www.ti.com.cn/lit/ds/symlink/sn74ls32.pdf` — no table text returned.
- `web.archive.org` copies and `r.jina.ai` reader — not retrievable from this environment.
- `alldatasheet.com` per-page text — request refused.
- Local OCR (`autoclaw-pdf-ocr`) — needs a Node/CLI shell, which this session does not have; the
  pre-existing renders and OCR dumps in `work/timing/` were used instead.
