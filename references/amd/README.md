# AMD source cache

Original manufacturer documents are used as the specification oracle; the
cache PDFs are ignored by Git. Project documentation links to their public
locations so the source remains reproducible without committing large books.

| File | Source | SHA-256 |
|---|---|---|
| `1974_AMD_Data_Book.pdf` | [Bitsavers mirror](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf) | `9d1f5140c9c206b57145e22743c689610b25cd145a07e93a54a205e5f71efefc` |

The 1974 book has 765 PDF pages. Am9300 occupies printed pages 2-33 through
2-38 (one-based PDF pages 54-59). In particular the serial-input truth table
is on printed page 2-37 / PDF page 58: K is an active-low input. The scanned
symbol must be consulted alongside OCR because complement bars are lost in
text extraction. Am2505 begins on printed page 2-9 / PDF page 30.
Am2501 shares the Am9306 datasheet on printed pages 2-55 through 2-60
(PDF pages 76-81); the two parts' state diagrams must not be confused.
