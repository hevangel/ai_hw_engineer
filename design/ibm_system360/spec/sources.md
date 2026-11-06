# System/360 source and provenance ledger

Status: **started**. This ledger records every artifact this design relies on,
how to obtain it, what it supports, and what is still missing. It is deliberately
conservative: an entry is "located" only when a URL, a retrieval date and a
hash are recorded, and "read" only when the relevant pages were actually
inspected for the claim they support.

Owning issues: [ai_engineer#381](https://github.com/hevangel/ai_engineer/issues/381)
(sources and rights), [#382](https://github.com/hevangel/ai_engineer/issues/382)
(architecture and model options), [#383](https://github.com/hevangel/ai_engineer/issues/383)
(independent oracles).

## 1. Distribution policy

- **No IBM code, microcode, licensed program, OS distribution or media image is
  committed to this repository.** This includes OS/360, DOS/360, BOS/360,
  TOS/360, CP/67, TSS/360, compilers, and any diagnostic or test deck.
- Manuals are **cited, not redistributed**: this folder links to the archive
  copy and quotes page references. PDFs are downloaded to the ignored `work/`
  tree for reading and are not part of any commit.
- Files obtained for a test must live under an ignored `work/` directory with a
  provenance manifest (URL, retrieval date, hash, licence assessment) before
  any test may depend on them, following the system conventions in
  `system/TEMPLATE.md`.
- IBM's manuals from the 1960s are of uncertain copyright status in the
  jurisdictions this project operates in. They are used as *references*; no
  claim of permission to redistribute is made. Any future redistribution
  requires written permission or a clearly licensed copy, and is out of scope
  for the code in this folder.
- The testbench program in `tb/` is **written for this project**, not copied
  from IBM documentation or software.

## 2. Primary sources read for this milestone

### S-1 — IBM System/360 Principles of Operation

| Field | Value |
|---|---|
| Form | A22-6821-7, eighth edition, September 1968 (reprint of A22-6821-6 with Technical Newsletter changes) |
| Archive | bitsavers, `pdf/ibm/360/princOps/` |
| URL | https://bitsavers.org/pdf/ibm/360/princOps/A22-6821-7_360PrincOpsDec67.pdf |
| Retrieved | 2026-11-05 |
| Size / hash | 17,001,522 bytes, SHA-256 `13FD1487492B37C2D28C4DA859537E228C2B31354ED3A839FE769983FE5AF8AD` |
| Text layer | present; page text was extracted locally for searching, page numbers below are the printed manual pages |
| Supports | instruction formats and length recording (pp. 12-13); address generation and zero base/index fields (pp. 13-14); sequential execution (p. 14); PSW layout (p. 15, Figure 14); interruption classes and permanent storage assignments (pp. 15-17); fixed-point arithmetic and condition codes (pp. 26-32); logical operations and their condition codes (pp. 53-56); `LA` (p. 65); branching, `BC`/`BCR` mask ordering and `R2 = 0` (pp. 64, 73-74) |
| Rights | see §1; reference only |

Note on the edition: the eighth edition is a reprint of the December 1967
sixth edition plus Technical Newsletter changes. The PSW figure in this
printing names bit 12 "ASCII mode" and bits 0-7 as "channel 0-6 mask, external
mask"; older printings describe the same bit as "extended control". The
difference is a model-feature naming issue, not an encoding change, but any
model that does not offer ASCII mode must be checked against its own
Functional Characteristics manual before its PSW is declared exact.

### S-2 — System/360 Reference Data (green card)

| Field | Value |
|---|---|
| Form | GX20-1703-9 |
| Archive | bitsavers, `pdf/ibm/360/referenceCard/` |
| URL | https://bitsavers.org/pdf/ibm/360/referenceCard/GX20-1703-9_System360_Reference_Data.pdf |
| Retrieved | 2026-11-05 |
| Size / hash | 662,124 bytes, SHA-256 `4D5CC66A4F7D31CD77848C7A92EA4F68E2841B217F60C7721B95AF954A64AA71` |
| Supports | cross-check of the opcode map and instruction formats; not yet used for any claim in `spec.md` (the page images are small and were not transcribed; the Principles of Operation remained the authority) |
| Rights | see §1; reference only |

### S-3 — Secondary source for dates and model line-up

| Field | Value |
|---|---|
| Source | Wikipedia, "IBM System/360" |
| URL | https://en.wikipedia.org/wiki/IBM_System/360 |
| Retrieved | 2026-11-05 |
| Supports | announcement date (7 April 1964), shipment years (1965-1978), the initial announcement of Models 30/40/50/60/62/70, the replacement of 60/62/70 by 65/75, and the model list with announcement/ship dates; Model 20's eight 16-bit registers and reduced set; Model 44's removal of storage-to-storage instructions; Model 67's DAT |
| Status | **secondary** — every date and model deviation still needs its primary IBM announcement, Functional Characteristics manual or Systems Reference Library entry before the corresponding model issue is signed off |

## 3. Sources located but not yet read

These are needed by later issues and are recorded so that no one re-does the
search. None has been downloaded, hashed, or used for a claim yet.

| Source | Archive location | Needed by |
|---|---|---|
| Model Functional Characteristics manuals (20, 22, 25, 30, 40, 44, 50, 65, 67, 75, 85, 91, 95, 195) | `pdf/ibm/360/functional_characteristics/` | #381, #382, each model issue |
| System/360 System Summary (C28-6510) | `pdf/ibm/360/systemSummary/` | #381 |
| IBM 2030 Model 30 logic and microcode material | `pdf/ibm/360/model20/`, `fe/`, vendor archives | #388, #393 |
| Instruction timing (A22-6825) | `pdf/ibm/360/A22-6825-0_360_Instr_Timing.pdf` | #384, #389 |
| BOS/360, TOS/360, DOS/360, OS/360 distributions and IPL decks | `pdf/ibm/360/bos_bps/`, `dos/`, `os/` | #429-#434 |
| CP/67-CMS source listing (1969) | https://github.com/moshix/CP-67-CMS-Source | #435 |
| IBM 2030 VHDL | https://github.com/ibm2030/IBM2030 | #383, #393 |
| microsim360 microcode simulator | https://github.com/rcornwell/microsim360 | #383, #388 |
| SimH 360 control panel images and software | https://github.com/rsanchovilla/SimH_cPanel | #383 |

## 4. Gaps that block a compatibility claim

1. **No independent emulator oracle yet.** The M1 tests compare the RTL against
   hand-derived expectations from the manual and against a second reading of the
   same manual in the formal properties. That cannot catch a shared misreading.
   Issue #383 must provide an external oracle and a test corpus before any
   "S/360 compatible" claim.
2. **No IBM diagnostics or historical software.** The programs that would
   exercise overlaps, unusual addresses and exception paths (`#441`, `#443`)
   are not located or licensed for local use.
3. **No per-model Functional Characteristics.** The M1 core is the common
   subset; nothing here establishes what a Model 30 or Model 67 does
   differently.
4. **No microcode or logic documentation read.** The implementation is
   architectural, not a reconstruction of any specific machine's control store.
5. **No timing source read.** No cycle counts in this folder may be compared
   with historical performance figures.

## 5. Reproducing the source check

The manual is read from the network into the ignored `work/` tree; the hash in
§2 can be reproduced with:

```sh
curl -sSLA "Mozilla/5.0" -o work/s360/A22-6821-7.pdf \
  https://bitsavers.org/pdf/ibm/360/princOps/A22-6821-7_360PrincOpsDec67.pdf
sha256sum work/s360/A22-6821-7.pdf
```

The archive rejects requests without a user agent (`403 Forbidden`), which is
why the `-A` option is required. Page references in `spec.md` were checked
against the extracted text of that file; the extraction used the PDF text layer
with `pypdf`.
