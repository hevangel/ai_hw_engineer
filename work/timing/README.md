# 74LS propagation-delay provenance (Apple II rev-0 board)

`ls_logic.json` holds one `T_PD` pair per 74LS part used on the rev-0 board.

## Convention

- `tpd_typ_ns` / `tpd_max_ns` are the **worst-case published (TYP, MAX) pair from a single
  parameter row** in the manufacturer's switching-characteristics table at
  VCC = 5 V, CL = 15 pF, TA = 25 °C. Where a device has several paths (select, enable,
  clear, clock), the row with the largest MAX is used so the board model is not optimistic.
  Every other path is listed in that part's `notes`.
- Datasheets that publish only Min/Max (Fairchild, Signetics) get `tpd_typ_ns: null`.
- `page` is the printed page number in the cited PDF.
- `source` is the exact PDF URL that was downloaded and read, not a product landing page.

## How the numbers were read

1. TI `ti.com/lit/ds/symlink/*.pdf` copies for 21 parts; Fairchild DM74LS161A (eater.net
   mirror), ON Semiconductor SN74LS195A and Signetics 54/74LS257 (mirrors) for the rest.
   All PDFs are kept in `ds/`, `cand/` and `x_74LS257.pdf`.
2. Most TI scans have no usable text layer, so pages were located with RapidOCR and every
   switching table was then **read from the rendered page image** (300 dpi crops in `crops/`).
   Text-layer extraction was used only where the PDF is text-native (74LS00, 74LS04,
   Fairchild, ON, Signetics) and was cross-checked against a second manufacturer where
   available (74LS74: TI and ON agree at 13/25 and 25/40).
3. `/ai_hw_engineer/work/timing/build_json.py` regenerates the JSON and asserts the value types.

## Known gaps

- **74LS161** (Fairchild DS006397): table has no TYP column; only MAX at CL = 15 pF.
- **74LS257** (Signetics 257): Min/Max only, no TYP; TI's SN74LS257B datasheet specifies
  CL = 45 pF, so it was not used.
- **74LS166**: the TI scan carries no SDLS document number; cited by URL and page.
- Three parts (74LS151, 74LS251, 74LS257) are specified at RL = 400 Ω / 2 kΩ / not stated
  respectively rather than the 2 kΩ used for the rest; see `notes`.
