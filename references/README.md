# Shared hardware references

This folder collects primary manufacturer documents and historical sources used
across the chip designs. Chip-specific notes and the way each source is applied
remain in the relevant `design/<chip>/references/` folders.
Original scans, PDFs, and raw OCR sources are centralized here; `design/` and
`system/` retain cleaned searchable extractions and source-grounded notes.

## AMD

The 1974 data book is copied to this folder for direct use. Other AMD scans remain
in the local `amd/` cache; those cached PDFs are ignored by Git, and design
records link to their public sources for reproducibility.

### Source documents

| Document | Local file | Source | SHA-256 |
| --- | --- | --- | --- |
| 1974 AMD Data Book | [1974_AMD_Data_Book.pdf](1974_AMD_Data_Book.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf) | `9d1f5140c9c206b57145e22743c689610b25cd145a07e93a54a205e5f71efefc` |
| 1977 8080A/9080A MOS Microprocessor Handbook | [amd/1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf](amd/1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1977_AMD_8080A_9080A_MOS_Microprocessor_Handbook.pdf) | `6bea9955f5784c009574cd7d18a83c790dc6f72f4e3de1c02bc69cdd2213ac74` |
| 1978 Am2900 Family Data Book | [amd/1978_The_Am2900_Family_Data_Book.pdf](amd/1978_The_Am2900_Family_Data_Book.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf) | `823513eaf25d19e6ae992809afcd3116bf8cb27b4b0657256842d61c6a56c8fa` |
| 1979 AMD Designer's Guide | [amd/1979_AMD_The_Designers_Guide.pdf](amd/1979_AMD_The_Designers_Guide.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1979_AMD_The_Designers_Guide.pdf) | `e4e3eacf2c555351bf4c81cfa1fc24f4be39b280deb7f21a08cfe9b8916a53e3` |
| 1979 Am2900 Family Data Book | [amd/1979_AMD_2900family.pdf](amd/1979_AMD_2900family.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf) | `bc506a9acb19e840351d74cec78c8b0bb46e079e75245dddeddee73ef7167604` |
| January 1987 Am2914 data sheet | [amd/1987_2914.pdf](amd/1987_2914.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/amd/bitslice/_dataSheets/1987_2914.pdf) | `2bd157401a740dab4505e8522b94dda0e8e3e890eabbd3f6466e6aa6cc1fb293` |
| *The Am9511 Arithmetic Processing Unit* (1978) | [amd/The_Am9511_Arithmetic_Processing_Unit.pdf](amd/The_Am9511_Arithmetic_Processing_Unit.pdf) | [Parker and Kroeger](https://github.com/barberd/coco9511pak/blob/0f272e44db724ed7f0e60730499457be230e4e4f/docs/The%20Am9511%20Arithmetic%20Processing%20Unit.pdf) | `80b2984668ad59773db7610b01d08075513d360b6fafbcbb913660aae5869263` |
| *Am9511A/Am9512 Floating Point Processor Manual* (May 1981) | [amd/Am9511A_9512_Processor_Manual.pdf](amd/Am9511A_9512_Processor_Manual.pdf) | [Cheng](https://github.com/barberd/coco9511pak/blob/0f272e44db724ed7f0e60730499457be230e4e4f/docs/Am9511A-9512FP_Processor_Manual.pdf) | `38c673ccd12186caa3b6089b9be4207a6d13ace629a140f4949a0e51d0da1dda` |
| *Electronics*, January 19, 1978 | [amd/Electronics_1978-01-19.pdf](amd/Electronics_1978-01-19.pdf) | [World Radio History](https://www.worldradiohistory.com/Archive-Electronics/70s/78/Electronics-1978-01-19.pdf) | `b90178cbf4884754e2a62493d622683b0a324aaaa7f00627d137dc98f2dbf245` |

### Design and verification notes

#### 1974 AMD Data Book

The book has 765 PDF pages. The Am9300 occupies printed pages 2-33 through
2-38 (PDF pages 54-59). Its serial-input truth table is on printed page 2-37 /
PDF page 58: K is active low. The scanned symbol must be checked alongside OCR
because OCR loses complement bars. Am2505 begins on printed page 2-9 (PDF page
30). Am2501 shares the Am9306 data sheet on printed pages 2-55 through 2-60
(PDF pages 76-81); keep the two parts' state diagrams distinct. The multiplier
application note spans printed pages 8-84 to 8-107 (PDF pages 719-742); its
circuit and pin discussion explicitly applies to Am2505 as well as Am25L05 and
Am25S05.

The prefatory letter on PDF page 4, signed by Jerry Sanders on June 3, 1974,
dates the original 18-device product-line introduction to April 1970. The
original Am3101 occupies printed pages 6-11 to 6-16 (PDF pages 516-521); its
output truth table and unspecified deselected-write note are on PDF page 520.
Do not substitute the separate Am3101A sheet that starts on PDF page 522.
Am9102/Am9102A/Am9102B occupies printed pages 5-61 to 5-66 (PDF pages
498-503). PDF page 501 specifies that output follows data during selected
writes; PDF page 502 defines retained-data standby and its required
deselection/recovery timing.

#### 1977 8080A/9080A Handbook

The 319-page handbook has functional description on PDF page 6-21, instruction
semantics on PDF pages 22-83, and appendix summaries on PDF pages 314-317.
ANA/ANI on PDF pages 31-32 explicitly clears AC, unlike Intel 8080 silicon.
The detailed PUSH description on PDF page 63 decrements SP, correcting the
reversed general prose on PDF page 7. The actual ISR save/restore/EI/RET
skeleton is on PDF page 301 (printed page 15-2), including Figure 15-3.

#### 1978 Am2900 Family Data Book

Am2901A is defined on PDF pages 11-29, including native CP phases on page 12,
source/function/destination on page 14, status Figure 8 on page 16, and the
signed-multiply microcode dated August 5, 1975 / J.S. in Figure 21 on page 29.
Overbars in Figure 8 must be visually inspected. Companion Figure 20 supplies
cascade shift wiring and sign/overflow correction.

Am2902A follows on PDF pages 34-35 (printed pages 2-26/2-27). Physical P/G
pins are active low, carry pins match active-high Am2901 carries, and there are
only three individual carry outputs. Use the original logic diagram to resolve
the digital equations rather than unbarred OCR alone.

Am2909/Am2911 occupy PDF pages 82-95 (printed pages 2-74-2-87). Figure 2 /
PDF page 84 shows separate register/direct inputs and the Am2911 shared-data /
no-OR variant. Figures 5/6 on PDF page 86 specify selection and exact pre-edge
PC push; Figures 7/8 on PDF page 87 provide original pipelined and one-word
nested subroutine traces.

Am2910 occupies PDF pages 96-108 (printed pages 2-88-2-100). Table I/II on
PDF page 99 must be visually checked for active-low signals. Figure 4 on PDF
page 103 and its explanations on pages 104-106 provide original microprogram
examples. Unlike Am2909, Am2910 stack depth saturates at zero/five and overflow
replaces the full top word.

#### 1979 guides and family book

In the 1979 Designer's Guide, Am2903 Table 5 on PDF page 69 / printed page 2-7
corrects the original 1978 special-E Gi cell at Z=LOW to R AND S; the earlier
PDF page 43 print complemented R there. Original multiply firmware is in 1978
Figures 17/19 on PDF pages 53-54, with actual Am2910 LDCT/RPCT counts and
serial/carry/Z wiring in Figures 15/18.

In the 1979 Am2900 Family Data Book, Am2904 occupies PDF pages 92-106 (printed
pages 2-84-2-98). Tables 1-7 on PDF pages 94-98 define status operations,
conditional-test overbars, carry selection, and all 32 shift linkages. Table 7
notes 2/3 explicitly override CEM/EC holds when a shift loads machine carry.
The original two-load interrupt restoration and register-swap applications are
on PDF page 99. The 1978 PDF pages 60-63 entry is advance information, not
proof of an exact commercial shipment date.

Am2913 occupies 1979 PDF pages 161-165 (printed pages 2-153-2-157). Its
positive-polarity encoder and five independent output gates are defined by the
two truth tables on PDF page 164. EI HIGH inhibits encoding but does not
release the output; EO remains independent of all output gates. PDF page 165
shows the original eight-Am2914/one-Am2913 64-level interrupt application.
The earlier 1978 book already includes the Am2913 data sheet on PDF pages
109-113, supplying the historical bound.

Am2914 occupies 1979 PDF pages 166-173, original applications pages 174-184,
and detailed logic pages 185-190. The original Figure 4 interrupt procedure is
on PDF page 177; Figures 6/9/10 on pages 178/181/182 define the original
64-level ripple cascade, vector, and status buses. Its first complete data
sheet already appears in the 1978 book on PDF pages 114-121. The January 1987
manufacturer data sheet (16 pages) explicitly defines native edge sampling
and sticky status overflow until master clear/status reload.

Am2918 is defined in 1979 PDF pages 209-212 (printed pages 2-201-2-204); PDF
page 211 contains its complete positive-edge/non-inverted truth table. PDF page
212, MPR-188 and MPR-189, gives the original two-chip bidirectional interface
and serial converter. The bidirectional schematic crosses each register's Y
to the opposite bus; the adjacent prose repeats A for the left output. Native
tests follow the unambiguous pin connections. The earlier 1978 book already
contains the complete data sheet on PDF pages 162-165.

#### Am9511, Am9512, and Am9517

Am9511 is defined by the 1979 Designer's Guide on PDF pages 235-244 (printed
pages 4-33-4-42) and its algorithm chapter on pages 275-296 (printed pages
5-1-5-22); detailed commands are on pages 284-296. The independent command
CSV cross-checks bit diagrams against the data sheet; the summary on PDF page
279 contains OCR code errors.

The Am9511A/Am9512 manual dates Am9511 to 1977 and Am9512 to 1979 on PDF page
26 (printed page 23); no exact month is established. Original 8080 DEMAND/POLL
software is on PDF pages 36-39 (printed pages 33-36). Its object bytes,
including the first POLL-loop target 003e, are retained in the Am9511 design
with provenance and integrity hash. This later manual supplies history and
host software; original command semantics continue to use the 1979 source
rather than importing A-revision electrical changes.

Am9517 occupies the 1979 Designer's Guide on PDF pages 245-260 (printed pages
4-43-4-58), with the original application brief on pages 297-316 (printed
pages 5-23-5-42). The original register map explicitly marks E write illegal;
HACK-time arbitration and programming during HREQ/HACK wait are explicit.
Figure 15 on PDF page 307 has source-hold labels that disagree with adjacent
prose and data sheet PDF page 250; the latter agree that bit 1 = 1 enables
hold. Original STUP/SDMA objects are on PDF pages 311-314; STUP's literal
object command 62/count 07 disagree with printed operands 60/7F.

The January 19, 1978 *Electronics* issue has its cover date on PDF page 1 and
AMD's Am9517 advertisement on PDF pages 77-78. It supports a public announcement
by 1978, not an exact first-shipment date.

## Texas Instruments

### Source documents

| Document | Local file | Source | Details |
| --- | --- | --- | --- |
| SN74LS181 data sheet (SDLS136; December 1972, revised March 1988) | [SN74LS181_datasheet.pdf](SN74LS181_datasheet.pdf) | Texas Instruments | 695,806 bytes; SHA-256 `94e617d454b8da64ace69a37b9e4873e81b41ea78f88f7026caeb0ee616b8363` |
| TTL Data Book for Design Engineers, 2nd edition (1976) | [1976_TI_The_TTL_Data_Book_2ed.pdf](1976_TI_The_TTL_Data_Book_2ed.pdf) | [Bitsavers directory](https://bitsavers.trailing-edge.com/components/ti/_dataBooks/1976_TI_The_TTL_Data_Book_2ed/) | 832-page combined scan; 33,267,308 bytes; bookmarks mark source-part boundaries |

### TTL Data Book for Design Engineers, 2nd edition (1976)

The 832-page combined scan is [1976_TI_The_TTL_Data_Book_2ed.pdf](1976_TI_The_TTL_Data_Book_2ed.pdf).
It contains the 74-series TTL logic family catalog used by the Apple II chip
references. The combined file is 33,267,308 bytes and has bookmarks for the
source-part boundaries.

The original Bitsavers scan is split into 11 numbered parts under
[`ti_74_series_ttl_data_book_1976_2ed/`](ti_74_series_ttl_data_book_1976_2ed/).
Open them in numeric order (`00.pdf` through `10.pdf`). Their combined size is
33,261,964 bytes. Source: [Bitsavers directory](https://bitsavers.trailing-edge.com/components/ti/_dataBooks/1976_TI_The_TTL_Data_Book_2ed/).

| Part | Bytes | SHA-256 |
| --- | ---: | --- |
| [00.pdf](ti_74_series_ttl_data_book_1976_2ed/00.pdf) | 137,882 | `623f6fa321671b6d9b4a294944b8c7c862496fe31304141a1063b30fe08125b2` |
| [01.pdf](ti_74_series_ttl_data_book_1976_2ed/01.pdf) | 1,276,104 | `5174beace065ea0fd41f36233ff8b3d08e89814830075580fc474a09a102ddcc` |
| [02.pdf](ti_74_series_ttl_data_book_1976_2ed/02.pdf) | 608,077 | `1c5616c6023179b27b069cac405a960dce6c52dcede9cf54033cfeb8dd34694e` |
| [03.pdf](ti_74_series_ttl_data_book_1976_2ed/03.pdf) | 343,808 | `56df363c54f873123330dec38257283d3308cc18f1aa65a5b2344c4275510053` |
| [04.pdf](ti_74_series_ttl_data_book_1976_2ed/04.pdf) | 342,289 | `3e26083d6a93e19d7d14d2b7cd88d4c800f9394fb92a4729a82893e12b74786e` |
| [05.pdf](ti_74_series_ttl_data_book_1976_2ed/05.pdf) | 2,430,672 | `b274a482827037aac0b2962288bd93da20aac601208c145b209c4a864c0df212` |
| [06.pdf](ti_74_series_ttl_data_book_1976_2ed/06.pdf) | 4,411,241 | `99dba623b44071cee3e7839a48559ddf3d08ee9a2a515ab9033286b3ab5b0aa9` |
| [07.pdf](ti_74_series_ttl_data_book_1976_2ed/07.pdf) | 22,109,989 | `a17ac6255168b1fe99760837abda4e7c3151de59470210f12aceb0575922571d` |
| [08.pdf](ti_74_series_ttl_data_book_1976_2ed/08.pdf) | 333,270 | `d1e285555fb26d0aef42ba9e7de4081c227e84c45bff82e98b10725474069e79` |
| [09.pdf](ti_74_series_ttl_data_book_1976_2ed/09.pdf) | 985,842 | `9bf96bc6326451b4176eb3e0d9eb0494cf1d0742aaaeddd51dbf51e46563f385` |
| [10.pdf](ti_74_series_ttl_data_book_1976_2ed/10.pdf) | 282,790 | `e6c09ce3245d10e1a037f825e35ace026394a1167d8dd8d9ad17136098bbe46e` |

## Intel

| Document | Local file(s) | Source | Details |
| --- | --- | --- | --- |
| MCS-4 data sheet (November 1971) | [MCS4_Data_Sheet_Nov71.pdf](MCS4_Data_Sheet_Nov71.pdf) | [DeRamp's Intel archive](https://deramp.com/downloads/mfe_archive/011-Other%20Computers%20and%20Boards/Intel/MCS-4/MCS4_Data_Sheet_Nov71.pdf) | 11,184,923 bytes; SHA-256 `4672da4d81b75c98ef7c8892c9f33d522aa55922d48d6cd4952ecffe9a739622` |
| MCS-8 Users Manual (8008), November 1973 | Scan: [intel_mcs8_users_manual_nov1973.pdf](intel_mcs8_users_manual_nov1973.pdf)<br>Searchable transcription: [8008UM_text.pdf](8008UM_text.pdf), also kept with the Intel 8008 design references | [DeRamp's Intel archive](https://deramp.com/downloads/mfe_archive/050-Component%20Specifications/Intel/Microprocessors%20and%20Support/8008%20Family/i8008UM%20Nov%2073.pdf) | 4,061,851 bytes; SHA-256 `e2b576af238be02755adf046af5443a47b168b385a87bae606149ce217860f84` |
| 8080 Microcomputer Systems User's Manual (September 1975), Intel publication 98-153B | [intel_8080_microcomputer_systems_users_manual_1975.pdf](intel_8080_microcomputer_systems_users_manual_1975.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/intel/MCS80/98-153B_Intel_8080_Microcomputer_Systems_Users_Manual_197509.pdf) | 43,049,640 bytes; SHA-256 `d5982f96536b1dbecbeff409d2370970638716296dce7b318624d86221597a9e` |
| 8086 Family User's Manual (October 1979), Intel publication 9800722-03 | [intel_8086_family_users_manual_1979.pdf](intel_8086_family_users_manual_1979.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/intel/8086/9800722-03_The_8086_Family_Users_Manual_Oct79.pdf) | 62,967,963 bytes; SHA-256 `717194ec03520d6499a40523abdfd4ed15a2b8ccc45a21c653e2b443c248664c` |
| 8086 Family User's Manual, Numerics Supplement (July 1980), order 121586-001 | Scan: [intel8087.pdf](intel8087.pdf)<br>Clean searchable extraction: [manual.txt](../design/intel_8087/references/manual.txt) | [Mark Ogden](https://mark-ogden.uk/files/intel/publications/121586-001%20The%208086%20Family%20Users%20Manual%20Numerics%20Supplement-Jul80.pdf) | 93,425,392 bytes; SHA-256 `d2d8557a8e9c24cdc4613ea5d51cd3cf745fbd586c6eaab1a1af1ccfc977aa04` |
| Peripheral Design Handbook (1981) | [1981_Intel_Peripheral_Design_Handbook.pdf](1981_Intel_Peripheral_Design_Handbook.pdf) | [Bitsavers](https://bitsavers.trailing-edge.com/components/intel/_dataBooks/1981_Intel_Peripheral_Design_Handbook.pdf) | 908 pages; 65,164,894 bytes; original manufacturer material and notices retained; SHA-256 `90b0d961f0e324944d07b3cedef31b8133ef9f49cf8b3d60d4469ddc533becec` |
| 3205/3404 combined data sheet | [intel_3205_3404_datasheet.pdf](intel_3205_3404_datasheet.pdf) | [Trinity College Dublin SCSS hardware archive](https://treasures.scss.tcd.ie/hardware/TCD-SCSS-T.20250922.001/Intel-C3000-datasheets/Intel-3205-3404-datasheet.pdf) | Primary functional contract for intel_3205 and intel_3404: catalog pages 2-35 to 2-38 cover the 3205 1-of-8 decoder and 3404 6-bit latch. No print date is given. 140,267 bytes; SHA-256 `4dc74bd9c5909ae6e3b15d094a7e0700a87e97fd195c1a5f59fe7f315cc0cdae` |
| 8272A preliminary datasheet (AFN-01259C, ©1982) | [intel_8272a.pdf](intel_8272a.pdf) | [Threedee archive](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf) | 19-page scan; 3,083,346 bytes; SHA-256 `c03a1fabe42fe43bb47fbd84042840f7b78b1ddd03e8a117fc7059c3453cc398` |
| 8273 datasheet (order 210479-004, October 1992) | [intel_8273.pdf](intel_8273.pdf) | [Octopart](https://datasheet.octopart.com/P8273-Intel-datasheet-38976656.pdf) | 33 technical pages plus Rochester cover; 6,251,363 bytes; SHA-256 `04fa19a153fa7dd9c4327f8b3043bc6a83b1dfd5e0be7f16afcef4bb7b4461f8` |
| 8275 datasheet (AFN-00224B) | [intel_8275.pdf](intel_8275.pdf) | [CPU Galaxy](https://www.cpu-galaxy.at/CPU/Ram%20Rom%20Eprom/Other_Intel_chips/other_intel-Dateien/8275_Datasheet.pdf) | Catalog pages 8-223–8-246; 24 scanned pages; 774,137 bytes; SHA-256 `aec733a972739cd70361560ba26249ec139f919f71f50167cdfde30a72826736` |
| 8237A datasheet (order 231466-005, September 1993) | [INTEL_8237A_DMA.pdf](INTEL_8237A_DMA.pdf) | [PCjs](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf) | 249,347 bytes; SHA-256 `2a1ac5bbf5b4be75ba9272647effb389bcc5e76cbfe293d5c56e75217e2bc8a8` |

## Commodore Semiconductor Group

| Document | Local file(s) | Source | Details |
| --- | --- | --- | --- |
| 6500 Microprocessors family data sheet | [mos_csg_6500_microprocessors_datasheet.pdf](mos_csg_6500_microprocessors_datasheet.pdf) | [ChipDB mirror](https://datasheets.chipdb.org/Commodore/csg6500.pdf) | Covers the 6502 family. The copied scan does not establish a publication date. 1,077,248 bytes; SHA-256 `32ef34a7c1d35dfa9e0f1be3cb085da293121f1af2e5463d2e937e13bd251012` |

## Fairchild Semiconductor

| Document | Local file | Source | Details |
| --- | --- | --- | --- |
| 74F181PC datasheet | [74F181_Fairchild_datasheet.pdf](74F181_Fairchild_datasheet.pdf) | Fairchild Semiconductor | 96,691 bytes; SHA-256 `82aabdfbe127ba8efb77af53791bb6019446965b071e64353b720e2b720f6497` |

## Systems Reference Manuals

| Manual | Clean extracted version in design/system | Source PDF in references | Source and details |
| --- | --- | --- | --- |
| Apple IIe Technical Reference Manual, 2nd edition (first printing July 1985) | No local text extraction | [Apple_IIe_TRM_1985.pdf](Apple_IIe_TRM_1985.pdf) | [Internet Archive item `a2etrm`](https://archive.org/details/a2etrm); 454 pages; 29,404,158 bytes; SHA-256 `f92a117a04c61f41f428a1be726f75ad61084b3339011013dba902fe6367677f`. The former `Apple_IIe_TRM_1982_text.txt` identified the edition and first printing. |
| Apple IIe Technical Reference Manual (1987 edition) | No local text extraction | [Apple_IIe_TRM_1987.pdf](Apple_IIe_TRM_1987.pdf) | [Internet Archive item](https://archive.org/details/apple-iie-technical-reference-manual-1987-edition); 416 pages; first printing January 1987; copyright © Apple 1986; 139,493,799 bytes; SHA-256 `61520d35a23418e5a3fb40219a4f032ed223cc8fe36a34a0ad8325b0430c5ba7`. |
| IBM Personal System/2 Model 30 Technical Reference (January 1987) | [Clean text extraction](../system/ibm_ps2_model30/spec/reference/model30tr.txt) | [model30tr.pdf](model30tr.pdf) | [IBM archive](https://www.ibmfiles.com/ibmfiles/ps2/25/model30tr.pdf); first edition, 348 pages; 8,867,734 bytes; SHA-256 `f563acc62997f91ec79754e7c397474d136e7bd9a1893349b8b25fd6ce47b20f`. |
| IBM Personal System/2 Model 30 maintenance schematics (1991) | No text extraction; see the [system fixed-disk specification](../system/ibm_ps2_model30/spec/hard_disk.md) | [m30_sch.pdf](m30_sch.pdf) | [Ardent Tool](https://www.ardent-tool.com/docs/pdf/schematics/m30_sch.pdf); sheet 6 cross-checks the fixed-disk connector signals; 21,830,468 bytes; SHA-256 `68c79ecefab2e686a8ce5986b70e33a1d2c8bbcd6840ee5045b607dc148d5558`. |
| R2E Micral N User Manual (January 1974) | [Searchable Markdown](../system/micral_n/spec/reference/MICRAL_N_Users_Manual_Jan74.md) | [MICRAL_N_Users_Manual_Jan74.pdf](MICRAL_N_Users_Manual_Jan74.pdf); [source OCR text](MICRAL_N_Users_Manual_Jan74_ocr.txt) | [Bitsavers mirror](https://www.mirrorservice.org/sites/www.bitsavers.org/pdf/r2e/MICRAL_N_Users_Manual_Jan74.pdf); 19,057,147 bytes; SHA-256 `710fd094bc6626d8ec761a21c58c2cecdea613bceac34595672e7f1633064d11`. The Markdown retains the searchable archive transcription; diagrams and uncertain OCR should be checked against the scan. |
| Unicom 141 Series Calculator Operating Instructions | [Readable Markdown](../system/busicom_141pf/spec/reference/Unicom_141P_manual.md); [raw OCR Markdown](Unicom_141P_manual_ocr.md) | [Unicom_141P_manual_text.pdf](Unicom_141P_manual_text.pdf) | [Internet Archive item](https://archive.org/details/Unicom141PManual); 35 pages; 806,475 bytes; SHA-256 `05d8d3dcccf3efe4e0c8ab4d81678909a8d082af4a6b6cd8a093345284751640`. Operation tables in the readable Markdown were visually checked against the scan. |
| MITS 88-SIO Rev 0 & 1 serial interface manual | No text layer or clean local extraction; use the scan pages directly | [88-SIO_Rev0_1.pdf](88-SIO_Rev0_1.pdf) | [DeRamp archive](https://deramp.com/downloads/altair/hardware/sio_serial_interface/88-SIO%20Rev%200%20%26%201.pdf); 58-page scan with no text layer; 1,543,781 bytes; SHA-256 `f699066b59eb71b83293c5ecb195812b95fd9595eb65756b7442bf83c6ca7715`. |
