# AMD primary-source cache

Local cache of AMD manufacturer documents used by the `design/amd_am*`
reconstructions. Manufacturer scans are copyright AMD; they are cached here
for verification provenance only. The `/references/amd/*.pdf` gitignore
entry documents that PDFs are cache artifacts; tracked entries were added
deliberately as verification evidence for the designs that cite them.

| File | Used by | SHA-256 (first 16) | Provenance |
|------|---------|--------------------|------------|
| Am9518_AmZ8068_Data_Ciphering_Processor_00618B.pdf | [design/amd_am9518](../../design/amd_am9518/) | `28706ab64d688c30` | AMD Am9518/AmZ8068 Data Ciphering Processor datasheet, doc 00618B (printed pages 2-461…2-478), distributor scan (semikey.com CDN cache); page images verified against the AMD 1985 Peripheral Processor Interface Guide's command/status tables and interface-test program. |
| Am9511A_9512_Processor_Manual.pdf | [design/amd_am9511](../../design/amd_am9511/) | — | AMD Am9511A/Am9512 Floating Point Processor manual (also mirrored in the coco9511pak repository, see that design's README). |
| 1979_AMD_The_Designers_Guide.pdf | [design/amd_am9511](../../design/amd_am9511/) | — | AMD 1979 Designer's Guide; Am9511 chapter at PDF pages 235–244 and 275–296. |

Verification rule for this design (`design/amd_am9518`): any quoted
datasheet fact is checked against the cached scan's page images; where the
scan text is ambiguous the 1985 Peripheral Processor Interface Guide
(bitsavers, linked in the design README) is the cross-reference, and AMD's
published interface-test vector provides the behavioral anchor.
