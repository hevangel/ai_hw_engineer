# AMD Am26xx family

Canonical issue: [hevangel/ai_hw_engineer#127](https://github.com/hevangel/ai_hw_engineer/issues/127).
One family folder; one native sub-issue and one member folder per documented
physical part. The Am26 series is AMD's line-driver, line-receiver, one-shot
and interface-logic family for serial and bus interconnection.

| Chip | Function | Member issue | Implementation |
| --- | --- | --- | --- |
| Am2600 | Single retriggerable monostable (dual active-low, three active-high trigger inputs, dual clear) | [#186](https://github.com/hevangel/ai_hw_engineer/issues/186) | [members/am2600](members/am2600/README.md) |
| Am2602 | Dual retriggerable resettable monostable | [#187](https://github.com/hevangel/ai_hw_engineer/issues/187) | [members/am2602](members/am2602/README.md) |
| Am2614 | Quad single-ended inverting line driver with pair strobes | [#188](https://github.com/hevangel/ai_hw_engineer/issues/188) | [members/am2614](members/am2614/README.md) |
| Am2615 | Dual differential line receiver with strobe and fail safe | [#189](https://github.com/hevangel/ai_hw_engineer/issues/189) | [members/am2615](members/am2615/README.md) |
| Am2616 | Quad MIL-188C / RS-232C line driver with inhibits | [#190](https://github.com/hevangel/ai_hw_engineer/issues/190) | [members/am2616](members/am2616/README.md) |
| Am2617 | Quad RS-232C line receiver | [#191](https://github.com/hevangel/ai_hw_engineer/issues/191) | [members/am2617](members/am2617/README.md) |
| Am26123 | Dual retriggerable resettable monostable (74123-compatible A/B trigger) | [#192](https://github.com/hevangel/ai_hw_engineer/issues/192) | [members/am26123](members/am26123/README.md) |
| Am26L02 | Low-power dual retriggerable resettable monostable | [#193](https://github.com/hevangel/ai_hw_engineer/issues/193) | [members/am26l02](members/am26l02/README.md) |
| Am26L123 | Low-power dual retriggerable resettable monostable (Am26123 function) | [#194](https://github.com/hevangel/ai_hw_engineer/issues/194) | [members/am26l123](members/am26l123/README.md) |
| Am26LS29 | Quad three-state RS-423 line driver | [#195](https://github.com/hevangel/ai_hw_engineer/issues/195) | [members/am26ls29](members/am26ls29/README.md) |
| Am26LS30 | Dual differential RS-422 / quad single-ended RS-423 line driver | [#196](https://github.com/hevangel/ai_hw_engineer/issues/196) | [members/am26ls30](members/am26ls30/README.md) |
| Am26LS31 | Quad differential RS-422 line driver | [#197](https://github.com/hevangel/ai_hw_engineer/issues/197) | [members/am26ls31](members/am26ls31/README.md) |
| Am26LS32 | Quad differential RS-422/RS-423 line receiver (±7 V, 200 mV) | [#198](https://github.com/hevangel/ai_hw_engineer/issues/198) | [members/am26ls32](members/am26ls32/README.md) |
| Am26LS33 | Quad differential line receiver (±15 V, 500 mV) | [#199](https://github.com/hevangel/ai_hw_engineer/issues/199) | [members/am26ls33](members/am26ls33/README.md) |
| Am26S02 | Schottky dual retriggerable resettable monostable | [#200](https://github.com/hevangel/ai_hw_engineer/issues/200) | [members/am26s02](members/am26s02/README.md) |
| Am26S10 | Quad open-collector bus transceiver, inverting driver | [#201](https://github.com/hevangel/ai_hw_engineer/issues/201) | [members/am26s10](members/am26s10/README.md) |
| Am26S11 | Quad open-collector bus transceiver, non-inverting driver | [#202](https://github.com/hevangel/ai_hw_engineer/issues/202) | [members/am26s11](members/am26s11/README.md) |
| Am26S12 | Quad open-collector bus transceiver, dual enable, 2.0/1.4 V receiver hysteresis | [#203](https://github.com/hevangel/ai_hw_engineer/issues/203) | [members/am26s12](members/am26s12/README.md) |
| Am26S12A | Same part with revised receiver hysteresis (2.25/1.2 V) | [#204](https://github.com/hevangel/ai_hw_engineer/issues/204) | [members/am26s12a](members/am26s12a/README.md) |

Am26S12 and Am26S12A are one documented part with two released hysteresis
grades, so they share the single source file
[members/am26s12/src/am26s12.sv](members/am26s12/src/am26s12.sv) with an
explicit revision selection and verify each contract separately, as the
parent issue requires. Every other member is a distinct part with its own
self-contained source, specification and verification flow.

## Sources

- [AMD 1974 Data Book](../../../references/1974_AMD_Data_Book.pdf)
  ([bitsavers copy](https://www.bitsavers.org/components/amd/_dataBooks/1974_AMD_Data_Book.pdf)):
  Am2600/9600/9601 (catalog pages 4-15 to 4-20), Am2602/9602 (4-21 to 4-26),
  Am26L02/96L02 (4-27 to 4-32), Am26S02 preliminary (4-33 to 4-38),
  Am26S12/26S12A (4-39 to 4-44), Am2614/9614 (4-45 to 4-50),
  Am2615/9615 (4-51 to 4-56), Am26123/Am54/74123 (4-87 to 4-92).
- [AMD 1979 Linear and Interface Data Book](../../../references/1979_AMD_Linear_and_Interface_Data_Book.pdf)
  ([bitsavers copy](https://www.bitsavers.org/components/amd/_dataBooks/1979_AMD_Linear_and_Interface_Data_Book.pdf)):
  Am26LS29 (pages 4-26 to 4-29), Am26LS30 (4-30 to 4-35), Am26LS31 (4-36 to
  4-39), Am26LS32/Am26LS33 (4-40 to 4-44 plus the quad-family RS-422/423
  application note 4-45 to 4-56), Am26S10/Am26S11 (4-57 to 4-61),
  Am26S12/26S12A (4-62 to 4-66), Am2614 (4-67 to 4-71), Am2615/9615 (4-72 to
  4-77), Am2616 (4-78 to 4-82), Am2617 (4-82 to 4-85), monostable selection
  guide (page 1-13) which defines the Am26L123 as the low-power Am26123.
- [AMD 1978 Schottky and Low-Power Schottky Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1978_AMD_Schottky_and_Low-Power_Schottky_Data_Book_including_Digital_Signal_Processing_Handbook_Second_Edition_197807.pdf):
  final (non-preliminary) Am26S02 data used to qualify the 26S02 contract;
  catalog pages 4-50 to 4-53.

The 1974 and 1979 books are committed as shared repository scans; member
specifications cite printed catalog pages and the PDF page ranges inside
them. Original manufacturer notices are retained in the scans.

## Digital abstraction

These parts are analog interface devices. Each member specification records
the digital abstraction contract that this repository implements and verify:
pin and polarity contract, boolean function (trigger networks, driver and
receiver equations, enables, strobes), retrigger/reset semantics, and the
three-state / open-collector bus behavior modeled as drive/release. External
RC networks, slew-rate capacitors, response-control capacitors, terminating
resistors, supply levels and propagation delays are electrical behavior and
are documented, not modeled. The monostables expose an explicit timing
reference clock (documented in each spec as an abstraction port, not a
device pin) and count the documented pulse width in clock cycles.

Historical dates, source qualifications and verification limits remain in
member READMEs and the [design index](../README.md).
