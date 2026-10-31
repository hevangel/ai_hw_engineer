# Propagation-delay sources — Signetics 8T28 and 8T97 (Apple II rev-0 bus drivers)

Target conditions for the board timing table: VCC = 5 V, CL = 15 pF, TA = 25 °C.

**Headline finding:** neither Signetics datasheet specifies at CL = 15 pF. The 8T97
AC table is specified at **CL = 50 pF**, so a 15 pF entry in the board table cannot be
sourced from it — it can only be *bounded* by the 50 pF number. The 8T28 Signetics
datasheet could not be read at all (image-only scan, AC page beyond reach); an AMD
second-source datasheet for the same part number gives 17 ns max.

## Table

| part | path | typ | max | load | doc | page | url | verbatim quote |
|---|---|---|---|---|---|---|---|---|
| 8T97 | data A→Y, tPLH | 8 ns | 12 ns † | CL = 50 pF, S1/S2 closed, TA = 25 °C, VCC = 5.0 V | Signetics *8T95, 96, 97, 98 — Hex Buffers/Inverters, High Speed Hex 3-State Buffers/Inverters*, Product Specification, 4 Dec 1985 (lit. 853-0445 81495) | 6-53 | https://www.parastream.com/downloads/datasheets/Signetics%208T95,%2096,%2097,%2098.pdf | "Propagation delay tPLH · S1, S2 are closed, CL = 50pF · 12 · 11 · Data inputs to data outputs" |
| 8T97 | data A→Y, tPHL | 8 ns | 13 ns † | CL = 50 pF, S1/S2 closed, TA = 25 °C, VCC = 5.0 V | same | 6-53 | same | "Propagation delay tPHL · S1, S2 are closed, CL = 50pF · 13 · 10 ns" |
| 8T97 | enable/disable (3-state) | not read | not read | — | same | 6-53 | same | table page not renderable — see note 3 |
| 8T28 | data (driver DIN→bus and receiver bus→ROUT) | **UNVERIFIED** | **UNVERIFIED** | — | Signetics *8T26A, 28 — 3-State Quad Bus Transceiver*, Product Specification (6 pp.) — image-only scans, AC page not reachable | — | — | UNVERIFIED |
| 8T28 *(AMD Am8T28, second source — cross-check only)* | driver DIN→bus; receiver bus→ROUT | not read | 17 ns | Figure 1 / Figure 2 load circuits, TA = +25 °C, VCC = 5.0 V | AMD *Am8T26A • Am8T28 — Schottky Three-State Quad Bus Driver/Receiver* | 12-84 (front page), table on 12-85 | https://datasheet.octopart.com/N8T26B-AMD-datasheet-182221349.pdf | "Driver propagation delay - 14ns max. for 8T26A 17 ns max. for 8T28" / "Receiver propagation delay - 14ns max. for 8T26/ 17ns max. for 8T28" |

† The 12 / 13 ns figures come from the AC ELECTRICAL CHARACTERISTICS table on p. 6-53,
which exists only as scanned page images. `fetch_content` cannot extract them (no text
layer) and the OCR service used caps at 3 pages per PDF, so p. 6-53 was never rendered.
The numbers were read from keyword snippets of **three independent scans of the same
document** (parastream, blog.kevtris.org, elinfor), which agree on the rows
(tPLH: 12 / 11; tPHL: 13 / 10 at CL = 50 pF). The mapping of 12/13 to the 8T95/97 column
group is an inference from the DC table's column split (8T95/97 vs 8T96/98) and the
typical-delay ranking (8 ns for 95/97 vs 6.5 ns for 96/98). Treat max as "12 ns (tPLH) /
13 ns (tPHL), ±one column" until the page image is read.

## What is actually verified, and how

**Verified from rendered page text (OCR of the page):**

- 8T97 typical delay, p. 6-50:
  `TYPE | TYPICAL PROPAGATION DELAY | TYPICAL SUPPLY CURRENT (TOTAL)`
  `N8T95 8ns 65mA · N8T96 6.5ns 59mA · N8T97 8ns 65mA · N8T98 6.5ns 59mA`
  Commercial range `Vcc = 5V ±5%; TA = 0°C to +70°C`; document footer
  "December 4, 1985", doc id "853-0445 81495".
- 8T97 DC table, p. 6-52: two device groups only — `8T95/97` and `8T96/98`
  (this is the basis of the column-split inference above).
- 8T97 test circuit, p. 6-52: pulse gen 3 V / 1 MHz, tr = tf ≤ 10 ns, "CL includes
  probe and jig capacitance"; 3-state test uses switches S1/S2.
- AMD Am8T28 max delay 17 ns (driver and receiver), p. 12-84 bullets quoted above.
- AMD switching table header, p. 12-85: "Switching Characteristics (TA = +25°C,
  VCC = 5.0V)" with separate Min/Typ/Max columns for Am8T26A and Am8T28, and rows
  "Driver Input to Bus", "Bus to Receiver Output", "Driver Enable to Bus",
  "Receiver Enable to Receiver Output" — the OCR of the numeric cells is corrupted,
  so only the 17 ns max from the front page is quoted.

**Inferred (label as such, do not ship as a datasheet value):** the assignment of
12 ns / 13 ns to 8T97 rather than to 8T96/98.

**Not known:** any Signetics 8T28 propagation delay; any 8T97 enable/disable time.

## Enable/disable times vs data-path delay

- **8T97 (Signetics 1985):** the datasheet *does* have a separate 3-state switching
  section — p. 6-52 defines the S1/S2 switch positions for tpZH/tpZL/tpHZ/tpLZ and
  p. 6-53 carries the matching rows. Those rows were **not read** (page 4 of the scan).
  So: structure present, numbers unknown.
- **8T26A (same Signetics family, verified):** the Aug 1987 Product Specification
  separates them explicitly — data path "Propagation delay, DIN to DOUT, CL = 300pF:
  14 ns"; then "Data enable to data output, Hi-Z to 0: 25 ns", "Data enable to data
  output, 0 to Hi-Z: 20 ns", "Receive enable to receive output, Hi-Z to 0: 20 ns",
  "Receive enable … 0 to Hi-Z: 15 ns". Enable/disable is therefore ~1.5–2× the
  data-path delay and must not be folded into T_PD.
  (https://datasheet.sisoog.com/file/7a657573/datasheet/872bb8c7afcbc209c638b35774e24b061511a0b2.pdf, p. 695)
- **8T28:** unknown for the Signetics part; the AMD sheet lists enable rows
  (Driver Enable to Bus, Receiver Enable to Receiver Output) but the OCR of those
  cells is unreadable.

## Where I looked (dead ends, so nobody repeats them)

- `https://www.parastream.com/.../Signetics 8T95, 96, 97, 98.pdf` — 4-page scan,
  image-only; the server also blocks `fetch_content` (HTML and PDF both fail).
- `http://blog.kevtris.org/blogfiles/corememory/n8t98n.pdf` and
  `https://www.elinfor.com/pdf/Signetics/8T95_Signetics.pdf` — same document, same limits.
- `http://www.applelogic.org/files/8T28.pdf` — **not** a Signetics datasheet: it is a
  Fairchild interface databook page (logic/connection diagrams plus a Fairchild
  cross-reference table listing 8T26/8T28 with Ipd 13/16 ns). Secondary, not used.
- `http://bitsavers.org/components/signetics/_dataBooks/1981_Signetics_Logic_Interface.pdf`
  — has a text layer and does contain "8T26A, 28" and "8T95,96,97,98" sections, but the
  8T pages sit ~page 91–96 of ~100 and the fetch truncates around page 11.
- `1972_Signetics_8000_Series_TTL_MSI.pdf`, `1978_Signetics_TTL_Data_Manual.pdf` —
  OCR'd but far too large to reach the 8T pages via this fetch path; the 1972 book
  stops at 8T26 anyway (no 8T28).
- alldatasheet / datasheetarchive / digchip / ic37 — deep-link protection, cookie
  walls, or image-only scans; archive.org APIs and the Wayback CDX endpoint were
  unreachable from this environment.
- TI-style text PDFs (e.g. SN74LS00) extract fine — the failure is specific to these
  image-only Signetics scans.

## Consequence for the board timing table

- 8T97: enter **8 ns typ / 13 ns max at CL = 50 pF**, and record in the table's notes
  that the datasheet load is 50 pF, not 15 pF. Using the 50 pF max at 15 pF is
  conservative (real 15 pF delay will be lower), but it is not the datasheet's
  15 pF number because no such number exists.
- 8T28: the Signetics value is **UNVERIFIED**. If the table needs a number now, the
  AMD second-source 17 ns max is the only manufacturer-published figure found, and it
  must be labelled as AMD, not Signetics.
