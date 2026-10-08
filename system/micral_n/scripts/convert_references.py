#!/usr/bin/env python3
"""Convert the archived R2E OCR and searchable Intel scan to Markdown."""
from pathlib import Path
import re
from pypdf import PdfReader

repo = Path(__file__).resolve().parents[3]
intel = repo / "design/intel_8008/references"
refs = repo / "references"
micral = repo / "system/micral_n/spec/reference"

pdf = PdfReader(refs / "intel_mcs8_users_manual_nov1973.pdf")
chunks = [
    "# Intel MCS-8 8008 User Manual (November 1973)\n",
    "Source: https://deramp.com/downloads/mfe_archive/050-Component%20Specifications/Intel/Microprocessors%20and%20Support/8008%20Family/i8008UM%20Nov%2073.pdf\n",
    "This searchable transcription was extracted from the archived Intel scan. Diagrams, tables, and OCR may require checking against the PDF.\n",
]
for number, page in enumerate(pdf.pages, 1):
    value = page.extract_text() or ""
    value = value.replace("\u00ad", "")
    value = re.sub(r"\n{3,}", "\n\n", value).strip()
    chunks.append(f"\n## Scan page {number}\n\n{value}\n")
(intel / "intel_mcs8_users_manual_nov1973.md").write_text("\n".join(chunks), encoding="utf-8")

raw = (micral / "MICRAL_N_Users_Manual_Jan74_ocr.txt").read_text(encoding="utf-8", errors="replace")
raw = raw.replace("\r\n", "\n").replace("\u00ad", "")
raw = re.sub(r"[ \t]+\n", "\n", raw)
raw = re.sub(r"\n{3,}", "\n\n", raw).strip()
header = """# R2E Micral N User Manual (January 1974)

Original R2E manual: https://www.mirrorservice.org/sites/www.bitsavers.org/pdf/r2e/MICRAL_N_Users_Manual_Jan74.pdf

OCR source: https://archive.org/download/bitsavers_r2eMICRALN_19057147/MICRAL_N_Users_Manual_Jan74_djvu.txt

This Markdown transcription preserves the archived OCR text. It is searchable, but drawings, circuit diagrams, tables, and uncertain OCR characters must be checked against the PDF. The page numbers embedded in the OCR are the printed manual's page numbers.

## Transcription

"""
(micral / "MICRAL_N_Users_Manual_Jan74.md").write_text(header + raw + "\n", encoding="utf-8")
print(f"Intel: {len(pdf.pages)} scanned pages; R2E: {len(raw)} OCR characters")
