# Sources

All files in the ignored `work/am29xxx_refs/` directory of the task
worktree. SHA256 checksums recorded at download time.

| File | SHA256 (first 16 hex) | Role |
| --- | --- | --- |
| `1987_Am29332_Instruction_Manual.pdf` | `21585095fff6dc04` | Primary contract: AMD Am29332 Instruction Manual (1987, doc 07995A), 190 pages. Chapter 1 summary tables 1-16 and Figure 3 status map; Chapter 2 detailed descriptions of the 124 defined opcodes; Appendix A BCD arithmetic rules with examples 1-13; Appendix B modified-Booth multiply and nonrestoring divide flow charts with the 65h×48h and 75h/02h traces. |
| `manual29332.txt` | (derived) | Extracted text of the manual; worked-example values transcribed from it (page images cross-checked where OCR is ambiguous). |
| `1988_Am29C300_29300_Data_Book.pdf` | `c125ee91e06dcd13` | Supplemental contract: the Am29332 datasheet (PDF 162-170) supplies the only signal-level PIN DESCRIPTION of BOROW, RS, HOLD, M/m, MCIN, MLINK, SLAVE, OE-Y and the parity pins. |
| `ds29332_pins.txt` | (derived) | Extracted PIN DESCRIPTION pages (data book 162-170). |
| `m32p178.png` … `m32p186.png` | (derived) | Rendered page images of the manual's Appendix B flow charts and traces (read directly where the OCR text is mangled). |
| `1985_AM29300_Family_Handbook.pdf` | `80be2980...` | Family context (Am29300 provenance, family README). |

Worked-example expected values used by `scripts/generate_oracle.py
--check-table` come from the manual's printed traces (Appendix B pages
8-1/8-2, Appendix A pages A-2..A-8, Chapter 2 field-op example boxes) and
were cross-checked against the rendered page images where the OCR text is
ambiguous. The divide-step semantics (S ← F[w-1], quotient bit ← ¬F[w],
REMCORR gated on Z⊕N⊕S) were validated by exhaustive rule sweeps against
true division at widths 8/16/32 in addition to the printed trace.
