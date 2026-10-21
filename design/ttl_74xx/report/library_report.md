# Numbered 74-series coverage and verification

Updated 2026-10-21 03:57 UTC.

**Requested scope is incomplete.** 1393 catalog entries:
1024 normalized digital function models, **311 pending digital
parts**, and 58 analog/electrical exclusions. Numbers above 74299
have no artificial upper limit; wide-bus functions are included. Distinct family
functions retain their letters. Unknown historical introduction years are not guessed.

Implemented-subset tool results: **3072/3072**
current-source checks passed. Family formal check/cover tasks: 12/12.
Tool success is not full manufacturer-table or native pin compatibility certification.
See the [original range evidence](classic_range_report.md) for the preserved
74181 verification and corrections made to the first 289 models.

## Verification contract and limits

- Verilator --lint-only -Wall, no blanket warning suppression.
- xezim self-checking simulation with required per-part PASS marker and timeout.
- Yosys synthesis and check -assert. Models labelled memory_inference stop
  after coarse memory inference; other models use complete generic gate synthesis.
- Source/test/runner fingerprints prevent stale successes. ROM fixtures are
  synthetic test patterns, not recovered historical masks.
- Six formal families include the new unbounded 74574 storage/drive contract
  and covers. Formal verification is targeted, not exhaustive across the catalog.
- New imported models have normalized functional interfaces. Full native
  timing/control conformance remains unreviewed except where explicitly stated.
  Missing boundary-scan functions, generic placeholders and absent models are
  pending, with no misleading RTL stubs.
- New ROM/PROM models are read-only image-backed arrays. Selected RAM/FIFO
  models normalize clocks and controls; external board adapters must respect
  the local contract. Dual-clock FIFO simulations do not prove CDC safety.

## Pending digital functions

These are required by the user's scope. They are **not analog exclusions**.
The full run_all.sh completion gate returns nonzero while this table is nonempty.

| Part | Function | Reason / next work |
|---|---|---|
| [74x361](../spec/chips/ttl_74x361.md) | bubble memory function timing generator | Reference is a generic four-phase placeholder, not the bubble-memory timing-generator function. |
| [74S408](../spec/chips/ttl_74s408.md) | controller/driver for 16k/64k/256k dRAM | Reference DRAM controller omits manufacturer timing/control functions. |
| [74x430](../spec/chips/ttl_74x430.md) | cyclic redundancy checker/corrector | Reference generic CRC accumulator omits the advertised error corrector. |
| [74x655](../spec/chips/ttl_74x655.md) | octal buffer / line driver with parity, inverting | 74F655 datasheet not accessible via current sources; need confirmation of unidirectional buffer-with-parity pinout before implementation |
| [74x656](../spec/chips/ttl_74x656.md) | octal buffer / line driver with parity, non-inverting | 74F656 datasheet not accessible via current sources; need confirmation of unidirectional buffer-with-parity pinout before implementation |
| [74x658](../spec/chips/ttl_74x658.md) | octal bus transceiver, parity, inverting | HC-family parity transceiver datasheet not accessible from current sources; needs confirmation of control-pin set (registered vs combinational) before implementation |
| [74x659](../spec/chips/ttl_74x659.md) | octal bus transceiver, parity, non-inverting | HC-family parity transceiver datasheet not accessible from current sources; needs confirmation of control-pin set (registered vs combinational) before implementation |
| [74x664](../spec/chips/ttl_74x664.md) | octal bus transceiver, parity, inverting | HC-family parity transceiver datasheet not accessible from current sources; needs confirmation of control-pin set (registered vs combinational) before implementation |
| [74x665](../spec/chips/ttl_74x665.md) | octal bus transceiver, parity, non-inverting | HC-family parity transceiver datasheet not accessible from current sources; needs confirmation of control-pin set (registered vs combinational) before implementation |
| [74x681](../spec/chips/ttl_74x681.md) | 4-bit parallel binary accumulator | Datasheet not yet accessible via current sources; specific control-pin layout (shift register variants 671-676, ALS-family address comparators 677-680, accumulator 681) needs confirmation before RTL; Datasheet FOUND and correct: TI SN74LS681 (D2422, tidataBookVol2 n1339). NOT a simple accumulator: it is a 4-bit ALU (16 arithmetic + 16 logic ops) plus Word-A register and Word-B shift/accumulator register, carry look-ahead (Cn/P/G/Cn+4), bus-driving bidirectional I/O, 8 register modes (RS0-2), and serial shift (RI/LO, LI/RO). Implementable but a large multi-table effort (needs Tables 1/2/3) - deferred as a bigger task than the rest of this batch. |
| [74x694](../spec/chips/ttl_74x694.md) | 4-bit decimal counter/latch/multiplexer, synchronous and asynchronous clears | Counter/latch/multiplexer family datasheet not accessible from current sources; needs confirmation of control-pin set (load, count, latch, mux-select, OE) before RTL; Not present in the TI SN54LS690-693 / SN54LS696-699 databook — the family skips 694/695 (690-693, then 696-699). No datasheet found in TI/Signetics/Wikipedia sources; likely a spurious entry in the Wikipedia-derived list. Verify the part actually exists before attempting. |
| [74x695](../spec/chips/ttl_74x695.md) | 4-bit binary counter/latch/multiplexer, synchronous and asynchronous clears | Counter/latch/multiplexer family datasheet not accessible from current sources; needs confirmation of control-pin set (load, count, latch, mux-select, OE) before RTL; Not present in the TI SN54LS690-693 / SN54LS696-699 databook — the family skips 694/695. No datasheet found; likely a spurious entry in the Wikipedia-derived list. Verify existence before attempting. |
| [74x701](../spec/chips/ttl_74x701.md) | 8-bit register/counter/comparator | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL |
| [74x702](../spec/chips/ttl_74x702.md) | 8-bit registered read-back transceiver | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL; Datasheet located: National 74F702 8-bit registered readback transceiver, bitsavers_nationaldaFASTDatabook_31226275 page n621 (chips.json previously pointed to the 1988 FAST Advanced databook scan with an off-by-several page number). Complex bidirectional readback transceiver - deferred. |
| [74x705](../spec/chips/ttl_74x705.md) | arithmetic logic unit for digital signal processing applications | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL |
| [74x707](../spec/chips/ttl_74x707.md) | 8-bit TTL-ECL shift register | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL; Datasheet location: National 74F707 8-bit TTL-ECL shift register, bitsavers_nationaldaFASTDatabook_31226275 ~n622 (advance-information entry: general description + logic diagram only, no detailed function table). Cannot implement faithfully without the MODE/LE/clock-edge function table. |
| [74x710](../spec/chips/ttl_74x710.md) | 8-bit single-supply TTL-ECL shift register | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL; Datasheet located: National 74F710 single-supply TTL-ECL 8-bit shift register, bitsavers_nationaldaFASTDatabook_31226275 n624-625 (8-bit holding latch + shift register, MODE load/shift, differential ECL clock SC/SC-bar, outputs only at Q3/Q7). ADVANCE INFORMATION - no detailed function table (MODE/LE polarity), so not implementable faithfully from the available scan. |
| [74x715](../spec/chips/ttl_74x715.md) | programmable video sync generator | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL |
| [74x716](../spec/chips/ttl_74x716.md) | programmable decade counter | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL |
| [74x718](../spec/chips/ttl_74x718.md) | programmable binary counter | Datasheet not accessible from current sources; complex programmable/registered/FIFO part needs control-pin and internal-state confirmation before RTL |
| [74x732](../spec/chips/ttl_74x732.md) | 4-bit 3-bus multiplexer, inverting | Mux/3-bus-mux datasheet not accessible; needs confirmation of select/enable pin organization before RTL; Datasheet LOCATED: Signetics FAST 74F732 (Quad 4-bit 3-bus data multiplexer, bidirectional A/B/C buses, inverting, 3-state). chips.json datasheet_url page pointer was wrong (pointed to the 723/725 FIFO page). Correct location: bitsavers signeticsdaManual_57966640 pages n790-791. Held blocked: the routing FUNCTION TABLE (select S0..S2 / OEA,OEB,OEC -> source->dest) is not legible enough in the available scan to implement faithfully; needs a clearer datasheet. |
| [74x733](../spec/chips/ttl_74x733.md) | 4-bit 3-bus multiplexer, non-inverting | Mux/3-bus-mux datasheet not accessible; needs confirmation of select/enable pin organization before RTL; Datasheet LOCATED: Signetics FAST 74F733 (Quad 4-bit 3-bus data multiplexer, bidirectional, NON-inverting, 3-state). Correct location: bitsavers signeticsdaManual_57966640 pages n790-791 (chips.json pointer was wrong). Held blocked: routing function table not legible enough in the scan to implement faithfully; needs a clearer datasheet. |
| [74x758](../spec/chips/ttl_74x758.md) | quadruple bus transceivers, inverting outputs | Datasheet not accessible; quad/specialized configuration needs confirmation |
| [74x759](../spec/chips/ttl_74x759.md) | quadruple bus transceivers, non-inverting outputs | Datasheet not accessible; quad/specialized configuration needs confirmation |
| [74x762](../spec/chips/ttl_74x762.md) | octal buffer/line driver, inverting and non-inverting outputs | Datasheet not accessible; quad/specialized configuration needs confirmation |
| [74x764](../spec/chips/ttl_74x764.md) | dual-port dRAM controller | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x765](../spec/chips/ttl_74x765.md) | dual-port dRAM controller with address latch | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x776](../spec/chips/ttl_74x776.md) | 8-bit latched transceiver for FutureBus | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x777](../spec/chips/ttl_74x777.md) | triple latched transceiver | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x779](../spec/chips/ttl_74x779.md) | 8-bit bidirectional binary counter | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout; Datasheet located: National 74F779 8-bit bidirectional binary counter with tri-state, bitsavers_nationaldaFASTDatabook_31226275 n626-627 (chips.json previously pointed to a Motorola databook - WRONG archive item). Multiplexed tri-state I/O, S0/S1 modes (hold/up/down/load), lookahead carry. ADVANCE INFORMATION - no detailed function table in the available scan. |
| [74x783](../spec/chips/ttl_74x783.md) | synchronous address multiplexer for display systems | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x784](../spec/chips/ttl_74x784.md) | 8-bit serial/parallel multiplier with adder/subtractor | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x785](../spec/chips/ttl_74x785.md) | synchronous address multiplexer for display systems with 256-column refresh | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x786](../spec/chips/ttl_74x786.md) | 4-input asynchronous bus arbiter | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x790](../spec/chips/ttl_74x790.md) | error detection and correction (EDAC) | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x793](../spec/chips/ttl_74x793.md) | 8-bit latch, readback | Complex specialized part (DRAM controller, FutureBus latched transceiver, multiplier, display address mux, bus arbiter, EDAC, readback latch) requires datasheet for accurate control-pin layout |
| [74x794](../spec/chips/ttl_74x794.md) | 8-bit register, readback | Specialized part (readback register / clock driver / GTLP fanout / diagnostic register / bus-interface flop) requires datasheet for control-pin layout |
| [74x807](../spec/chips/ttl_74x807.md) | 1-to-10 clock driver | Specialized part (readback register / clock driver / GTLP fanout / diagnostic register / bus-interface flop) requires datasheet for control-pin layout |
| [74x817](../spec/chips/ttl_74x817.md) | GTL+ to LV-TTL 1-to-6 fanout / LV-TTL to GTL+ 1-to-2 fanout driver | Specialized part (readback register / clock driver / GTLP fanout / diagnostic register / bus-interface flop) requires datasheet for control-pin layout |
| [74x818](../spec/chips/ttl_74x818.md) | 8-bit diagnostic register | Specialized part (readback register / clock driver / GTLP fanout / diagnostic register / bus-interface flop) requires datasheet for control-pin layout |
| [74x819](../spec/chips/ttl_74x819.md) | 8-bit diagnostic / pipeline register | Specialized part (readback register / clock driver / GTLP fanout / diagnostic register / bus-interface flop) requires datasheet for control-pin layout |
| [74x839](../spec/chips/ttl_74x839.md) | field-programmable logic array 14x32x6 | FPLA (field-programmable logic array) is inherently programmable; no fixed function to model in synthesizable RTL |
| [74x840](../spec/chips/ttl_74x840.md) | field-programmable logic array 14x32x6 | FPLA (field-programmable logic array) is inherently programmable; no fixed function to model in synthesizable RTL |
| [74x848](../spec/chips/ttl_74x848.md) | 8 to 3-line priority encoder (glitch-less) | Datasheet not yet pulled; control-pin layout (transceiver port controller / 1-of-16 mux / parity-latch / counter) needs confirmation; chips.json datasheet_url page pointer is WRONG (points to the 74LS323 page in the Motorola Schottky databook). The real 74LS848 (8-to-3 'glitch-less' priority encoder) was not located; likely functionally close to the '148 but needs its own datasheet to confirm I/O polarity and the glitch-free/cascade pins. Needs correct datasheet before implementing. |
| [74x852](../spec/chips/ttl_74x852.md) | 8-bit universal transceiver port controller | Datasheet not yet pulled; control-pin layout (transceiver port controller / 1-of-16 mux / parity-latch / counter) needs confirmation |
| [74x853](../spec/chips/ttl_74x853.md) | 8-bit to 9-bit bus transceiver with parity latch, non-inverting | Datasheet not yet pulled; control-pin layout (transceiver port controller / 1-of-16 mux / parity-latch / counter) needs confirmation |
| [74x854](../spec/chips/ttl_74x854.md) | 8-bit to 9-bit bus transceiver with parity latch, inverting | Datasheet not yet pulled; control-pin layout (transceiver port controller / 1-of-16 mux / parity-latch / counter) needs confirmation |
| [74x856](../spec/chips/ttl_74x856.md) | 8-bit universal transceiver port controller | Datasheet not yet pulled; control-pin layout (transceiver port controller / 1-of-16 mux / parity-latch / counter) needs confirmation |
| [74x870](../spec/chips/ttl_74x870.md) | dual 16x4 register files | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x871](../spec/chips/ttl_74x871.md) | dual 16x4 register files | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x877](../spec/chips/ttl_74x877.md) | 8-bit universal transceiver port controller | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x887](../spec/chips/ttl_74x887.md) | 8-bit processor element (non-cascadable version of 74x888) | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x888](../spec/chips/ttl_74x888.md) | 8-bit processor slice | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x889](../spec/chips/ttl_74x889.md) | 8-bit processor slice | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x890](../spec/chips/ttl_74x890.md) | microoperation sequencer | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x891](../spec/chips/ttl_74x891.md) | microoperation sequencer | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x895](../spec/chips/ttl_74x895.md) | 8-bit memory address generator | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x897](../spec/chips/ttl_74x897.md) | 16-bit parallel/serial barrel shifter | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x899](../spec/chips/ttl_74x899.md) | 9-bit latchable transceiver with parity generator / checker | Complex bit-slice / processor / sequencer / wide register file / programmable counter / barrel shifter — needs datasheet study before RTL |
| [74x905](../spec/chips/ttl_74x905.md) | 12-bit successive approximation register | Specialized (SAR / voltage comparator analog / RAM / display controllers) — needs dedicated datasheet study |
| [74x911](../spec/chips/ttl_74x911.md) | 4-digit expandable display controller | Specialized (SAR / voltage comparator analog / RAM / display controllers) — needs dedicated datasheet study |
| [74x912](../spec/chips/ttl_74x912.md) | 6-digit BCD display controller and driver | Specialized (SAR / voltage comparator analog / RAM / display controllers) — needs dedicated datasheet study |
| [74x913](../spec/chips/ttl_74x913.md) | 6-digit BCD display controller and driver, no decimal point | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x917](../spec/chips/ttl_74x917.md) | 6-digit hex display controller and driver | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x922](../spec/chips/ttl_74x922.md) | 16-key encoder | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x923](../spec/chips/ttl_74x923.md) | 20-key encoder | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x925](../spec/chips/ttl_74x925.md) | 4-digit counter/display driver | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x926](../spec/chips/ttl_74x926.md) | 4-digit decade counter/display driver, carry out and latch (up to 9999) | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x927](../spec/chips/ttl_74x927.md) | 4-digit timer counter/display driver (up to 9599, intended as time elapsed, i.e. 9:59.9 min) | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x928](../spec/chips/ttl_74x928.md) | 4-digit counter/display driver (up to 1999) | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x932](../spec/chips/ttl_74x932.md) | phase comparator | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x942](../spec/chips/ttl_74x942.md) | 300 baud Bell 103 modem (+/- 5 V supply) | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x943](../spec/chips/ttl_74x943.md) | 300 baud Bell 103 modem (single 5 V supply) | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x945](../spec/chips/ttl_74x945.md) | 4-digit up/down counter, decoder and LCD driver, output latch | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x946](../spec/chips/ttl_74x946.md) | 4.5-digit counter, decoder and LCD driver, leading zero blanking | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x947](../spec/chips/ttl_74x947.md) | 4-digit up/down counter, decoder and LCD driver, leading zero blanking | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study |
| [74x952](../spec/chips/ttl_74x952.md) | dual rank 8-bit shift register, synchronous clear | Display controller / RAM / key encoder / counter+display / ADC / modem / LCD driver / shift register variant — needs dedicated datasheet study; Datasheet FOUND: National DM74LS952 (TL/F/6437; syntax.com.tw/upload/pdf/IC-74LS952.pdf). NOT a simple shift register: dual-rank (upper register A + lower shift register B) with 8 bidirectional TRI-STATE I/O, 6 active-low control lines, and a ~20-row function table including a Data-OR (DOR) function (ORs I/O with reg B), simultaneous transfer-up+down = synchronous clear, and combined shift+transfer modes. Complex multi-mode part - deferred (high mis-model risk), like 681/870/871. |
| [74x1017](../spec/chips/ttl_74x1017.md) | 16x16-bit parallel multiplier | Wide multiplier/accumulator or passive termination array — needs dedicated datasheet |
| [74x1018](../spec/chips/ttl_74x1018.md) | 18-bit Schottky diode R-C bus termination array | Wide multiplier/accumulator or passive termination array — needs dedicated datasheet |
| [74x1050](../spec/chips/ttl_74x1050.md) | 12-bit Schottky diode bus termination array, clamp to GND | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1051](../spec/chips/ttl_74x1051.md) | 12-bit Schottky diode bus termination array, clamp to GND/V | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1052](../spec/chips/ttl_74x1052.md) | 16-bit Schottky diode bus termination array, clamp to GND | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1053](../spec/chips/ttl_74x1053.md) | 16-bit Schottky diode bus termination array, clamp to GND/V | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1056](../spec/chips/ttl_74x1056.md) | 8-bit Schottky diode bus termination array, clamp to GND | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1071](../spec/chips/ttl_74x1071.md) | 10-bit bus termination array with bus-hold function | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1073](../spec/chips/ttl_74x1073.md) | 16-bit bus termination array with bus-hold function | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1284](../spec/chips/ttl_74x1284.md) | parallel printer interface transceiver / buffer (IEEE 1284) | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1394](../spec/chips/ttl_74x1394.md) | 2-bit GTLP transceiver with split LV-TTL port | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1395](../spec/chips/ttl_74x1395.md) | Dual 1-bit GTLP transceiver with split LV-TTL port | Termination array / IEEE 1284 / GTLP transceiver / wider parity register — needs datasheet |
| [74x1404](../spec/chips/ttl_74x1404.md) | oscillator driver | Oscillator driver; physical/analog crystal-oscillator buffer with no clocked logic to model |
| [74x1612](../spec/chips/ttl_74x1612.md) | 18-bit LV-TTL-to-GTLP adjustable-edge-rate universal bus transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1620](../spec/chips/ttl_74x1620.md) | octal bus transceiver, inverting | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1621](../spec/chips/ttl_74x1621.md) | octal bus transceiver, non-inverting | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1622](../spec/chips/ttl_74x1622.md) | octal bus transceiver, inverting | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1623](../spec/chips/ttl_74x1623.md) | octal bus transceiver, non-inverting | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1627](../spec/chips/ttl_74x1627.md) | 18-bit LV-TTL-to-GTLP adjustable-edge-rate bus transceiver with source synchronous clock outputs | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1631](../spec/chips/ttl_74x1631.md) | quad bus driver with complementary outputs | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1650](../spec/chips/ttl_74x1650.md) | dual 9-bit Futurebus universal storage transceiver with split TTL I/O | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1651](../spec/chips/ttl_74x1651.md) | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split TTL I/O | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1653](../spec/chips/ttl_74x1653.md) | 9-bit and 8-bit Futurebus universal storage transceivers with delayed buffered clock with split 3.3V TTL I/O | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1655](../spec/chips/ttl_74x1655.md) | dual 8-bit GTL universal storage transceivers with live insertion | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1761](../spec/chips/ttl_74x1761.md) | dRAM and interrupt vector controller | Combined DRAM + interrupt vector controller; complex state machine + interrupt protocol requires SN74F1761 datasheet |
| [74x1763](../spec/chips/ttl_74x1763.md) | single-port dRAM controller | Single-port DRAM controller; refresh state machine + arbitration requires SN74F1763 datasheet |
| [74x1764](../spec/chips/ttl_74x1764.md) | dual-port dRAM controller | Dual-port DRAM controller; port arbitration requires SN74F1764 datasheet |
| [74x1765](../spec/chips/ttl_74x1765.md) | dual-port dRAM controller with address latch | Dual-port DRAM controller with address latch; requires SN74F1765 datasheet |
| [74x1766](../spec/chips/ttl_74x1766.md) | burst mode dRAM controller | Burst-mode DRAM controller; burst state machine requires SN74F1766 datasheet |
| [74x1801](../spec/chips/ttl_74x1801.md) | FM, MFM, and DM encoder / decoder, data rates up to 10 MHz | FM/MFM/DM disk encoder/decoder; analog/timing-heavy floppy data separator requires WD/Intel datasheet |
| [74x1802](../spec/chips/ttl_74x1802.md) | SerDes with ECC and CRC, data rates up to 10 MHz | SerDes with ECC and CRC; complex serial protocol requires part-specific datasheet |
| [74x1811](../spec/chips/ttl_74x1811.md) | FM, MFM, and DM encoder / decoder, data rates up to 20 MHz | FM/MFM/DM disk encoder/decoder (faster); same blocker as 74x1801 |
| [74x1812](../spec/chips/ttl_74x1812.md) | SerDes with ECC and CRC, data rates up to 30 MHz | SerDes with ECC and CRC (faster); same blocker as 74x1802 |
| [74x2000](../spec/chips/ttl_74x2000.md) | direction discriminator with microprocessor interface | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2003](../spec/chips/ttl_74x2003.md) | 8-bit level translator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2006](../spec/chips/ttl_74x2006.md) | 13-bit GTL to 3.3V TTL level translator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2007](../spec/chips/ttl_74x2007.md) | 12-bit GTL to 3.3V TTL level translator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2010](../spec/chips/ttl_74x2010.md) | 10-bit level translator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2014](../spec/chips/ttl_74x2014.md) | 4-bit GTL to TTL transceiver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2031](../spec/chips/ttl_74x2031.md) | 9-bit Futurebus address/data transceiver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2032](../spec/chips/ttl_74x2032.md) | 9-bit Futurebus competition transceiver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2034](../spec/chips/ttl_74x2034.md) | 8-bit GTLP adjustable-edge-rate registered transceiver with split LV-TTL I/O | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2040](../spec/chips/ttl_74x2040.md) | 8-bit Futurebus transceiver with split TTL I/O | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2041](../spec/chips/ttl_74x2041.md) | 7-bit Futurebus transceiver with split TTL I/O | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2107](../spec/chips/ttl_74x2107.md) | 12-bit GTL to 3.3V TTL level translator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2150](../spec/chips/ttl_74x2150.md) | 512 x 8 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2152](../spec/chips/ttl_74x2152.md) | 2k x 8 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2154](../spec/chips/ttl_74x2154.md) | 2k x 8 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2155](../spec/chips/ttl_74x2155.md) | 2k x 8 burst cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2156](../spec/chips/ttl_74x2156.md) | 16k x 4 burst cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2158](../spec/chips/ttl_74x2158.md) | 8k x 9 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2159](../spec/chips/ttl_74x2159.md) | 8k x 9 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2160](../spec/chips/ttl_74x2160.md) | 8k x 4 2-way cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2164](../spec/chips/ttl_74x2164.md) | 16k x 5 cache address comparator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2166](../spec/chips/ttl_74x2166.md) | 16k x 5 cache address comparator with input latches | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2323](../spec/chips/ttl_74x2323.md) | dual line receiver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2410](../spec/chips/ttl_74x2410.md) | 11-bit MOS memory driver, non-inverting | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2411](../spec/chips/ttl_74x2411.md) | 11-bit MOS memory driver, inverting | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2414](../spec/chips/ttl_74x2414.md) | dual 2-to-4 line decoder with supply voltage monitor | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2420](../spec/chips/ttl_74x2420.md) | 16-bit NuBus address/data transceiver and register | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2423](../spec/chips/ttl_74x2423.md) | 16-bit latched multiplexer/demultiplexer NuBus transceiver, inverting | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2424](../spec/chips/ttl_74x2424.md) | 16-bit latched multiplexer/demultiplexer NuBus transceiver, non-inverting | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2425](../spec/chips/ttl_74x2425.md) | Macintosh Coprocessor Platform NuBus address/data registered transceiver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2440](../spec/chips/ttl_74x2440.md) | NuBus interface controller | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2441](../spec/chips/ttl_74x2441.md) | NuBus interface controller | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2442](../spec/chips/ttl_74x2442.md) | NuBus block slave address generator | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2525](../spec/chips/ttl_74x2525.md) | 8-output clock driver | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2526](../spec/chips/ttl_74x2526.md) | 8-output clock driver with input multiplexer | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2620](../spec/chips/ttl_74x2620.md) | octal bus transceiver / MOS driver, inverting | Specialized cache comparator / NuBus / GTL / clock driver / FIFO / level translator — needs dedicated datasheet |
| [74x2960](../spec/chips/ttl_74x2960.md) | error detection and correction (EDAC), equivalent to Am2960 | EDAC equivalent to Am2960; complex syndrome generation/decode and check-bit ALU requires Am2960 datasheet |
| [74x2969](../spec/chips/ttl_74x2969.md) | memory timing controller for use with EDAC | Memory timing controller for EDAC use; complex state machine requires SN74F2969 datasheet |
| [74x2970](../spec/chips/ttl_74x2970.md) | memory timing controller for use without EDAC | Memory timing controller (non-EDAC); complex state machine requires SN74F2970 datasheet |
| [74x3004](../spec/chips/ttl_74x3004.md) | selectable GTL voltage reference | GTL voltage reference; analog 1.0V/1.2V reference generator with no digital logic |
| [74x3125](../spec/chips/ttl_74x3125.md) | quad FET bus switch, output enable active low | Quad FET bus switch; physical switch with no logical model, like 74CBT3245 |
| [74x3126](../spec/chips/ttl_74x3126.md) | quad FET bus switch, output enable active high | Quad FET bus switch, OE active high; physical switch with no logical model |
| [74x3251](../spec/chips/ttl_74x3251.md) | 8-line to 1-line FET multiplexer / demultiplexer | 8-to-1 FET multiplexer/demultiplexer; analog FET switch, not modeled |
| [74x3253](../spec/chips/ttl_74x3253.md) | dual 4-line to 1-line FET multiplexer / demultiplexer | Dual 4-to-1 FET multiplexer/demultiplexer; analog FET switch, not modeled |
| [74x3257](../spec/chips/ttl_74x3257.md) | quad 2-line to 1-line FET multiplexer / demultiplexer | Quad 2-to-1 FET multiplexer/demultiplexer; analog FET switch, not modeled |
| [74x3305](../spec/chips/ttl_74x3305.md) | dual FET bus switch with extended voltage range | Dual FET bus switch with extended voltage range; analog FET switch |
| [74x3306](../spec/chips/ttl_74x3306.md) | dual FET bus switch | Dual FET bus switch; analog FET switch |
| [74x3345](../spec/chips/ttl_74x3345.md) | octal FET bus switch, dual output enable | Octal FET bus switch with dual OE; analog FET switch |
| [74x3383](../spec/chips/ttl_74x3383.md) | 5-bit 4-port FET bus exchange switch | 5-bit 4-port FET bus exchange switch; analog FET switch crossbar |
| [74x3384](../spec/chips/ttl_74x3384.md) | dual 5-bit FET bus switch | Dual 5-bit FET bus switch; analog FET switch |
| [74x3386](../spec/chips/ttl_74x3386.md) | 5-bit 4-port FET bus exchange switch with extended voltage range | 5-bit 4-port FET bus exchange switch, extended voltage; analog FET switch |
| [74x3390](../spec/chips/ttl_74x3390.md) | octal 2-line to 1-line FET multiplexer / bus switch | Octal 2-to-1 FET multiplexer / bus switch; analog FET switch |
| [74x3584](../spec/chips/ttl_74x3584.md) | dual 5-bit FET bus switch | Dual 5-bit FET bus switch; analog FET switch |
| [74x3807](../spec/chips/ttl_74x3807.md) | 1-to-10 clock driver | 1-to-10 clock driver/buffer; physical clock fanout buffer, electrical not logical |
| [74x3861](../spec/chips/ttl_74x3861.md) | 10-bit FET bus switch | 10-bit FET bus switch; analog FET switch |
| [74x3862](../spec/chips/ttl_74x3862.md) | 10-bit FET bus switch with dual output enable | 10-bit FET bus switch with dual OE; analog FET switch |
| [74x3893](../spec/chips/ttl_74x3893.md) | quad Futurebus backplane transceiver | Quad Futurebus backplane transceiver; specialized backplane physical-layer transceiver requires datasheet |
| [74x3907](../spec/chips/ttl_74x3907.md) | Pentium clock synthesizer | Pentium clock synthesizer; PLL-based clock multiplier with frequency synthesis |
| [74x4016](../spec/chips/ttl_74x4016.md) | quad bilateral switch | Quad bilateral analog switch; CMOS transmission gates, not modeled digitally |
| [74x4059](../spec/chips/ttl_74x4059.md) | programmable divide-by-N counter | Reference generic binary divider omits the programmed BCD/mode decoding. |
| [74x4060](../spec/chips/ttl_74x4060.md) | 14-stage binary ripple counter with oscillator | 14-stage binary counter with on-chip oscillator; oscillator portion is analog/timing |
| [74x4061](../spec/chips/ttl_74x4061.md) | 14-stage asynchronous binary counter with oscillator | 14-stage async binary counter with on-chip oscillator; same blocker as 74x4060 |
| [74x4503](../spec/chips/ttl_74x4503.md) | controller for 64k/256k/1M dynamic RAM | Programmable DRAM controller for 64k/256k/1M; complex state machine requires datasheet |
| [74x4764](../spec/chips/ttl_74x4764.md) | programmable dRAM controller | Programmable DRAM controller; complex programming + state machine requires datasheet |
| [74x4799](../spec/chips/ttl_74x4799.md) | Timer for NiCd and NiMH chargers | Timer for NiCd/NiMH battery chargers; specialized application-specific timer |
| [74x5555](../spec/chips/ttl_74x5555.md) | programmable delay timer with oscillator | Programmable delay timer with oscillator; analog RC oscillator and delay generator |
| [74x6000](../spec/chips/ttl_74x6000.md) | logic-to-logic optocoupler, non-inverting | Logic-to-logic optocoupler; opto-isolator physical device |
| [74x6001](../spec/chips/ttl_74x6001.md) | logic-to-logic optocoupler, inverting | Logic-to-logic optocoupler (inverting); opto-isolator physical device |
| [74x6010](../spec/chips/ttl_74x6010.md) | logic-to-logic optocoupler, non-inverting | Logic-to-logic optocoupler; opto-isolator physical device |
| [74x6011](../spec/chips/ttl_74x6011.md) | logic-to-logic optocoupler, inverting | Logic-to-logic optocoupler (inverting); opto-isolator physical device |
| [74x6300](../spec/chips/ttl_74x6300.md) | programmable dynamic memory refresh timer | Programmable DRAM refresh timer; complex programmable timing controller |
| [74x6301](../spec/chips/ttl_74x6301.md) | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | DRAM refresh controller; complex state machine requires datasheet |
| [74x6302](../spec/chips/ttl_74x6302.md) | dynamic memory refresh controller, transparent and burst modes, for 16K, 64K, 256K, and 1M dRAM | DRAM refresh controller; complex state machine requires datasheet |
| [74x6310](../spec/chips/ttl_74x6310.md) | static column and page mode access detector for dRAM | Static column/page mode access detector for dRAM; specialized detector requires datasheet |
| [74x6311](../spec/chips/ttl_74x6311.md) | static column and page mode access detector for dRAM | Static column/page mode access detector for dRAM; specialized detector requires datasheet |
| [74x6323](../spec/chips/ttl_74x6323.md) | programmable ripple counter with oscillator | Programmable ripple counter with on-chip oscillator; oscillator portion is analog |
| [74x6364](../spec/chips/ttl_74x6364.md) | 64-bit flow-through error detection and correction circuit | 64-bit flow-through EDAC; complex syndrome generation/decode requires datasheet |
| [74x6800](../spec/chips/ttl_74x6800.md) | 10-bit FET bus switch with precharge | 10-bit FET bus switch with precharge; analog FET switch |
| [74x6845](../spec/chips/ttl_74x6845.md) | 8-bit FET bus switch with precharge and extended voltage range | 8-bit FET bus switch with precharge; analog FET switch |
| [74x7060](../spec/chips/ttl_74x7060.md) | 14-stage binary counter with oscillator | 14-stage binary counter with on-chip oscillator; oscillator portion is analog |
| [74x8240](../spec/chips/ttl_74x8240.md) | octal inverting buffer with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8244](../spec/chips/ttl_74x8244.md) | octal non-inverting buffer with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8245](../spec/chips/ttl_74x8245.md) | octal bus transceiver with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8373](../spec/chips/ttl_74x8373.md) | octal D-type latch with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8374](../spec/chips/ttl_74x8374.md) | octal D-type edge-triggered flip-flop with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8400](../spec/chips/ttl_74x8400.md) | expandable error checker / corrector | Expandable error checker/corrector; complex EDAC with cascade, needs datasheet |
| [74x8543](../spec/chips/ttl_74x8543.md) | octal registered bus transceiver with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8646](../spec/chips/ttl_74x8646.md) | octal bus transceiver and register with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8652](../spec/chips/ttl_74x8652.md) | octal bus transceiver and register with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8818](../spec/chips/ttl_74x8818.md) | 16-bit microprogram sequencer, cascadable | 16-bit microprogram sequencer (Am2910-class); complex sequencer requires datasheet |
| [74x8832](../spec/chips/ttl_74x8832.md) | 32-bit registered ALU | 32-bit registered ALU; complex datapath, needs Am29332-class datasheet |
| [74x8834](../spec/chips/ttl_74x8834.md) | 40-bit register file | 40-bit register file; specific port architecture requires datasheet |
| [74x8835](../spec/chips/ttl_74x8835.md) | 16-bit microprogram sequencer, cascadable | 16-bit microprogram sequencer (Am29C10A); needs datasheet |
| [74x8836](../spec/chips/ttl_74x8836.md) | 32x32-bit multiplier/accumulator | 32x32-bit multiplier/accumulator; complex datapath, needs datasheet |
| [74x8837](../spec/chips/ttl_74x8837.md) | 64-bit floating point unit | 64-bit FPU; complex IEEE 754 unit, needs datasheet |
| [74x8839](../spec/chips/ttl_74x8839.md) | 32-bit shuffle/exchange network | 32-bit shuffle/exchange network; specialized permutation network requires datasheet |
| [74x8840](../spec/chips/ttl_74x8840.md) | digital crossbar switch | Digital crossbar switch; specialized crossbar configuration requires datasheet |
| [74x8841](../spec/chips/ttl_74x8841.md) | digital crossbar switch | Digital crossbar switch; specialized crossbar configuration requires datasheet |
| [74x8847](../spec/chips/ttl_74x8847.md) | 64-bit floating point and integer unit | 64-bit FPU and integer unit; complex IEEE 754 unit, needs datasheet |
| [74x8867](../spec/chips/ttl_74x8867.md) | 32-bit vector processor unit | 32-bit vector processor unit; complex VPU, needs datasheet |
| [74x8952](../spec/chips/ttl_74x8952.md) | octal registered bus transceiver with JTAG port | Reference omits the digital JTAG/boundary-scan function; a plain buffer is insufficient. |
| [74x8980](../spec/chips/ttl_74x8980.md) | JTAG test access port master with 8-bit host interface | JTAG test access port master with 8-bit host interface; complex TAP controller requires datasheet |
| [74x8986](../spec/chips/ttl_74x8986.md) | linkable, multidrop-addressable JTAG transceiver | Multidrop-addressable JTAG transceiver; specialized JTAG topology requires datasheet |
| [74x8990](../spec/chips/ttl_74x8990.md) | JTAG test access port master with 16-bit host interface | JTAG test access port master with 16-bit host interface; complex TAP controller requires datasheet |
| [74x8994](../spec/chips/ttl_74x8994.md) | JTAG scan-controlled logic/signature analyzer | JTAG scan-controlled logic/signature analyzer; complex scan engine requires datasheet |
| [74x8996](../spec/chips/ttl_74x8996.md) | multidrop-addressable JTAG transceiver | Multidrop-addressable JTAG transceiver; specialized JTAG topology requires datasheet |
| [74x8997](../spec/chips/ttl_74x8997.md) | scan-controlled JTAG concatenator | Scan-controlled JTAG concatenator; specialized scan-chain wiring requires datasheet |
| [74x8999](../spec/chips/ttl_74x8999.md) | scan-controlled JTAG multiplexer | Scan-controlled JTAG multiplexer; specialized JTAG MUX requires datasheet |
| [74x9000](../spec/chips/ttl_74x9000.md) | programmable timer with oscillator | Programmable timer with on-chip oscillator; oscillator portion is analog |
| [74x9323](../spec/chips/ttl_74x9323.md) | programmable ripple counter with oscillator | Programmable ripple counter with oscillator; oscillator portion is analog |
| [74x9510](../spec/chips/ttl_74x9510.md) | 16×16-bit multiplier/accumulator (compatible to Am29510 and TDC1010) | 16x16-bit MAC (Am29510/TDC1010-equivalent); complex pipelined multiplier-accumulator |
| [74x1616](../spec/chips/ttl_74x1616.md) | 17-bit LVTTL-to-GTLP adjustable edge rate universal bus transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x1645](../spec/chips/ttl_74x1645.md) | 16-bit LVTTL-to-GTLP adjustable edge rate bus transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16209](../spec/chips/ttl_74x16209.md) | 18-bit FET bus exchange switches | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16210](../spec/chips/ttl_74x16210.md) | 20-bit FET bus switch | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16211](../spec/chips/ttl_74x16211.md) | 24-bit FET bus switch | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16212](../spec/chips/ttl_74x16212.md) | 24-bit FET bus exchange switches | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16213](../spec/chips/ttl_74x16213.md) | 24-bit FET bus exchange switches | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16214](../spec/chips/ttl_74x16214.md) | 12-bit 1-of-3 FET multiplexer/demultiplexer | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16232](../spec/chips/ttl_74x16232.md) | synchronous 16-bit 1-of-2 FET multiplexer/demultiplexer | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16233](../spec/chips/ttl_74x16233.md) | 16-bit 1-of-2 FET multiplexer/demultiplexer | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16241](../spec/chips/ttl_74x16241.md) | 16-bit non-inverting buffer/driver with grouped 4-bit output enables (1 and 4 active-low) | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16246](../spec/chips/ttl_74x16246.md) | 11-bit incident wave switching bus transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16260](../spec/chips/ttl_74x16260.md) | 12-bit to 24-bit multiplexed D-type latches | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16269](../spec/chips/ttl_74x16269.md) | 12-bit to 24-bit registered bus exchanger | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16270](../spec/chips/ttl_74x16270.md) | 12-bit to 24-bit registered bus exchanger | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16271](../spec/chips/ttl_74x16271.md) | 12-bit to 24-bit multiplexed bus exchanger | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16282](../spec/chips/ttl_74x16282.md) | 18-bit to 36-bit registered bus exchanger | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16292](../spec/chips/ttl_74x16292.md) | 12-bit 1-of-2 FET multiplexer/demultiplexer | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16334](../spec/chips/ttl_74x16334.md) | 16-bit universal bus driver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16344](../spec/chips/ttl_74x16344.md) | 1-bit to 4-bit address driver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16390](../spec/chips/ttl_74x16390.md) | 16-bit to 32-bit FET multiplexer/demultiplexer bus switch | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16409](../spec/chips/ttl_74x16409.md) | 9-bit 4-port universal bus exchanger | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16460](../spec/chips/ttl_74x16460.md) | 4-to-1 multiplexed/demultiplexed registered transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16470](../spec/chips/ttl_74x16470.md) | 16-bit registered transceiver | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16500](../spec/chips/ttl_74x16500.md) | 18-bit universal bus transceiver (registered, active low clock) | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16501](../spec/chips/ttl_74x16501.md) | 18-bit universal bus transceiver (registered, active high clock) | Specialized Widebus/FET/GTLP/Futurebus part — needs dedicated datasheet study |
| [74x16600](../spec/chips/ttl_74x16600.md) | 18-bit universal bus transceiver (registered, active low clock) | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16601](../spec/chips/ttl_74x16601.md) | 18-bit universal bus transceiver (registered, active high clock) | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16612](../spec/chips/ttl_74x16612.md) | 18-bit LVTTL-to-GTL+ universal bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16616](../spec/chips/ttl_74x16616.md) | 17-bit LVTTL-to-GTL+ universal bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16622](../spec/chips/ttl_74x16622.md) | 18-bit LVTTL-to-GTL+ bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16646](../spec/chips/ttl_74x16646.md) | 16-bit bus transceiver and registers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16648](../spec/chips/ttl_74x16648.md) | 16-bit bus transceiver and registers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16651](../spec/chips/ttl_74x16651.md) | 16-bit bus transceiver and registers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16652](../spec/chips/ttl_74x16652.md) | 16-bit bus transceiver and registers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16657](../spec/chips/ttl_74x16657.md) | 16-bit bus transceiver with parity generators/checkers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16800](../spec/chips/ttl_74x16800.md) | 20-bit FET bus switch | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16811](../spec/chips/ttl_74x16811.md) | 24-bit FET bus switch | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16831](../spec/chips/ttl_74x16831.md) | 1-to-4 address register/driver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16832](../spec/chips/ttl_74x16832.md) | 1-to-4 address register/driver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16833](../spec/chips/ttl_74x16833.md) | dual 8-bit to 9-bit parity bus transceivers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16834](../spec/chips/ttl_74x16834.md) | 18-bit universal bus driver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16835](../spec/chips/ttl_74x16835.md) | 18-bit universal bus driver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16853](../spec/chips/ttl_74x16853.md) | dual 8-bit to 9-bit parity bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16857](../spec/chips/ttl_74x16857.md) | 14-bit registered buffer | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16859](../spec/chips/ttl_74x16859.md) | 13-bit to 26-bit registered buffer | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16861](../spec/chips/ttl_74x16861.md) | 20-bit FET bus switch | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16901](../spec/chips/ttl_74x16901.md) | 18-bit universal bus transceiver with parity generators/checkers | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16903](../spec/chips/ttl_74x16903.md) | 3.3-V 12-bit universal bus driver with parity checker | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16912](../spec/chips/ttl_74x16912.md) | 18-bit LVTTL-to-GTLP universal bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16916](../spec/chips/ttl_74x16916.md) | 17-bit LVTTL-to-GTLP universal bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16923](../spec/chips/ttl_74x16923.md) | 18-bit LVTTL-to-GTLP universal bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16945](../spec/chips/ttl_74x16945.md) | 16-bit LVTTL-to-GTLP bus transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x16952](../spec/chips/ttl_74x16952.md) | 16-bit registered transceiver | Widebus registered/parity/FET/GTLP transceiver — needs dedicated datasheet |
| [74x162260](../spec/chips/ttl_74x162260.md) | 12-bit to 24-bit multiplexed D-type latch | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162268](../spec/chips/ttl_74x162268.md) | 12-bit to 24-bit registered bus exchanger | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162280](../spec/chips/ttl_74x162280.md) | 16-bit to 32-bit registered bus exchanger with byte masks | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162282](../spec/chips/ttl_74x162282.md) | 18-bit to 36-bit registered bus exchanger | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162292](../spec/chips/ttl_74x162292.md) | 12-bit 1-of-2 FET multiplexer/demultiplexer | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162334](../spec/chips/ttl_74x162334.md) | 16-bit universal bus driver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162344](../spec/chips/ttl_74x162344.md) | 1-bit to 4-bit address driver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162460](../spec/chips/ttl_74x162460.md) | 4-to-1 multiplexed/demultiplexed registered transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162500](../spec/chips/ttl_74x162500.md) | 18-bit universal bus transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162501](../spec/chips/ttl_74x162501.md) | 18-bit registered transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162525](../spec/chips/ttl_74x162525.md) | 18-bit registered bus transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162543](../spec/chips/ttl_74x162543.md) | 16-bit latched transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162601](../spec/chips/ttl_74x162601.md) | 18-bit universal bus tranceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162646](../spec/chips/ttl_74x162646.md) | 16-bit registered transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162652](../spec/chips/ttl_74x162652.md) | 16-bit registered transceiver | Specialized Widebus 3.3-V part — needs dedicated datasheet |
| [74x162830](../spec/chips/ttl_74x162830.md) | 1-bit to 2-bit address driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x162831](../spec/chips/ttl_74x162831.md) | 1-bit to 4-bit address register/driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x162832](../spec/chips/ttl_74x162832.md) | 1-bit to 4-bit address register/driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x162834](../spec/chips/ttl_74x162834.md) | 3.3-V CMOS 18-bit universal bus driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x162835](../spec/chips/ttl_74x162835.md) | 18-bit universal bus driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x162836](../spec/chips/ttl_74x162836.md) | 20-bit universal bus driver | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x18245](../spec/chips/ttl_74x18245.md) | scan test devices with 18-bit bus transceivers | Specialized address driver / universal bus driver / scan-test part — needs datasheet |
| [74x18502](../spec/chips/ttl_74x18502.md) | scan test devices with 18-bit universal bus transceivers | Scan test device with 18-bit universal bus transceiver; specialized scan logic requires datasheet |
| [74x18504](../spec/chips/ttl_74x18504.md) | scan test devices with 20-bit universal bus transceivers | Scan test device with 20-bit universal bus transceiver; specialized scan logic requires datasheet |
| [74x18512](../spec/chips/ttl_74x18512.md) | scan test devices with 18-bit universal bus transceivers | Scan test device with 18-bit universal bus transceiver; specialized scan logic requires datasheet |
| [74x18640](../spec/chips/ttl_74x18640.md) | scan test devices with 18-bit inverting bus transceivers | Scan test device 18-bit inverting transceiver; scan logic requires datasheet |
| [74x18646](../spec/chips/ttl_74x18646.md) | scan test devices with 18-bit transceivers and registers | Scan test device 18-bit transceiver+registers; scan logic requires datasheet |
| [74x18652](../spec/chips/ttl_74x18652.md) | scan test devices with 18-bit transceivers and registers | Scan test device 18-bit transceiver+registers; scan logic requires datasheet |
| [74x182502](../spec/chips/ttl_74x182502.md) | scan test devices with 18-bit universal bus transceivers | Scan test device 18-bit universal transceiver; scan logic requires datasheet |
| [74x182504](../spec/chips/ttl_74x182504.md) | scan test devices with 20-bit universal bus transceivers | Scan test device 20-bit universal transceiver; scan logic requires datasheet |
| [74x182512](../spec/chips/ttl_74x182512.md) | scan test devices with 18-bit universal bus transceivers | Scan test device 18-bit universal transceiver; scan logic requires datasheet |
| [74x182646](../spec/chips/ttl_74x182646.md) | scan test devices with 18-bit transceivers and registers | Scan test device 18-bit transceiver+registers; scan logic requires datasheet |
| [74x182652](../spec/chips/ttl_74x182652.md) | scan test devices with 18-bit transceivers and registers | Scan test device 18-bit transceiver+registers; scan logic requires datasheet |
| [74x22033](../spec/chips/ttl_74x22033.md) | 8-bit LVTTL-to-GTLP adjustable edge rate registered transceiver | LVTTL-to-GTLP adjustable edge rate transceiver; physical signaling-level translation |
| [74x32316](../spec/chips/ttl_74x32316.md) | 16-bit tri-port universal bus exchangers | 16-bit tri-port universal bus exchanger; specialized 3-way exchange requires datasheet |
| [74x32318](../spec/chips/ttl_74x32318.md) | 18-bit tri-port universal bus exchangers | 18-bit tri-port universal bus exchanger; specialized 3-way exchange requires datasheet |

## Analog exclusions

- 74x31: hex delay elements (two 6ns, two 23-32ns, two 45-48ns).
- 74x121: monostable multivibrator.
- 74x122: retriggerable monostable multivibrator, clear.
- 74x123: dual retriggerable monostable multivibrator, clear.
- 74x124: dual voltage-controlled oscillator.
- 74x130: retriggerable monostable multivibrator.
- 74x221: dual monostable multivibrator.
- 74x320: crystal-controlled oscillator.
- 74x321: crystal-controlled oscillators, F/2 and F/4 count-down outputs.
- 74x324: voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs.
- 74x325: dual voltage-controlled oscillator (or crystal controlled), complementary outputs.
- 74x326: dual voltage-controlled oscillator (or crystal controlled), enable input, complementary outputs.
- 74x327: dual voltage-controlled oscillator (or crystal controlled).
- 74x422: retriggerable monostable multivibrators, two inputs.
- 74x423: dual retriggerable monostable multivibrator.
- 74424: dual voltage-controlled oscillator.
- 74x462: fiber-optic data-link transmitter.
- 74x463: fiber-optic data-link receiver.
- 74x500: 6-bit flash analog-to-digital converter (ADC).
- 74x505: 8-bit successive approximation ADC.
- 74x624: voltage-controlled oscillator, enable control, range control, two-phase outputs.
- 74x625: dual voltage-controlled oscillator, two-phase outputs.
- 74x626: dual voltage-controlled oscillator, enable control, two-phase outputs.
- 74x627: dual voltage-controlled oscillator.
- 74x628: voltage-controlled oscillator, enable control, range control, external temperature compensation, two-phase outputs.
- 74x629: dual voltage-controlled oscillator, enable control, range control.
- 74x724: voltage-controlled multivibrator.
- 74x909: quad voltage comparator.
- 74934: ADC similar to ADC0829, see corresponding NSC datasheet.
- 74x935: ADC for 3.5-digit digital voltmeters, multiplexed 7-segment display outputs.
- 74x936: ADC for 3.75-digit digital voltmeters, multiplexed 7-segment display outputs.
- 74x937: ADC for 3.5-digit digital voltmeters, multiplexed BCD outputs.
- 74x938: ADC for 3.75-digit digital voltmeters, multiplexed BCD outputs.
- 74x948: 8-bit ADC with 16-channel analog multiplexer.
- 74x949: 8-bit ADC with 8-channel analog multiplexer.
- 74x950: 8-bit ADC with 8-channel analog multiplexer and sample and hold.
- 74x2509: 9-output clock driver with PLL.
- 74x2510: 10-output clock driver with PLL.
- 74x3932: PLL-based clock driver.
- 74x4046: phase-locked loop and voltage-controlled oscillator.
- 74x4051: high-speed 8-channel analog multiplexer/demultiplexer.
- 74x4052: dual 4-channel analog multiplexer/demultiplexers.
- 74x4053: triple 2-channel analog multiplexer/demultiplexers.
- 74x4066: quad single-pole single-throw analog switch.
- 74x4067: 16-channel analog multiplexer/demultiplexer.
- 74x4316: quad analog switch.
- 74x4351: 8-channel analog multiplexer/demultiplexer with latch.
- 74x4352: dual 4-channel analog multiplexer/demultiplexer with latch.
- 74x4353: triple 2-channel analog multiplexer/demultiplexer with latch.
- 74x4538: dual retriggerable precision monostable multivibrator.
- 74x4851: 8-channel analog multiplexer/demultiplexer.
- 74x4852: dual 4-channel analog multiplexer/demultiplexer.
- 74x5300: fiber optic LED driver.
- 74x5302: dual fiber optic LED / clock driver.
- 74x7046: phase-locked loop with voltage-controlled oscillator and lock detector.
- 74x7132: quad adjustable comparator with output latches.
- 74x9046: PLL with band gap controlled VCO.
- 74x16222: 22-bit voltage clamp.

## Implemented-subset results

| Module | Lint | Sim | Synthesis | Synthesis level |
|---|---|---|---|---|
| [ttl_74x00](../spec/chips/ttl_74x00.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x01](../spec/chips/ttl_74x01.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x02](../spec/chips/ttl_74x02.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x03](../spec/chips/ttl_74x03.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x04](../spec/chips/ttl_74x04.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x05](../spec/chips/ttl_74x05.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x06](../spec/chips/ttl_74x06.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x07](../spec/chips/ttl_74x07.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x08](../spec/chips/ttl_74x08.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x09](../spec/chips/ttl_74x09.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x10](../spec/chips/ttl_74x10.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x11](../spec/chips/ttl_74x11.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x12](../spec/chips/ttl_74x12.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x13](../spec/chips/ttl_74x13.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x14](../spec/chips/ttl_74x14.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x15](../spec/chips/ttl_74x15.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16](../spec/chips/ttl_74x16.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x17](../spec/chips/ttl_74x17.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x18](../spec/chips/ttl_74x18.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x19](../spec/chips/ttl_74x19.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x20](../spec/chips/ttl_74x20.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x21](../spec/chips/ttl_74x21.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x22](../spec/chips/ttl_74x22.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x23](../spec/chips/ttl_74x23.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x24](../spec/chips/ttl_74x24.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x25](../spec/chips/ttl_74x25.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x26](../spec/chips/ttl_74x26.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x27](../spec/chips/ttl_74x27.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x28](../spec/chips/ttl_74x28.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29](../spec/chips/ttl_74x29.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x30](../spec/chips/ttl_74x30.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32](../spec/chips/ttl_74x32.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x33](../spec/chips/ttl_74x33.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x34](../spec/chips/ttl_74x34.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x35](../spec/chips/ttl_74x35.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x36](../spec/chips/ttl_74x36.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x37](../spec/chips/ttl_74x37.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x38](../spec/chips/ttl_74x38.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x39](../spec/chips/ttl_74x39.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x40](../spec/chips/ttl_74x40.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x41](../spec/chips/ttl_74x41.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x42](../spec/chips/ttl_74x42.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x43](../spec/chips/ttl_74x43.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x44](../spec/chips/ttl_74x44.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x45](../spec/chips/ttl_74x45.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x46](../spec/chips/ttl_74x46.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x47](../spec/chips/ttl_74x47.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x48](../spec/chips/ttl_74x48.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x49](../spec/chips/ttl_74x49.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x50](../spec/chips/ttl_74x50.md) | PASS | PASS | PASS | generic gates |
| [ttl_7451](../spec/chips/ttl_7451.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l51](../spec/chips/ttl_74l51.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x52](../spec/chips/ttl_74x52.md) | PASS | PASS | PASS | generic gates |
| [ttl_7453](../spec/chips/ttl_7453.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h53](../spec/chips/ttl_74h53.md) | PASS | PASS | PASS | generic gates |
| [ttl_7454](../spec/chips/ttl_7454.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h54](../spec/chips/ttl_74h54.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l54](../spec/chips/ttl_74l54.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x55](../spec/chips/ttl_74x55.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x56](../spec/chips/ttl_74x56.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x57](../spec/chips/ttl_74x57.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x58](../spec/chips/ttl_74x58.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x59](../spec/chips/ttl_74x59.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x60](../spec/chips/ttl_74x60.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x61](../spec/chips/ttl_74x61.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x62](../spec/chips/ttl_74x62.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x63](../spec/chips/ttl_74x63.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x64](../spec/chips/ttl_74x64.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x65](../spec/chips/ttl_74x65.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x67](../spec/chips/ttl_74x67.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l68](../spec/chips/ttl_74l68.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls68](../spec/chips/ttl_74ls68.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l69](../spec/chips/ttl_74l69.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls69](../spec/chips/ttl_74ls69.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x70](../spec/chips/ttl_74x70.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h71](../spec/chips/ttl_74h71.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l71](../spec/chips/ttl_74l71.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x72](../spec/chips/ttl_74x72.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x73](../spec/chips/ttl_74x73.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x74](../spec/chips/ttl_74x74.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x75](../spec/chips/ttl_74x75.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x76](../spec/chips/ttl_74x76.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x77](../spec/chips/ttl_74x77.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h78](../spec/chips/ttl_74h78.md) | PASS | PASS | PASS | generic gates |
| [ttl_74l78](../spec/chips/ttl_74l78.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls78](../spec/chips/ttl_74ls78.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x79](../spec/chips/ttl_74x79.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x80](../spec/chips/ttl_74x80.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x81](../spec/chips/ttl_74x81.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x82](../spec/chips/ttl_74x82.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x83](../spec/chips/ttl_74x83.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x84](../spec/chips/ttl_74x84.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x85](../spec/chips/ttl_74x85.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x86](../spec/chips/ttl_74x86.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x87](../spec/chips/ttl_74x87.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x88](../spec/chips/ttl_74x88.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x89](../spec/chips/ttl_74x89.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x90](../spec/chips/ttl_74x90.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x91](../spec/chips/ttl_74x91.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x92](../spec/chips/ttl_74x92.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x93](../spec/chips/ttl_74x93.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x94](../spec/chips/ttl_74x94.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x95](../spec/chips/ttl_74x95.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x96](../spec/chips/ttl_74x96.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x97](../spec/chips/ttl_74x97.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x98](../spec/chips/ttl_74x98.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x99](../spec/chips/ttl_74x99.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x100](../spec/chips/ttl_74x100.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x101](../spec/chips/ttl_74x101.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x102](../spec/chips/ttl_74x102.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x103](../spec/chips/ttl_74x103.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x104](../spec/chips/ttl_74x104.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x105](../spec/chips/ttl_74x105.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x106](../spec/chips/ttl_74x106.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x107](../spec/chips/ttl_74x107.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x108](../spec/chips/ttl_74x108.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x109](../spec/chips/ttl_74x109.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x110](../spec/chips/ttl_74x110.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x111](../spec/chips/ttl_74x111.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x112](../spec/chips/ttl_74x112.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x113](../spec/chips/ttl_74x113.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x114](../spec/chips/ttl_74x114.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x115](../spec/chips/ttl_74x115.md) | PASS | PASS | PASS | generic gates |
| [ttl_74116](../spec/chips/ttl_74116.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h116](../spec/chips/ttl_74h116.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x117](../spec/chips/ttl_74x117.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x118](../spec/chips/ttl_74x118.md) | PASS | PASS | PASS | generic gates |
| [ttl_74119](../spec/chips/ttl_74119.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h119](../spec/chips/ttl_74h119.md) | PASS | PASS | PASS | generic gates |
| [ttl_74120](../spec/chips/ttl_74120.md) | PASS | PASS | PASS | generic gates |
| [ttl_74h120](../spec/chips/ttl_74h120.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x125](../spec/chips/ttl_74x125.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x126](../spec/chips/ttl_74x126.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x128](../spec/chips/ttl_74x128.md) | PASS | PASS | PASS | generic gates |
| [ttl_74131](../spec/chips/ttl_74131.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x132](../spec/chips/ttl_74x132.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x133](../spec/chips/ttl_74x133.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x134](../spec/chips/ttl_74x134.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x135](../spec/chips/ttl_74x135.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x136](../spec/chips/ttl_74x136.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x137](../spec/chips/ttl_74x137.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x138](../spec/chips/ttl_74x138.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x139](../spec/chips/ttl_74x139.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x140](../spec/chips/ttl_74x140.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x141](../spec/chips/ttl_74x141.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x142](../spec/chips/ttl_74x142.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x143](../spec/chips/ttl_74x143.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x144](../spec/chips/ttl_74x144.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x145](../spec/chips/ttl_74x145.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x146](../spec/chips/ttl_74x146.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x147](../spec/chips/ttl_74x147.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x148](../spec/chips/ttl_74x148.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x149](../spec/chips/ttl_74x149.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x150](../spec/chips/ttl_74x150.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x151](../spec/chips/ttl_74x151.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x152](../spec/chips/ttl_74x152.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x153](../spec/chips/ttl_74x153.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x154](../spec/chips/ttl_74x154.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x155](../spec/chips/ttl_74x155.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x156](../spec/chips/ttl_74x156.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x157](../spec/chips/ttl_74x157.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x158](../spec/chips/ttl_74x158.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x159](../spec/chips/ttl_74x159.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x160](../spec/chips/ttl_74x160.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x161](../spec/chips/ttl_74x161.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162](../spec/chips/ttl_74x162.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x163](../spec/chips/ttl_74x163.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x164](../spec/chips/ttl_74x164.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x165](../spec/chips/ttl_74x165.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x166](../spec/chips/ttl_74x166.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x167](../spec/chips/ttl_74x167.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x168](../spec/chips/ttl_74x168.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x169](../spec/chips/ttl_74x169.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x170](../spec/chips/ttl_74x170.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x171](../spec/chips/ttl_74x171.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x172](../spec/chips/ttl_74x172.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x173](../spec/chips/ttl_74x173.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x174](../spec/chips/ttl_74x174.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x175](../spec/chips/ttl_74x175.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x176](../spec/chips/ttl_74x176.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x177](../spec/chips/ttl_74x177.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x178](../spec/chips/ttl_74x178.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x179](../spec/chips/ttl_74x179.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x180](../spec/chips/ttl_74x180.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x181](../spec/chips/ttl_74x181.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x182](../spec/chips/ttl_74x182.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x183](../spec/chips/ttl_74x183.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x184](../spec/chips/ttl_74x184.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x185](../spec/chips/ttl_74x185.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x186](../spec/chips/ttl_74x186.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x187](../spec/chips/ttl_74x187.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x188](../spec/chips/ttl_74x188.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x189](../spec/chips/ttl_74x189.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x190](../spec/chips/ttl_74x190.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x191](../spec/chips/ttl_74x191.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x192](../spec/chips/ttl_74x192.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x193](../spec/chips/ttl_74x193.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x194](../spec/chips/ttl_74x194.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x195](../spec/chips/ttl_74x195.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x196](../spec/chips/ttl_74x196.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x197](../spec/chips/ttl_74x197.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x198](../spec/chips/ttl_74x198.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x199](../spec/chips/ttl_74x199.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x200](../spec/chips/ttl_74x200.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x201](../spec/chips/ttl_74x201.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x202](../spec/chips/ttl_74x202.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x206](../spec/chips/ttl_74x206.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x207](../spec/chips/ttl_74x207.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x208](../spec/chips/ttl_74x208.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x209](../spec/chips/ttl_74x209.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x210](../spec/chips/ttl_74x210.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x211](../spec/chips/ttl_74x211.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x212](../spec/chips/ttl_74x212.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x213](../spec/chips/ttl_74x213.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x214](../spec/chips/ttl_74x214.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x215](../spec/chips/ttl_74x215.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x216](../spec/chips/ttl_74x216.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x217](../spec/chips/ttl_74x217.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x218](../spec/chips/ttl_74x218.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x219](../spec/chips/ttl_74x219.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x222](../spec/chips/ttl_74x222.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x224](../spec/chips/ttl_74x224.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x225](../spec/chips/ttl_74x225.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x226](../spec/chips/ttl_74x226.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x227](../spec/chips/ttl_74x227.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x228](../spec/chips/ttl_74x228.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x229](../spec/chips/ttl_74x229.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x230](../spec/chips/ttl_74x230.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x231](../spec/chips/ttl_74x231.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x232](../spec/chips/ttl_74x232.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x233](../spec/chips/ttl_74x233.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x234](../spec/chips/ttl_74x234.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x235](../spec/chips/ttl_74x235.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x236](../spec/chips/ttl_74x236.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x237](../spec/chips/ttl_74x237.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x238](../spec/chips/ttl_74x238.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x239](../spec/chips/ttl_74x239.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x240](../spec/chips/ttl_74x240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x241](../spec/chips/ttl_74x241.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x242](../spec/chips/ttl_74x242.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x243](../spec/chips/ttl_74x243.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x244](../spec/chips/ttl_74x244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x245](../spec/chips/ttl_74x245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x246](../spec/chips/ttl_74x246.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x247](../spec/chips/ttl_74x247.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x248](../spec/chips/ttl_74x248.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x249](../spec/chips/ttl_74x249.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x250](../spec/chips/ttl_74x250.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x251](../spec/chips/ttl_74x251.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x253](../spec/chips/ttl_74x253.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x255](../spec/chips/ttl_74x255.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x256](../spec/chips/ttl_74x256.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x257](../spec/chips/ttl_74x257.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x258](../spec/chips/ttl_74x258.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x259](../spec/chips/ttl_74x259.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x260](../spec/chips/ttl_74x260.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x261](../spec/chips/ttl_74x261.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x262](../spec/chips/ttl_74x262.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x264](../spec/chips/ttl_74x264.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x265](../spec/chips/ttl_74x265.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x266](../spec/chips/ttl_74x266.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x268](../spec/chips/ttl_74x268.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x269](../spec/chips/ttl_74x269.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x270](../spec/chips/ttl_74x270.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x271](../spec/chips/ttl_74x271.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x273](../spec/chips/ttl_74x273.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x274](../spec/chips/ttl_74x274.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x275](../spec/chips/ttl_74x275.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x276](../spec/chips/ttl_74x276.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x278](../spec/chips/ttl_74x278.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x279](../spec/chips/ttl_74x279.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x280](../spec/chips/ttl_74x280.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x281](../spec/chips/ttl_74x281.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x282](../spec/chips/ttl_74x282.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x283](../spec/chips/ttl_74x283.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x284](../spec/chips/ttl_74x284.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x285](../spec/chips/ttl_74x285.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x286](../spec/chips/ttl_74x286.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x287](../spec/chips/ttl_74x287.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x288](../spec/chips/ttl_74x288.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x289](../spec/chips/ttl_74x289.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x290](../spec/chips/ttl_74x290.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x292](../spec/chips/ttl_74x292.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x293](../spec/chips/ttl_74x293.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x294](../spec/chips/ttl_74x294.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x295](../spec/chips/ttl_74x295.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x297](../spec/chips/ttl_74x297.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x298](../spec/chips/ttl_74x298.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x299](../spec/chips/ttl_74x299.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x300](../spec/chips/ttl_74x300.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x301](../spec/chips/ttl_74x301.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x302](../spec/chips/ttl_74x302.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x303](../spec/chips/ttl_74x303.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x304](../spec/chips/ttl_74x304.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x305](../spec/chips/ttl_74x305.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x306](../spec/chips/ttl_74x306.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x309](../spec/chips/ttl_74x309.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x310](../spec/chips/ttl_74x310.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x311](../spec/chips/ttl_74x311.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x312](../spec/chips/ttl_74x312.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x313](../spec/chips/ttl_74x313.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x314](../spec/chips/ttl_74x314.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x315](../spec/chips/ttl_74x315.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x316](../spec/chips/ttl_74x316.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x317](../spec/chips/ttl_74x317.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x318](../spec/chips/ttl_74x318.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x319](../spec/chips/ttl_74x319.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x322](../spec/chips/ttl_74x322.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x323](../spec/chips/ttl_74x323.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x330](../spec/chips/ttl_74x330.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x331](../spec/chips/ttl_74x331.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x333](../spec/chips/ttl_74x333.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x334](../spec/chips/ttl_74x334.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x335](../spec/chips/ttl_74x335.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x336](../spec/chips/ttl_74x336.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x337](../spec/chips/ttl_74x337.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x340](../spec/chips/ttl_74x340.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x341](../spec/chips/ttl_74x341.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x344](../spec/chips/ttl_74x344.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x347](../spec/chips/ttl_74x347.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x348](../spec/chips/ttl_74x348.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x350](../spec/chips/ttl_74x350.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x351](../spec/chips/ttl_74x351.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x352](../spec/chips/ttl_74x352.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x353](../spec/chips/ttl_74x353.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x354](../spec/chips/ttl_74x354.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x355](../spec/chips/ttl_74x355.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x356](../spec/chips/ttl_74x356.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x357](../spec/chips/ttl_74x357.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x362](../spec/chips/ttl_74x362.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x363](../spec/chips/ttl_74x363.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x364](../spec/chips/ttl_74x364.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x365](../spec/chips/ttl_74x365.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x366](../spec/chips/ttl_74x366.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x367](../spec/chips/ttl_74x367.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x368](../spec/chips/ttl_74x368.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x370](../spec/chips/ttl_74x370.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x371](../spec/chips/ttl_74x371.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x373](../spec/chips/ttl_74x373.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x374](../spec/chips/ttl_74x374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x375](../spec/chips/ttl_74x375.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x376](../spec/chips/ttl_74x376.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x377](../spec/chips/ttl_74x377.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x378](../spec/chips/ttl_74x378.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x379](../spec/chips/ttl_74x379.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x380](../spec/chips/ttl_74x380.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x381](../spec/chips/ttl_74x381.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x382](../spec/chips/ttl_74x382.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x383](../spec/chips/ttl_74x383.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x384](../spec/chips/ttl_74x384.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x385](../spec/chips/ttl_74x385.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x386](../spec/chips/ttl_74x386.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x387](../spec/chips/ttl_74x387.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x388](../spec/chips/ttl_74x388.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x390](../spec/chips/ttl_74x390.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x393](../spec/chips/ttl_74x393.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x395](../spec/chips/ttl_74x395.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x396](../spec/chips/ttl_74x396.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x398](../spec/chips/ttl_74x398.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x399](../spec/chips/ttl_74x399.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x401](../spec/chips/ttl_74x401.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x402](../spec/chips/ttl_74x402.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x403](../spec/chips/ttl_74x403.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x405](../spec/chips/ttl_74x405.md) | PASS | PASS | PASS | generic gates |
| [ttl_74406](../spec/chips/ttl_74406.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x407](../spec/chips/ttl_74x407.md) | PASS | PASS | PASS | generic gates |
| [ttl_74408](../spec/chips/ttl_74408.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x409](../spec/chips/ttl_74x409.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x410](../spec/chips/ttl_74x410.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x411](../spec/chips/ttl_74x411.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x412](../spec/chips/ttl_74x412.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x413](../spec/chips/ttl_74x413.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x414](../spec/chips/ttl_74x414.md) | PASS | PASS | PASS | generic gates |
| [ttl_74416](../spec/chips/ttl_74416.md) | PASS | PASS | PASS | generic gates |
| [ttl_74s416](../spec/chips/ttl_74s416.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x417](../spec/chips/ttl_74x417.md) | PASS | PASS | PASS | generic gates |
| [ttl_74418](../spec/chips/ttl_74418.md) | PASS | PASS | PASS | generic gates |
| [ttl_74419](../spec/chips/ttl_74419.md) | PASS | PASS | PASS | generic gates |
| [ttl_74s419](../spec/chips/ttl_74s419.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x420](../spec/chips/ttl_74x420.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls424](../spec/chips/ttl_74ls424.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x425](../spec/chips/ttl_74x425.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x426](../spec/chips/ttl_74x426.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x428](../spec/chips/ttl_74x428.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x429](../spec/chips/ttl_74x429.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x432](../spec/chips/ttl_74x432.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x433](../spec/chips/ttl_74x433.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x436](../spec/chips/ttl_74x436.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x437](../spec/chips/ttl_74x437.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x438](../spec/chips/ttl_74x438.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x440](../spec/chips/ttl_74x440.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x441](../spec/chips/ttl_74x441.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x442](../spec/chips/ttl_74x442.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x443](../spec/chips/ttl_74x443.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x444](../spec/chips/ttl_74x444.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x445](../spec/chips/ttl_74x445.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x446](../spec/chips/ttl_74x446.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x447](../spec/chips/ttl_74x447.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x448](../spec/chips/ttl_74x448.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x449](../spec/chips/ttl_74x449.md) | PASS | PASS | PASS | generic gates |
| [ttl_74450](../spec/chips/ttl_74450.md) | PASS | PASS | PASS | generic gates |
| [ttl_74s450](../spec/chips/ttl_74s450.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74ls450](../spec/chips/ttl_74ls450.md) | PASS | PASS | PASS | generic gates |
| [ttl_74s451](../spec/chips/ttl_74s451.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74ls451](../spec/chips/ttl_74ls451.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x452](../spec/chips/ttl_74x452.md) | PASS | PASS | PASS | generic gates |
| [ttl_74453](../spec/chips/ttl_74453.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls453](../spec/chips/ttl_74ls453.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x454](../spec/chips/ttl_74x454.md) | PASS | PASS | PASS | generic gates |
| [ttl_74455](../spec/chips/ttl_74455.md) | PASS | PASS | PASS | generic gates |
| [ttl_74456](../spec/chips/ttl_74456.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x458](../spec/chips/ttl_74x458.md) | PASS | PASS | PASS | generic gates |
| [ttl_74460](../spec/chips/ttl_74460.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls460](../spec/chips/ttl_74ls460.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x461](../spec/chips/ttl_74x461.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x465](../spec/chips/ttl_74x465.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x466](../spec/chips/ttl_74x466.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x467](../spec/chips/ttl_74x467.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x468](../spec/chips/ttl_74x468.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x469](../spec/chips/ttl_74x469.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x470](../spec/chips/ttl_74x470.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x471](../spec/chips/ttl_74x471.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x472](../spec/chips/ttl_74x472.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x473](../spec/chips/ttl_74x473.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x474](../spec/chips/ttl_74x474.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x475](../spec/chips/ttl_74x475.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x476](../spec/chips/ttl_74x476.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x477](../spec/chips/ttl_74x477.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x478](../spec/chips/ttl_74x478.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x479](../spec/chips/ttl_74x479.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x480](../spec/chips/ttl_74x480.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x481](../spec/chips/ttl_74x481.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x482](../spec/chips/ttl_74x482.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x484](../spec/chips/ttl_74x484.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x485](../spec/chips/ttl_74x485.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x488](../spec/chips/ttl_74x488.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x490](../spec/chips/ttl_74x490.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x491](../spec/chips/ttl_74x491.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x498](../spec/chips/ttl_74x498.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x502](../spec/chips/ttl_74x502.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x503](../spec/chips/ttl_74x503.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x504](../spec/chips/ttl_74x504.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x508](../spec/chips/ttl_74x508.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x515](../spec/chips/ttl_74x515.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x516](../spec/chips/ttl_74x516.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x518](../spec/chips/ttl_74x518.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x519](../spec/chips/ttl_74x519.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x520](../spec/chips/ttl_74x520.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x521](../spec/chips/ttl_74x521.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x522](../spec/chips/ttl_74x522.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x524](../spec/chips/ttl_74x524.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x525](../spec/chips/ttl_74x525.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x526](../spec/chips/ttl_74x526.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x527](../spec/chips/ttl_74x527.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x528](../spec/chips/ttl_74x528.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x531](../spec/chips/ttl_74x531.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x532](../spec/chips/ttl_74x532.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x533](../spec/chips/ttl_74x533.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x534](../spec/chips/ttl_74x534.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x535](../spec/chips/ttl_74x535.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x536](../spec/chips/ttl_74x536.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x537](../spec/chips/ttl_74x537.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x538](../spec/chips/ttl_74x538.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x539](../spec/chips/ttl_74x539.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x540](../spec/chips/ttl_74x540.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x541](../spec/chips/ttl_74x541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x543](../spec/chips/ttl_74x543.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x544](../spec/chips/ttl_74x544.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x545](../spec/chips/ttl_74x545.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x546](../spec/chips/ttl_74x546.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls547](../spec/chips/ttl_74ls547.md) | PASS | PASS | PASS | generic gates |
| [ttl_74ls548](../spec/chips/ttl_74ls548.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x549](../spec/chips/ttl_74x549.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x550](../spec/chips/ttl_74x550.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x551](../spec/chips/ttl_74x551.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x552](../spec/chips/ttl_74x552.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x556](../spec/chips/ttl_74x556.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x557](../spec/chips/ttl_74x557.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x558](../spec/chips/ttl_74x558.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x559](../spec/chips/ttl_74x559.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x560](../spec/chips/ttl_74x560.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x561](../spec/chips/ttl_74x561.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x563](../spec/chips/ttl_74x563.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x564](../spec/chips/ttl_74x564.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x566](../spec/chips/ttl_74x566.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x567](../spec/chips/ttl_74x567.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x568](../spec/chips/ttl_74x568.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x569](../spec/chips/ttl_74x569.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x570](../spec/chips/ttl_74x570.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x571](../spec/chips/ttl_74x571.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x572](../spec/chips/ttl_74x572.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x573](../spec/chips/ttl_74x573.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x574](../spec/chips/ttl_74x574.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x575](../spec/chips/ttl_74x575.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x576](../spec/chips/ttl_74x576.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x577](../spec/chips/ttl_74x577.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x579](../spec/chips/ttl_74x579.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x580](../spec/chips/ttl_74x580.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x582](../spec/chips/ttl_74x582.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x583](../spec/chips/ttl_74x583.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x588](../spec/chips/ttl_74x588.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x589](../spec/chips/ttl_74x589.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x590](../spec/chips/ttl_74x590.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x591](../spec/chips/ttl_74x591.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x592](../spec/chips/ttl_74x592.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x593](../spec/chips/ttl_74x593.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x594](../spec/chips/ttl_74x594.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x595](../spec/chips/ttl_74x595.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x596](../spec/chips/ttl_74x596.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x597](../spec/chips/ttl_74x597.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x598](../spec/chips/ttl_74x598.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x599](../spec/chips/ttl_74x599.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x600](../spec/chips/ttl_74x600.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x601](../spec/chips/ttl_74x601.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x602](../spec/chips/ttl_74x602.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x603](../spec/chips/ttl_74x603.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x604](../spec/chips/ttl_74x604.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x605](../spec/chips/ttl_74x605.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x606](../spec/chips/ttl_74x606.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x607](../spec/chips/ttl_74x607.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x608](../spec/chips/ttl_74x608.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x610](../spec/chips/ttl_74x610.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x611](../spec/chips/ttl_74x611.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x612](../spec/chips/ttl_74x612.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x613](../spec/chips/ttl_74x613.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x614](../spec/chips/ttl_74x614.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x615](../spec/chips/ttl_74x615.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x616](../spec/chips/ttl_74x616.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x617](../spec/chips/ttl_74x617.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x620](../spec/chips/ttl_74x620.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x621](../spec/chips/ttl_74x621.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x622](../spec/chips/ttl_74x622.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x623](../spec/chips/ttl_74x623.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x630](../spec/chips/ttl_74x630.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x631](../spec/chips/ttl_74x631.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x632](../spec/chips/ttl_74x632.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x633](../spec/chips/ttl_74x633.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x634](../spec/chips/ttl_74x634.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x635](../spec/chips/ttl_74x635.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x636](../spec/chips/ttl_74x636.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x637](../spec/chips/ttl_74x637.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x638](../spec/chips/ttl_74x638.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x639](../spec/chips/ttl_74x639.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x640](../spec/chips/ttl_74x640.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x641](../spec/chips/ttl_74x641.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x642](../spec/chips/ttl_74x642.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x643](../spec/chips/ttl_74x643.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x644](../spec/chips/ttl_74x644.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x645](../spec/chips/ttl_74x645.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x646](../spec/chips/ttl_74x646.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x647](../spec/chips/ttl_74x647.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x648](../spec/chips/ttl_74x648.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x649](../spec/chips/ttl_74x649.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x651](../spec/chips/ttl_74x651.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x652](../spec/chips/ttl_74x652.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x653](../spec/chips/ttl_74x653.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x654](../spec/chips/ttl_74x654.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x657](../spec/chips/ttl_74x657.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x666](../spec/chips/ttl_74x666.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x667](../spec/chips/ttl_74x667.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x668](../spec/chips/ttl_74x668.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x669](../spec/chips/ttl_74x669.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x670](../spec/chips/ttl_74x670.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x671](../spec/chips/ttl_74x671.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x672](../spec/chips/ttl_74x672.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x673](../spec/chips/ttl_74x673.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x674](../spec/chips/ttl_74x674.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x675](../spec/chips/ttl_74x675.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x676](../spec/chips/ttl_74x676.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x677](../spec/chips/ttl_74x677.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x678](../spec/chips/ttl_74x678.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x679](../spec/chips/ttl_74x679.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x680](../spec/chips/ttl_74x680.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x682](../spec/chips/ttl_74x682.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x683](../spec/chips/ttl_74x683.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x684](../spec/chips/ttl_74x684.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x685](../spec/chips/ttl_74x685.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x686](../spec/chips/ttl_74x686.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x687](../spec/chips/ttl_74x687.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x688](../spec/chips/ttl_74x688.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x689](../spec/chips/ttl_74x689.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x690](../spec/chips/ttl_74x690.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x691](../spec/chips/ttl_74x691.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x692](../spec/chips/ttl_74x692.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x693](../spec/chips/ttl_74x693.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x696](../spec/chips/ttl_74x696.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x697](../spec/chips/ttl_74x697.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x698](../spec/chips/ttl_74x698.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x699](../spec/chips/ttl_74x699.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x700](../spec/chips/ttl_74x700.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x708](../spec/chips/ttl_74x708.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x711](../spec/chips/ttl_74x711.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x712](../spec/chips/ttl_74x712.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x723](../spec/chips/ttl_74x723.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x725](../spec/chips/ttl_74x725.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x730](../spec/chips/ttl_74x730.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x731](../spec/chips/ttl_74x731.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x734](../spec/chips/ttl_74x734.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x740](../spec/chips/ttl_74x740.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x741](../spec/chips/ttl_74x741.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x742](../spec/chips/ttl_74x742.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x743](../spec/chips/ttl_74x743.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x744](../spec/chips/ttl_74x744.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x746](../spec/chips/ttl_74x746.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x747](../spec/chips/ttl_74x747.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x748](../spec/chips/ttl_74x748.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x756](../spec/chips/ttl_74x756.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x757](../spec/chips/ttl_74x757.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x760](../spec/chips/ttl_74x760.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x763](../spec/chips/ttl_74x763.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x795](../spec/chips/ttl_74x795.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x796](../spec/chips/ttl_74x796.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x797](../spec/chips/ttl_74x797.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x798](../spec/chips/ttl_74x798.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x800](../spec/chips/ttl_74x800.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x802](../spec/chips/ttl_74x802.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x803](../spec/chips/ttl_74x803.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x804](../spec/chips/ttl_74x804.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x805](../spec/chips/ttl_74x805.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x808](../spec/chips/ttl_74x808.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x810](../spec/chips/ttl_74x810.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x811](../spec/chips/ttl_74x811.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x821](../spec/chips/ttl_74x821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x822](../spec/chips/ttl_74x822.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x823](../spec/chips/ttl_74x823.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x824](../spec/chips/ttl_74x824.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x825](../spec/chips/ttl_74x825.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x826](../spec/chips/ttl_74x826.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x827](../spec/chips/ttl_74x827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x828](../spec/chips/ttl_74x828.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x832](../spec/chips/ttl_74x832.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x833](../spec/chips/ttl_74x833.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x834](../spec/chips/ttl_74x834.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x835](../spec/chips/ttl_74x835.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x841](../spec/chips/ttl_74x841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x842](../spec/chips/ttl_74x842.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x843](../spec/chips/ttl_74x843.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x844](../spec/chips/ttl_74x844.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x845](../spec/chips/ttl_74x845.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x846](../spec/chips/ttl_74x846.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x850](../spec/chips/ttl_74x850.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x851](../spec/chips/ttl_74x851.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x857](../spec/chips/ttl_74x857.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x861](../spec/chips/ttl_74x861.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x862](../spec/chips/ttl_74x862.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x863](../spec/chips/ttl_74x863.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x864](../spec/chips/ttl_74x864.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x866](../spec/chips/ttl_74x866.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x867](../spec/chips/ttl_74x867.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x869](../spec/chips/ttl_74x869.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x873](../spec/chips/ttl_74x873.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x874](../spec/chips/ttl_74x874.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x876](../spec/chips/ttl_74x876.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x878](../spec/chips/ttl_74x878.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x879](../spec/chips/ttl_74x879.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x880](../spec/chips/ttl_74x880.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x881](../spec/chips/ttl_74x881.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x882](../spec/chips/ttl_74x882.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x885](../spec/chips/ttl_74x885.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x900](../spec/chips/ttl_74x900.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x901](../spec/chips/ttl_74x901.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x904](../spec/chips/ttl_74x904.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x906](../spec/chips/ttl_74x906.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x907](../spec/chips/ttl_74x907.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x908](../spec/chips/ttl_74x908.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x910](../spec/chips/ttl_74x910.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x914](../spec/chips/ttl_74x914.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x915](../spec/chips/ttl_74x915.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x918](../spec/chips/ttl_74x918.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x920](../spec/chips/ttl_74x920.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x921](../spec/chips/ttl_74x921.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x929](../spec/chips/ttl_74x929.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x930](../spec/chips/ttl_74x930.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x933](../spec/chips/ttl_74x933.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x940](../spec/chips/ttl_74x940.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x941](../spec/chips/ttl_74x941.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x962](../spec/chips/ttl_74x962.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x963](../spec/chips/ttl_74x963.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x964](../spec/chips/ttl_74x964.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x968](../spec/chips/ttl_74x968.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x978](../spec/chips/ttl_74x978.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x979](../spec/chips/ttl_74x979.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x989](../spec/chips/ttl_74x989.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x990](../spec/chips/ttl_74x990.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x991](../spec/chips/ttl_74x991.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x992](../spec/chips/ttl_74x992.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x993](../spec/chips/ttl_74x993.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x994](../spec/chips/ttl_74x994.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x995](../spec/chips/ttl_74x995.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x996](../spec/chips/ttl_74x996.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1000](../spec/chips/ttl_74x1000.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1002](../spec/chips/ttl_74x1002.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1003](../spec/chips/ttl_74x1003.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1004](../spec/chips/ttl_74x1004.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1005](../spec/chips/ttl_74x1005.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1008](../spec/chips/ttl_74x1008.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1011](../spec/chips/ttl_74x1011.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1020](../spec/chips/ttl_74x1020.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1032](../spec/chips/ttl_74x1032.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1034](../spec/chips/ttl_74x1034.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1035](../spec/chips/ttl_74x1035.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1036](../spec/chips/ttl_74x1036.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1074](../spec/chips/ttl_74x1074.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1181](../spec/chips/ttl_74x1181.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1240](../spec/chips/ttl_74x1240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1241](../spec/chips/ttl_74x1241.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1242](../spec/chips/ttl_74x1242.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1243](../spec/chips/ttl_74x1243.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1244](../spec/chips/ttl_74x1244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1245](../spec/chips/ttl_74x1245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1280](../spec/chips/ttl_74x1280.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1403](../spec/chips/ttl_74x1403.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1604](../spec/chips/ttl_74x1604.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1638](../spec/chips/ttl_74x1638.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1639](../spec/chips/ttl_74x1639.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1640](../spec/chips/ttl_74x1640.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1641](../spec/chips/ttl_74x1641.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1642](../spec/chips/ttl_74x1642.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1643](../spec/chips/ttl_74x1643.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1644](../spec/chips/ttl_74x1644.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1760](../spec/chips/ttl_74x1760.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1762](../spec/chips/ttl_74x1762.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1779](../spec/chips/ttl_74x1779.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1803](../spec/chips/ttl_74x1803.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1804](../spec/chips/ttl_74x1804.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1805](../spec/chips/ttl_74x1805.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1808](../spec/chips/ttl_74x1808.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1821](../spec/chips/ttl_74x1821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1823](../spec/chips/ttl_74x1823.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1832](../spec/chips/ttl_74x1832.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1841](../spec/chips/ttl_74x1841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x1843](../spec/chips/ttl_74x1843.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2125](../spec/chips/ttl_74x2125.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2140](../spec/chips/ttl_74x2140.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2161](../spec/chips/ttl_74x2161.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2191](../spec/chips/ttl_74x2191.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2193](../spec/chips/ttl_74x2193.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2226](../spec/chips/ttl_74x2226.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2227](../spec/chips/ttl_74x2227.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2228](../spec/chips/ttl_74x2228.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2229](../spec/chips/ttl_74x2229.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2232](../spec/chips/ttl_74x2232.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2233](../spec/chips/ttl_74x2233.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2235](../spec/chips/ttl_74x2235.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2236](../spec/chips/ttl_74x2236.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2238](../spec/chips/ttl_74x2238.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2240](../spec/chips/ttl_74x2240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2241](../spec/chips/ttl_74x2241.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2242](../spec/chips/ttl_74x2242.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2243](../spec/chips/ttl_74x2243.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2244](../spec/chips/ttl_74x2244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2245](../spec/chips/ttl_74x2245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2253](../spec/chips/ttl_74x2253.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2257](../spec/chips/ttl_74x2257.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2273](../spec/chips/ttl_74x2273.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2299](../spec/chips/ttl_74x2299.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2373](../spec/chips/ttl_74x2373.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2374](../spec/chips/ttl_74x2374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2377](../spec/chips/ttl_74x2377.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2400](../spec/chips/ttl_74x2400.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2533](../spec/chips/ttl_74x2533.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2534](../spec/chips/ttl_74x2534.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2540](../spec/chips/ttl_74x2540.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2541](../spec/chips/ttl_74x2541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2543](../spec/chips/ttl_74x2543.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2544](../spec/chips/ttl_74x2544.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2573](../spec/chips/ttl_74x2573.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2574](../spec/chips/ttl_74x2574.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2623](../spec/chips/ttl_74x2623.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2640](../spec/chips/ttl_74x2640.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2643](../spec/chips/ttl_74x2643.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2645](../spec/chips/ttl_74x2645.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2646](../spec/chips/ttl_74x2646.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2648](../spec/chips/ttl_74x2648.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2651](../spec/chips/ttl_74x2651.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2652](../spec/chips/ttl_74x2652.md) | PASS | PASS | PASS | generic gates |
| [ttl_74s2708](../spec/chips/ttl_74s2708.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2725](../spec/chips/ttl_74x2725.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2726](../spec/chips/ttl_74x2726.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x2821](../spec/chips/ttl_74x2821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2823](../spec/chips/ttl_74x2823.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2825](../spec/chips/ttl_74x2825.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2827](../spec/chips/ttl_74x2827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2828](../spec/chips/ttl_74x2828.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2833](../spec/chips/ttl_74x2833.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2841](../spec/chips/ttl_74x2841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2843](../spec/chips/ttl_74x2843.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2845](../spec/chips/ttl_74x2845.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2853](../spec/chips/ttl_74x2853.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2861](../spec/chips/ttl_74x2861.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2862](../spec/chips/ttl_74x2862.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2863](../spec/chips/ttl_74x2863.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2864](../spec/chips/ttl_74x2864.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2952](../spec/chips/ttl_74x2952.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2953](../spec/chips/ttl_74x2953.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2961](../spec/chips/ttl_74x2961.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2962](../spec/chips/ttl_74x2962.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2967](../spec/chips/ttl_74x2967.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x2968](../spec/chips/ttl_74x2968.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3037](../spec/chips/ttl_74x3037.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3038](../spec/chips/ttl_74x3038.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3040](../spec/chips/ttl_74x3040.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3283](../spec/chips/ttl_74x3283.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3284](../spec/chips/ttl_74x3284.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3374](../spec/chips/ttl_74x3374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3573](../spec/chips/ttl_74x3573.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3574](../spec/chips/ttl_74x3574.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x3611](../spec/chips/ttl_74x3611.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3612](../spec/chips/ttl_74x3612.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3613](../spec/chips/ttl_74x3613.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3614](../spec/chips/ttl_74x3614.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3622](../spec/chips/ttl_74x3622.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3631](../spec/chips/ttl_74x3631.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3632](../spec/chips/ttl_74x3632.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3638](../spec/chips/ttl_74x3638.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3641](../spec/chips/ttl_74x3641.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3642](../spec/chips/ttl_74x3642.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3651](../spec/chips/ttl_74x3651.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3708](../spec/chips/ttl_74x3708.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x3827](../spec/chips/ttl_74x3827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4002](../spec/chips/ttl_74x4002.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4015](../spec/chips/ttl_74x4015.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4017](../spec/chips/ttl_74x4017.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4020](../spec/chips/ttl_74x4020.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4022](../spec/chips/ttl_74x4022.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4024](../spec/chips/ttl_74x4024.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4028](../spec/chips/ttl_74x4028.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4040](../spec/chips/ttl_74x4040.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4049](../spec/chips/ttl_74x4049.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4050](../spec/chips/ttl_74x4050.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4072](../spec/chips/ttl_74x4072.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4075](../spec/chips/ttl_74x4075.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4078](../spec/chips/ttl_74x4078.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4094](../spec/chips/ttl_74x4094.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4102](../spec/chips/ttl_74x4102.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4103](../spec/chips/ttl_74x4103.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4245](../spec/chips/ttl_74x4245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4301](../spec/chips/ttl_74x4301.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4302](../spec/chips/ttl_74x4302.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4303](../spec/chips/ttl_74x4303.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4304](../spec/chips/ttl_74x4304.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4305](../spec/chips/ttl_74x4305.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4306](../spec/chips/ttl_74x4306.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4374](../spec/chips/ttl_74x4374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4510](../spec/chips/ttl_74x4510.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4511](../spec/chips/ttl_74x4511.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4514](../spec/chips/ttl_74x4514.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4515](../spec/chips/ttl_74x4515.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4516](../spec/chips/ttl_74x4516.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4518](../spec/chips/ttl_74x4518.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4520](../spec/chips/ttl_74x4520.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4543](../spec/chips/ttl_74x4543.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4560](../spec/chips/ttl_74x4560.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x4724](../spec/chips/ttl_74x4724.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5074](../spec/chips/ttl_74x5074.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5245](../spec/chips/ttl_74x5245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5400](../spec/chips/ttl_74x5400.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5401](../spec/chips/ttl_74x5401.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5402](../spec/chips/ttl_74x5402.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5403](../spec/chips/ttl_74x5403.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x5620](../spec/chips/ttl_74x5620.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7001](../spec/chips/ttl_74x7001.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7002](../spec/chips/ttl_74x7002.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7003](../spec/chips/ttl_74x7003.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7006](../spec/chips/ttl_74x7006.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7007](../spec/chips/ttl_74x7007.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7008](../spec/chips/ttl_74x7008.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7014](../spec/chips/ttl_74x7014.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7022](../spec/chips/ttl_74x7022.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7030](../spec/chips/ttl_74x7030.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7032](../spec/chips/ttl_74x7032.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7038](../spec/chips/ttl_74x7038.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7074](../spec/chips/ttl_74x7074.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7075](../spec/chips/ttl_74x7075.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7076](../spec/chips/ttl_74x7076.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7080](../spec/chips/ttl_74x7080.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7200](../spec/chips/ttl_74x7200.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7201](../spec/chips/ttl_74x7201.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7202](../spec/chips/ttl_74x7202.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7203](../spec/chips/ttl_74x7203.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7205](../spec/chips/ttl_74x7205.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7206](../spec/chips/ttl_74x7206.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7240](../spec/chips/ttl_74x7240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7241](../spec/chips/ttl_74x7241.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7244](../spec/chips/ttl_74x7244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7245](../spec/chips/ttl_74x7245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7266](../spec/chips/ttl_74x7266.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7273](../spec/chips/ttl_74x7273.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7292](../spec/chips/ttl_74x7292.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7294](../spec/chips/ttl_74x7294.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7340](../spec/chips/ttl_74x7340.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7403](../spec/chips/ttl_74x7403.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7404](../spec/chips/ttl_74x7404.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7540](../spec/chips/ttl_74x7540.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7541](../spec/chips/ttl_74x7541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7597](../spec/chips/ttl_74x7597.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7623](../spec/chips/ttl_74x7623.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7640](../spec/chips/ttl_74x7640.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7643](../spec/chips/ttl_74x7643.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7645](../spec/chips/ttl_74x7645.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7731](../spec/chips/ttl_74x7731.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7793](../spec/chips/ttl_74x7793.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x7801](../spec/chips/ttl_74x7801.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7802](../spec/chips/ttl_74x7802.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7803](../spec/chips/ttl_74x7803.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7804](../spec/chips/ttl_74x7804.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7805](../spec/chips/ttl_74x7805.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7806](../spec/chips/ttl_74x7806.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7807](../spec/chips/ttl_74x7807.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7808](../spec/chips/ttl_74x7808.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7811](../spec/chips/ttl_74x7811.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7813](../spec/chips/ttl_74x7813.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7814](../spec/chips/ttl_74x7814.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7815](../spec/chips/ttl_74x7815.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7816](../spec/chips/ttl_74x7816.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7817](../spec/chips/ttl_74x7817.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7818](../spec/chips/ttl_74x7818.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7819](../spec/chips/ttl_74x7819.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7820](../spec/chips/ttl_74x7820.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7821](../spec/chips/ttl_74x7821.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7822](../spec/chips/ttl_74x7822.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7823](../spec/chips/ttl_74x7823.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7881](../spec/chips/ttl_74x7881.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7882](../spec/chips/ttl_74x7882.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x7884](../spec/chips/ttl_74x7884.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x8003](../spec/chips/ttl_74x8003.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8151](../spec/chips/ttl_74x8151.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8153](../spec/chips/ttl_74x8153.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8154](../spec/chips/ttl_74x8154.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8161](../spec/chips/ttl_74x8161.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8541](../spec/chips/ttl_74x8541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8838](../spec/chips/ttl_74x8838.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8960](../spec/chips/ttl_74x8960.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8961](../spec/chips/ttl_74x8961.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8962](../spec/chips/ttl_74x8962.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8963](../spec/chips/ttl_74x8963.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8965](../spec/chips/ttl_74x8965.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x8966](../spec/chips/ttl_74x8966.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9014](../spec/chips/ttl_74x9014.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9015](../spec/chips/ttl_74x9015.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9034](../spec/chips/ttl_74x9034.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9035](../spec/chips/ttl_74x9035.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9114](../spec/chips/ttl_74x9114.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9115](../spec/chips/ttl_74x9115.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9134](../spec/chips/ttl_74x9134.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9135](../spec/chips/ttl_74x9135.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9164](../spec/chips/ttl_74x9164.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9240](../spec/chips/ttl_74x9240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9244](../spec/chips/ttl_74x9244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9245](../spec/chips/ttl_74x9245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9541](../spec/chips/ttl_74x9541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x9595](../spec/chips/ttl_74x9595.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x40102](../spec/chips/ttl_74x40102.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x40103](../spec/chips/ttl_74x40103.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x40104](../spec/chips/ttl_74x40104.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x40105](../spec/chips/ttl_74x40105.md) | PASS | PASS | PASS | memory_inference |
| [ttl_74x16240](../spec/chips/ttl_74x16240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16244](../spec/chips/ttl_74x16244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16245](../spec/chips/ttl_74x16245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16373](../spec/chips/ttl_74x16373.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16374](../spec/chips/ttl_74x16374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16377](../spec/chips/ttl_74x16377.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16524](../spec/chips/ttl_74x16524.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16525](../spec/chips/ttl_74x16525.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16540](../spec/chips/ttl_74x16540.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16541](../spec/chips/ttl_74x16541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16543](../spec/chips/ttl_74x16543.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16620](../spec/chips/ttl_74x16620.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16623](../spec/chips/ttl_74x16623.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16640](../spec/chips/ttl_74x16640.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16721](../spec/chips/ttl_74x16721.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16722](../spec/chips/ttl_74x16722.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16820](../spec/chips/ttl_74x16820.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16821](../spec/chips/ttl_74x16821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16823](../spec/chips/ttl_74x16823.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16825](../spec/chips/ttl_74x16825.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16826](../spec/chips/ttl_74x16826.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16827](../spec/chips/ttl_74x16827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16828](../spec/chips/ttl_74x16828.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16841](../spec/chips/ttl_74x16841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16843](../spec/chips/ttl_74x16843.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16863](../spec/chips/ttl_74x16863.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x16973](../spec/chips/ttl_74x16973.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x161284](../spec/chips/ttl_74x161284.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162240](../spec/chips/ttl_74x162240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162241](../spec/chips/ttl_74x162241.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162244](../spec/chips/ttl_74x162244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162245](../spec/chips/ttl_74x162245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162373](../spec/chips/ttl_74x162373.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162374](../spec/chips/ttl_74x162374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162541](../spec/chips/ttl_74x162541.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162721](../spec/chips/ttl_74x162721.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162820](../spec/chips/ttl_74x162820.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162821](../spec/chips/ttl_74x162821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162823](../spec/chips/ttl_74x162823.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162825](../spec/chips/ttl_74x162825.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162827](../spec/chips/ttl_74x162827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x162841](../spec/chips/ttl_74x162841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x164245](../spec/chips/ttl_74x164245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x20245](../spec/chips/ttl_74x20245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x22501](../spec/chips/ttl_74x22501.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x25244](../spec/chips/ttl_74x25244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x25245](../spec/chips/ttl_74x25245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x25642](../spec/chips/ttl_74x25642.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29821](../spec/chips/ttl_74x29821.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29825](../spec/chips/ttl_74x29825.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29827](../spec/chips/ttl_74x29827.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29828](../spec/chips/ttl_74x29828.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29841](../spec/chips/ttl_74x29841.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29843](../spec/chips/ttl_74x29843.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29854](../spec/chips/ttl_74x29854.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29863](../spec/chips/ttl_74x29863.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x29864](../spec/chips/ttl_74x29864.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32240](../spec/chips/ttl_74x32240.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32244](../spec/chips/ttl_74x32244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32245](../spec/chips/ttl_74x32245.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32373](../spec/chips/ttl_74x32373.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32374](../spec/chips/ttl_74x32374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32501](../spec/chips/ttl_74x32501.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32543](../spec/chips/ttl_74x32543.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x32973](../spec/chips/ttl_74x32973.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x322244](../spec/chips/ttl_74x322244.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x322374](../spec/chips/ttl_74x322374.md) | PASS | PASS | PASS | generic gates |
| [ttl_74x324245](../spec/chips/ttl_74x324245.md) | PASS | PASS | PASS | generic gates |
