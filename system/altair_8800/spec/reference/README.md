# Reference provenance

Sources for the Altair 8800 virtual platform. Originals are cited by URL;
committed copies live in this folder. The copyrighted 4K BASIC 3.2 tape is
**not** committed: `scripts/fetch_firmware.py` downloads it into the ignored
`work/` folder and verifies SHA-256
`fd01fd8b5c3dfbf67709809a1da6409ff1e0cb9c108fbe6a5129f8ad8e68d90f`.

| File | What it is | Origin |
|---|---|---|
| [88-SIO_Rev0_1.pdf](../../../../references/88-SIO_Rev0_1.pdf) | MITS 88-SIO Rev 0 & 1 serial interface manual (scanned, 58 pages, no text layer) | <https://deramp.com/downloads/altair/hardware/sio_serial_interface/88-SIO%20Rev%200%20%26%201.pdf> |
| [LDR4K32.ASM](LDR4K32.ASM) and [LDR4K32-octal.PRN](LDR4K32-octal.PRN) | Mike Douglas's reconstruction of the MITS front-panel bootstrap for 4K BASIC 3.2 through the 88-SIO, with octal toggle listing | <https://deramp.com/downloads/altair/software/papertape_cassette/SIO%20Loaders/> |
| [altair_basic_32_4k_disassembly.txt](altair_basic_32_4k_disassembly.txt) | Annotated disassembly of Altair BASIC 3.2 (4K). Copyright 1975 Bill Gates, Paul Allen, Monte Davidoff; disassembly by Reuben Harris (altairbasic.org), cleanup by Charles Mangin. Ground truth for the console I/O bit contract. | <https://github.com/option8/Altair-BASIC> |
| 4K BASIC Ver 3-2.tap | Original MITS tape image of Altair BASIC 3.2 (4K), fetched at build time into ignored `work/` | <https://deramp.com/downloads/altair/software/papertape_cassette/4K%20BASIC%20Ver%203-2.tap> |
| Altair 8800 Operator's Manual | Front-panel switch/LED behavior and the sample add program (not committed; cited from the CC BY-SA transcription) | <https://ubuntourist.codeberg.page/Altair-8800/part-3.html>, scan at <https://altairclone.com/downloads/manuals/Altair%208800%20Operator's%20Manual.pdf> |
