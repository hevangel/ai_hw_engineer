# AMD source cache

Original manufacturer documents are used as the specification oracle; the
cache PDFs are ignored by Git. Project documentation links to their public
locations so the source remains reproducible without committing large books.

| File | Source | SHA-256 |
|---|---|---|
| `1974_AMD_Data_Book.pdf` | [Bitsavers mirror](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf) | `9d1f5140c9c206b57145e22743c689610b25cd145a07e93a54a205e5f71efefc` |
| `1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf` | [AMD handbook scan](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf) | `6bea9955f5784c009574cd7d18a83c790dc6f72f4e3de1c02bc69cdd2213ac74` |
| `1978_The_Am2900_Family_Data_Book.pdf` | [AMD family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf) | `823513eaf25d19e6ae992809afcd3116bf8cb27b4b0657256842d61c6a56c8fa` |

The 1974 book has 765 PDF pages. Am9300 occupies printed pages 2-33 through
2-38 (one-based PDF pages 54-59). In particular the serial-input truth table
is on printed page 2-37 / PDF page 58: K is an active-low input. The scanned
symbol must be consulted alongside OCR because complement bars are lost in
text extraction. Am2505 begins on printed page 2-9 / PDF page 30.
Am2501 shares the Am9306 datasheet on printed pages 2-55 through 2-60
(PDF pages 76-81); the two parts' state diagrams must not be confused.
The multiplier application note is printed pages 8-84 to 8-107 (PDF
pages 719-742); its circuit and pin discussion explicitly applies to
Am2505 as well as Am25L05 and Am25S05. The book's prefatory letter on
PDF page 4, signed by Jerry Sanders on June 3, 1974, dates the original
18-device product-line introduction to April 1970.

The original Am3101 occupies printed pages 6-11 to 6-16 (PDF pages 516-521);
its output truth table and unspecified deselected-write note are on PDF 520.
Do not substitute the separate Am3101A sheet starting on PDF 522.
Am9102/Am9102A/Am9102B occupies printed pages 5-61 to 5-66 (PDF 498-503).
PDF 501 specifies that output follows data during selected writes; PDF 502
defines retained-data standby and its required deselection/recovery timing.

The 319-page 1977 8080A/9080A handbook has functional description on PDF
6-21, instruction semantics on PDF 22-83 and appendix summaries on PDF
314-317. ANA/ANI on PDF 31-32 explicitly clears AC, unlike Intel 8080
silicon. Detailed PUSH on PDF 63 decrements SP, correcting the reversed
general prose on PDF 7. The actual ISR save/restore/EI/RET skeleton is
on PDF 301 (printed 15-2), including Figure 15-3.

The 402-page 1978 family book defines Am2901A on PDF 11–29, including native
CP phases on PDF 12; source/function/destination on PDF 14; status Figure 8
on PDF 16 (overbars must be visually inspected); and actual signed-multiply
microcode dated August 5, 1975 / J.S. in Figure 21 on PDF 29. Its companion
Figure 20 supplies cascade shift wiring and sign/overflow correction.
Am2902A follows on PDF 34/35 (printed 2-26/2-27); physical P/G pins are
active low, carry pins match active-high Am2901 carries, and only three
individual carry outputs exist. The original logic diagram, not unbarred
OCR alone, pins the digital equations.
Am2909/Am2911 occupy PDF 82–95 (printed 2-74–2-87): Figure 2 / PDF 84
shows separate register/direct inputs and Am2911's shared-data/no-OR variant;
Figures 5/6 / PDF 86 specify selection and exact pre-edge-PC push; Figures
7/8 / PDF 87 provide original pipelined and one-word nested subroutine traces.

Am2910 occupies PDF96–108 (printed2-88–2-100). Table I/II PDF99 must be
visually checked for active-low signals; Figure4 PDF103 and explanations
PDF104–106 provide original microprogram examples. Unlike Am2909, Am2910
stack depth saturates at zero/five and overflow replaces the full top word.
