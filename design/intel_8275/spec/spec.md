# Intel 8275 functional specification

## Sources and scope

The primary source is Intel's **8275**, AFN-00224B, catalog pages 8-223–8-246, preserved in [the local scan](../references/intel_8275.pdf) from [CPU Galaxy](https://www.cpu-galaxy.at/CPU/Ram%20Rom%20Eprom/Other_Intel_chips/other_intel-Dateien/8275_Datasheet.pdf). Page numbers below are PDF pages. This is an 8275 functional recreation, not the 8276 or a claim of electrical timing equivalence. [MAME's independent implementation](https://github.com/mamedev/mame/blob/master/src/devices/video/i8275.cpp) corroborates attribute tables, FIFO handling and status encodings; it does not support spaced rows and differs from Intel's stated character blink divisor. Intel takes precedence.

Use a synchronous `clk`, active-low synchronous `rst_n`, and `cclk_en` for each character-clock advance. CPU and DMA strobes are sampled on their falling edges in this clock domain. Hold data and address stable through the sampled edge. Separate `db_in`, `db_out`, `db_oe` replace the electrical bidirectional bus. `cs_n`, `rd_n`, `wr_n`, `a0`, `dack_n`, `lpen` have the manufacturer's polarity. Outputs are `cc[6:0]`, `lc[3:0]`, `la[1:0]`, `hrtc`, `vrtc`, `vsp`, `lten`, `rvv`, `hlgt`, `gpa[1:0]`, `drq`, `irq`. A character generator and dot serializer remain external.

## Programming model (pages 16–19)

A0=1: write command/read status. A0=0: write/read parameters. Status bits 6:0 are IE, IR, LP, IC, VE, DU, FO; bit 7 is zero. Reading status clears IR/LP/IC/DU/FO, retaining IE and VE. IRQ follows IR; disabling interrupts prevents new requests but does not acknowledge an existing request.

| Command bits 7:5 | Action | Parameters |
|---|---|---|
| 000 | Reset: stop DMA, clear IE/IR/VE, blank video; timing continues | Four screen bytes, write |
| 001 | Start display: set IE/VE; bits 4:2 space, bits 1:0 burst | None |
| 010 | Stop display: clear VE; timing and IE continue | None |
| 011 | Read light pen | Column then row, read |
| 100 | Load cursor | Column then row, write |
| 101 | Enable interrupt | None |
| 110 | Disable interrupt | None |
| 111 | Preset counters | None |

Screen bytes: S/HHHHHHH (alternate-row blanking, columns minus one, legal 1–80); VV/RRRRRR (vertical retrace rows minus one, displayed raster rows minus one); UUUU/LLLL (zero-based underline, lines minus one); M/F/CC/ZZZZ (offset line-counter mode, visible field mode, cursor format, half horizontal retrace length minus one). Horizontal retrace is 2–32 CCLKs; vertical retrace is 1–4 row periods. Normal line counter is zero based; offset mode emits the last line on the first scanline, then zero, one, etc. LC advances during horizontal retrace. Underline compares the physical line, independently of M. U bit 3 blanks first/last scanlines. Spaced rows blank odd raster rows and do not request their data; total programmed frame rows are unchanged (page 8).

Too few parameters before a new command, extra parameters, wrong read/write direction, or columns exceeding buffer capacity set IC. Undefined width programming is deterministically clamped to the instantiated capacity. `MAX_COLS` defaults to 80; smaller capacities permit inexpensive formal verification.

## Raster and attributes (pages 8–15)

Two independent row buffers and two 16×7 FIFOs alternate. Display repeats a row's codes for all scanlines. Field state carries to the following display row, restarts from that row's base on each scanline, and resets at vertical retrace. Codes 00–7F output the character. Field codes 80–BF encode U/R/GPA1/GPA0/B/H. Visible mode emits a blank cell; new attributes apply starting with the following cell. Invisible mode stores the next DMA byte, stripped to seven bits, in the FIFO and displays it at the attribute cell with the new field. A 17th replacement overwrites FIFO entry zero and sets FO. FIFO replacement data is always ordinary text, even if its original MSB was one.

Character attributes C0–EB implement the eleven graphics in Intel Table 2; EC–EF emit the table's all-zero combination. Graphics inherit RVV and GPA from the field, but use their own blink/highlight and line/underline controls. F0 ends a row, F1 ends a row and stops its DMA, F2 ends the screen, F3 ends the screen and stops frame DMA. EOS remains recognizable after EOR. F4–FF are undefined and deterministically blank.

Character blink is refresh/32 (16 frames on/off), cursor blink refresh/16 (8 on/off), per pages 14 and 16. Cursor CC=00/01/10/11 selects blinking block/underline/steady block/underline. Block XORs RVV; underline ORs LTEN on the programmed line. Retrace, disabled display, spaced rows, underrun, and screen termination override video with VSP and suppress LTEN.

## DMA and events (pages 11, 14, 19)

The first row is prefetched starting one row period before the end of vertical retrace. Each subsequent display row is fetched during the preceding raster row. Burst lengths are 1/2/4/8 bytes; request spacing is 0/7/15/23/31/39/47/55 CCLKs. Spacing is measured from the preceding request, not its acknowledgement. DRQ drops on each accepted DACK and returns for remaining burst bytes; first request may be delayed by the programmed spacing. A full row terminates a burst. A final invisible attribute still requires its FIFO replacement byte.

Stop-DMA codes at burst/row end stop immediately. Otherwise exactly one trailing dummy byte is accepted before stopping, as Intel's page 14 note specifies. EOR-stop marks the row complete; EOS-stop suppresses further DMA until vertical retrace. A final byte accepted on the display boundary completes that row without DU. If a row is not complete at its display boundary, set DU, stop DMA and blank until vertical retrace; status acknowledgement alone does not resume video. IRQ latches at the start of the last raster display row if IE is set, including when VE is clear.

LPEN rising edges capture the current column/raster row and set LP. Read-light-pen returns those two bytes without clearing LP. No optical delay compensation is built in.

## Assumption ledger / integration boundaries

* **ASSUMPTION A1:** all asynchronous package inputs are already synchronized; bus falling-edge acceptance has no historical nanosecond delays. Verify with held-low strobes and concurrent CPU/DMA tests.
* **ASSUMPTION A2:** reset power-up position is deterministic top left; Intel specifies random timing on power-up. Preset holds top left after two enabled character clocks and any new command releases it. Releasing into an empty active row can underrun; software should preset while video is stopped, then let vertical prefetch occur. Test exact counters and resume.
* **ASSUMPTION A3:** undefined width and undefined graphics codes have the deterministic behaviors above. Tests cover clamp/IC and blanking, but these are not compatibility promises for undefined hardware operation.
* **ASSUMPTION A4:** simultaneous status acknowledgement and newly arriving event retains the new event; CPU command has priority over a same-cycle DMA/raster event. Test these arbitration boundaries. No cross-clock metastability or electrical output pipeline is modeled.

This is a peripheral, so no CPU instruction oracle applies. Tests use original table transcription and independently sourced attribute vectors, not an RTL-derived golden model. Physical silicon timing and complete historical terminal firmware are outside sign-off.
