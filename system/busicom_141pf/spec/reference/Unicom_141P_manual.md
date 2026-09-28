# Unicom 141 Series: Operating Instructions

Source: [scanned manual](Unicom_141P_manual_text.pdf), Unicom Systems, Inc.,
Cupertino, California 95014; [Internet Archive](https://archive.org/details/Unicom141PManual).

This is a normalized Markdown extraction. The scan's operation tables have been
visually checked; graphical keys have explicit names. The original text-layer
extraction is preserved in [Unicom_141P_manual_ocr.md](Unicom_141P_manual_ocr.md),
including all original prose and OCR errors. Photographs and their layout remain
in the PDF. Printed page numbers are one less than PDF page numbers.

All 42 numbered examples are machine-readable in
[Unicom_141P_examples.json](Unicom_141P_examples.json). Expected values are decimal
strings, preserving trailing zeros, print symbols, rounding marks and red ink.
The tables below are regenerated from that file with `scripts/manual_markdown.py`.
They are expected behavior from the manual, not a claim that the simulator passes.

## Contents (printed page 1)

| Topic | Printed page |
|---|---:|
| Foreword | 2 |
| Specifications | 3 |
| Keyboard | 4 |
| Operating key functions | 5-7 |
| Changing recording paper roll | 8 |
| Changing print ribbon | 9 |
| 1. Addition/subtraction | 10-12 |
| 2. Multiplication | 13-15 |
| 3. Division | 16-17 |
| 4. Percentage calculation | 18 |
| 5. Mixed calculation | 19 |
| 6. Percentage distribution / reversed calculation | 20-21 |
| 7. Constant calculation with accumulation | 22 |
| 8. Divide proration | 23 |
| 9. Invoice calculation | 24 |
| 10. Application of memory and accumulator | 25 |
| 11. Square root | 26-28 |
| 12. Capacity of input buffer | 29 |
| 13. Capacity of number entry | 29 |
| 14. Capacity in addition/subtraction | 30 |
| 15. Capacity in multiplication | 31 |
| 16. Capacity in division | 32 |

## Foreword (printed page 2)

The 141 provides a printed record identifying each entry. Features include a
high-speed printer, 14-digit capacity, an input buffer, subtotal and main-total
accumulators, one memory, automatic constant calculation and rounding,
keyboard interlocks, and up to eight decimal places. Square root is available
only on the square-root model.

The original manual instructs the operator to ground the machine, leave the rear
vents uncovered, and avoid intense sunlight and nearby heaters. Switching power
off clears all figures, including memory. It states a one-year guarantee.

## Specifications (printed page 3)

| Item | Specification |
|---|---|
| Readout | Printer; 14 digits plus decimal point and symbols |
| Addition/subtraction | 0.45 seconds |
| Multiplication | 1.1 seconds |
| Division | 1.2 seconds |
| Input buffer | 8 words |
| Main element | MOS-LSI |
| Guaranteed temperature | +32 F to +104 F |
| Paper | 2-1/4 inches wide, 2-3/4 inches diameter |
| Power | AC 115 V +/-10%, 20 W |
| Dimensions | 8.3 inches W x 13.2 inches D x 5.1 inches H |
| Weight | 13 pounds |

Five working registers comprise one entry register, one subtotal register, one
main-total register and two multiplication/division registers. There is also one
memory. Multiplication/division produces its result in the entry register and
does not affect either accumulator.

## Keyboard and operating functions (printed pages 4-7)

| Key / control | Function | Printed symbol |
|---|---|---|
| C | Clear working registers and overflow | C |
| CE | Clear incorrect entry and overflow | none |
| 0-9, 00 | Numeral entry | digits |
| . | Decimal point | . |
| SIGN | Enter negative factors | negative values print red |
| - | Subtract from subtotal and main total | - |
| + | Add to subtotal and main total | + |
| / | Divide; chain division; keep second factor as constant divisor | divide |
| * | Multiply; chain multiplication; keep first factor as constant multiplicand | multiply |
| = | After + or -, print and clear main total; after multiply/divide, calculate and print result | = and/or total star |
| ST (diamond) | Print and clear subtotal after + or -; print a reference/date after numeral entry; print intermediate chain results | diamond or # |
| EX | Exchange multiplier/multiplicand or divisor/dividend | Ex |
| % | Percentage calculation | % and total star |
| CM | Print and clear memory | CM |
| RM | Recall and print memory without clearing | RM |
| M- | Subtract from memory | M- |
| M+ | Add to memory | M+ |
| M=- | Calculate product/quotient and subtract from memory | = then M- |
| M=+ | Calculate product/quotient and add to memory | = then M+ |
| SQRT | Square-root model only (examples 11-1 through 11-3) | root symbol |
| Decimal selector | 0, 1, 2, 3, 4, 5, 6, 8 places; no 7 position | - |
| Round switch | IN = truncate; FL = float; 5/4 = round | rounded-up arrow when applicable |
| Overflow lamp | Result exceeds capacity | - |
| Negative lamp | Entry/result is negative | - |
| Memory lamp | Amount is registered in memory | - |
| Paper feed | Advance paper tape | - |
| Power switch | Power on/off | - |

## Changing recording paper roll (printed page 8)

A red section indicates a low paper supply. Use standard tape 2-1/4 inches wide
and 2-3/4 inches in diameter.

1. Lift the back of the printing-section cover and remove it (figure 1).
2. Lift the paper guide; feed tape between the chrome plate and guide while pressing paper feed.
3. Insert tape into the guide slit while pressing paper feed (figure 2).
4. Press the guide until it clicks, tear off excess paper, and replace the cover (figure 3).

## Changing print ribbon (printed page 9)

Replace after 5-6 paper rolls. The specified nylon ribbon is 0.5 inches wide and
24 inches long (as printed).

1. Lift the back of the printing-section cover and remove it (figure 1).
2. Press the check lever behind each spool and pull the spools up (figure 2).
3. Insert supply and take-up spools, black half up, snapped onto the advance catches.
   Spring tension should hold the check levers against the ribbon (figure 3).
4. Replace the cover (figure 4).

## Notes accompanying the examples

- **Addition/subtraction (pages 10-12):** Set DP for the maximum entered decimal
  places. Press + or - after each amount. Repeat an amount by pressing the same
  operation key again. Addition/subtraction is independent of the round switch.
  The total key prints the answer and clears both accumulators. Example 1-2
  changes DP before totaling to round the result. Negative answers print red.
  ST clears only the subtotal; ST after number entry prints a reference number.
- **Multiplication (pages 13-15):** Fixed results use DP when rounding/truncating;
  FL uses the arithmetic decimal position. Intermediate chain products/quotients
  use floating precision. ST prints intermediate results. Multiplicands persist
  for constant calculations; EX changes which operand is held. Repeated = raises
  powers. Another multiply/divide key corrects the chosen operation.
- **Division (pages 16-17):** Enter chain operations in order. The divisor persists
  for repeated division. To retain a constant dividend, store it in memory and
  use RM and / before each new divisor. CM clears memory.
- **Percentage (page 18):** Multiplication by 2% acts as multiplication by .02.
  Percentage division scales the quotient to a percentage.
- **Mixed calculation (page 19):** Multiply/divide after addition/subtraction reads
  and clears main total and starts the requested operation. The formula in 5-1
  is `((1.5+129.05-11.08)*12.4/.55)/((12.96-3.56)*.87) = 329.36`.
- **Distribution (pages 20-21):** Add percentage results to the accumulator to prove
  100%. Products can also accumulate without using memory. Example 6-2 evaluates
  `3/((1.23*4)+(5.67*8))`, truncated to .05.
- **Constant accumulation (page 22):** M=+ and M=- accumulate products/quotients in
  memory. The negative term printed in the 7-1 formula denotes subtraction from
  memory; it does not mean entering a negative multiplier.
- **Proration (page 23):** The intermediate quotient becomes the constant
  multiplicand. M=+ accumulates the distributed amounts; CM checks their sum.
- **Invoice (page 24):** Items total 68.94; 10% discount is 6.89; discounted amount
  62.05; 5% tax 3.10; transport 2.50; final amount 67.65.
- **Memory and accumulator (page 25):** Quantities 10,20,15 total 45; corresponding
  products 23.80,27.60,54.75 total 106.15; average is 2.35 with truncation.
- **Square root (pages 26-28):** Square-root model only. Population deviation is
  `sqrt((n*sum(x*x)-sum(x)^2)/(n*n))`; values 2,3,4,5,6 give 1.414214.
  Pythagoras with sides 12 and 8 gives `sqrt(208) = 14.422205`.

## Capacity of input buffer and number entry (printed page 29, sections 12-13)

The eight-word input buffer scans the keyboard 40 times per second while
calculating or printing. Buffered functions execute sequentially when the prior
calculation completes. Number entry allows 14 digits plus decimal point and sign.
These sections contain no numbered worked example. Serial JSON replays exercise
arithmetic examples; they do not by themselves verify the buffer's timing/capacity.

## Capacity rules (printed pages 30-32, sections 14-16)

Accumulators and memory allow 14 digits plus decimal point and sign. Addition
and subtraction first align the entry to DP. On accumulator overflow, `CE + =`
recovers the old figure, demonstrated in 14-3.

Floating products and quotients, including intermediate fixed-mode calculations,
cannot exceed 14 integer digits. The constant operand is retained. For final
fixed-mode products/quotients, integer digits cannot exceed `14 - DP`. Overflow
prints a dotted line. Expected overflow is a tested outcome, not a failed example.

The scan appears to omit one zero from the formula for 15-3; its DP=8 tape table
and 14-digit description agree on `123456.00000000`, used below. Some print glyphs
are faint; explicit key names follow the control definitions and printed tape.

## Memo and back cover (printed page 33 and unnumbered back cover)

The memo page is blank. The back cover identifies Unicom Systems, Inc., Cupertino,
California 95014.

<!-- EXAMPLES: generated by scripts/manual_markdown.py -->

## Operation examples (printed pages 10-32)

Each table preserves the key order. Numeric entries are shown as individual keys.
Expected output lists the checked suffix at that step; a dash means no checkpoint,
not necessarily no printing. `*op` means multiplication, `*` means total,
`ST` means diamond/subtotal, `EX` means exchange, and `SQRT` means square root.
The JSON also contains independent setup keys (`CE C CM C`) to isolate replays.
These setup keys are not part of the manual examples.

### 1-1: Addition, subtraction and repeated addition

Printed page 10; PDF page 11. DP=3; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 4 +` | 12.340 + |
| `3 4 . 5 6 -` | 34.560 - |
| `5 6 . 7 8 9 +` | 56.789 + |
| `+` | 56.789 + |
| `. 1 2 3 +` | 0.123 + |
| `=` | 91.481 * |

### 1-2: Change decimal selector before totaling

Printed page 11; PDF page 12. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `1 . 2 3 +` | 1.23 + |
| `4 . 5 6 +` | 4.56 + |
| `Set precision=1` | - |
| `=` | 5.8 * (rounded up mark) |

### 1-3: Credit balance printed in red

Printed page 11; PDF page 12. DP=3; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 5 . 3 +` | 15.300 + |
| `5 6 . 7 8 9 -` | 56.789 - |
| `3 . 4 5 6 +` | 3.456 + |
| `=` | 38.033 * (red) |

### 1-4: Subtotals, grand total and non-add printing

Printed page 12; PDF page 13. DP=2; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 ST` | 1 # |
| `1 +` | 1.00 + |
| `2 +` | 2.00 + |
| `3 +` | 3.00 + |
| `ST` | 6.00 ST |
| `2 ST` | 2 # |
| `4 +` | 4.00 + |
| `5 +` | 5.00 + |
| `6 +` | 6.00 + |
| `ST` | 15.00 ST |
| `3 ST` | 3 # |
| `7 +` | 7.00 + |
| `8 +` | 8.00 + |
| `9 +` | 9.00 + |
| `ST` | 24.00 ST |
| `=` | 45.00 * |

### 2-1: Multiplication: FL

Printed page 13; PDF page 14. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 *` | 12.3 *op |
| `4 . 5 6 =` | 4.56 =; 56.088 * |

### 2-2: Multiplication: 5/4

Printed page 13; PDF page 14. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 *` | 12.3 *op |
| `4 . 5 6 =` | 4.56 =; 56.09 * (rounded up mark) |

### 2-3: Multiplication: IN

Printed page 13; PDF page 14. DP=2; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 *` | 12.3 *op |
| `4 . 5 6 =` | 4.56 =; 56.08 * |

### 2-4: Chain multiplication and intermediate print

Printed page 13; PDF page 14. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 *` | - |
| `4 . 5 6 *` | - |
| `ST` | 56.088 ST |
| `. 7 8 9 =` | 0.789 =; 44.253432 * |

### 2-5: Constant multiplicand

Printed page 14; PDF page 15. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `3 6 1 . 5 2 *` | - |
| `1 2 0 =` | 120 =; 43382.40 * |
| `1 1 8 . 6 =` | 118.6 =; 42876.272 * |
| `9 8 . 4 =` | 98.4 =; 35573.568 * |

### 2-6: Constant multiplier using exchange

Printed page 14; PDF page 15. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 . 2 5 *` | - |
| `1 2 EX` | 12 EX |
| `=` | 1.25 =; 15.00 * |
| `3 . 5 0 =` | 3.50 =; 42.00 * |
| `1 . 9 9 =` | 1.99 =; 23.88 * |

### 2-7: Raising five to the fourth power

Printed page 15; PDF page 16. DP=0; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `5 *` | - |
| `=` | 5 =; 25 * |
| `=` | 25 =; 125 * |
| `=` | 125 =; 625 * |

### 2-8: Correct function order

Printed page 15; PDF page 16. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 . 3 / * / *` | - |
| `4 . 5 6 =` | 4.56 =; 56.088 * |

### 3-1: Division: FL

Printed page 16; PDF page 17. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 /` | - |
| `6 =` | 6 =; 6.6666666666666 * |

**Editorial note (recovered ROM):** The scan prints one additional fractional digit; independent recovered-ROM execution prints 6.666666666666.

### 3-2: Division: 5/4

Printed page 16; PDF page 17. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 /` | - |
| `6 =` | 6 =; 6.67 * (rounded up mark) |

### 3-3: Division: IN

Printed page 16; PDF page 17. DP=2; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 /` | - |
| `6 =` | 6 =; 6.66 * |

### 3-4: Chain division

Printed page 16; PDF page 17. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 / 6 /` | - |
| `. 7 8 9 =` | 0.789 =; 25.98225602027 * |

### 3-5: Constant divisor

Printed page 17; PDF page 18. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `4 5 7 8 /` | - |
| `3 6 0 =` | 360 =; 12.72 * (rounded up mark) |
| `2 9 0 2 =` | 2902 =; 8.06 * |
| `8 7 1 6 =` | 8716 =; 24.21 * |

### 3-6: Constant dividend using memory

Printed page 17; PDF page 18. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 . 4 5 M+` | memory lamp: on |
| `/` | - |
| `3 6 . 9 =` | 36.9 =; 3.35 * (rounded up mark) |
| `RM` | 123.45 RM |
| `/` | - |
| `2 8 . 4 =` | 28.4 =; 4.35 * (rounded up mark) |
| `RM` | 123.45 RM |
| `/` | - |
| `3 1 . 5 5 =` | 31.55 =; 3.91 * |

### 4-1: Percentage multiplication

Printed page 18; PDF page 19. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 *` | - |
| `2 %` | 2 %; 246.90 * |

### 4-2: Percentage division

Printed page 18; PDF page 19. DP=2; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `2 /` | - |
| `3 %` | 3 %; 66.66666666666 * |

### 5-1: Mixed calculation with separately formed denominator

Printed page 19; PDF page 20. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `C 1 . 5 + 1 2 9 . 0 5 + 1 1 . 0 8 - *` | 119.47 *op |
| `1 2 . 4 / . 5 5 / 1 2 . 9 6 + 3 . 5 6 -` | - |
| `=` | 9.40 * |
| `/ 0 . 8 7 =` | 0.87 =; 329.36 * |

**Editorial note (recovered ROM):** The scan omits the rounding-up mark; the independent emulator prints it with 329.36.

### 6-1: Percentage distribution with 100 percent proof

Printed page 20; PDF page 21. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `C 1 2 3 / 1 2 3 + 4 5 6 + 7 8 9 +` | - |
| `=` | 1368.00 * |
| `%` | 1368.00 %; 8.99 * |
| `+` | 8.99 + |
| `4 5 6 %` | 456 %; 33.33 * |
| `+` | 33.33 + |
| `7 8 9 %` | 789 %; 57.68 * (rounded up mark) |
| `+` | 57.68 + |
| `=` | 100.00 * |

### 6-2: Reversed calculation

Printed page 21; PDF page 22. DP=2; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `C 1 . 2 3 * 4 =` | 4 =; 4.92 * |
| `+ 5 . 6 7 * 8 =` | 8 =; 45.36 * |
| `+ /` | 50.28 / |
| `3 EX` | 3 EX |
| `=` | 50.28 =; 0.05 * |

### 7-1: Constant multiplication with memory accumulation

Printed page 22; PDF page 23. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `CM 1 2 3 . 4 5 *` | - |
| `2 3 . 4 M=+` | 23.4 =; 2888.73 M+ |
| `4 2 . 6 M=-` | 42.6 =; 5258.97 M- |
| `5 1 M=+` | 51 =; 6295.95 M+ |
| `CM` | 3925.71 CM; memory lamp: off |

### 7-2: Constant division with memory accumulation

Printed page 22; PDF page 23. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `CM 4 5 7 8 /` | - |
| `3 6 0 M=+` | 360 =; 12.72 M+ (rounded up mark) |
| `2 9 0 2 M=+` | 2902 =; 8.06 M+ |
| `8 7 1 6 M=-` | 8716 =; 24.21 M- |
| `CM` | 3.43 CM (red); memory lamp: off |

### 8-1: Divide proration

Printed page 23; PDF page 24. DP=0; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `CM C 1 2 3 4 5 6 7 8 9 / 1 2 3 + 4 5 6 + 7 8 9 +` | - |
| `=` | 1368 * |
| `* 1 2 3 M=+` | 123 =; 11100281 M+ |
| `4 5 6 M=+` | 456 =; 41152263 M+ (rounded up mark) |
| `7 8 9 M=+` | 789 =; 71204245 M+ (rounded up mark) |
| `CM` | 123456789 CM |

### 9-1: Invoice, discount, sales tax and transport

Printed page 24; PDF page 25. DP=2; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `CM 1 1 * 1 . 2 3 M=+` | 1.23 =; 13.53 M+ |
| `1 2 * 4 . 1 1 M=+` | 4.11 =; 49.32 M+ |
| `3 * 2 . 0 3 M=+` | 2.03 =; 6.09 M+ |
| `RM` | 68.94 RM |
| `* 1 0 %` | 10 %; 6.89 * |
| `M- RM` | 62.05 RM |
| `* 5 %` | 5 %; 3.10 * |
| `M+ 2 . 5 0 M+ CM` | 67.65 CM |

### 10-1: Amount sold and average price

Printed page 25; PDF page 26. DP=2; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `CM C 1 0 M+ * 2 . 3 8 =` | 2.38 =; 23.80 * |
| `+ 2 0 M+ * 1 . 3 8 =` | 1.38 =; 27.60 * |
| `+ 1 5 M+ * 3 . 6 5 =` | 3.65 =; 54.75 * |
| `+ /` | 106.15 / |
| `CM` | 45.00 CM |
| `=` | 45.00 =; 2.35 * |

### 11-1: Square root

Printed page 26; PDF page 27. DP=2; FL (floating).

Square-root model only.

| Operation | Expected printed output / lamps |
|---|---|
| `1 5 2 4 1 7 5 4 3 . 0 6 2 5 SQRT` | 152417543.0625 SQRT; 12345.73 * |

**Editorial note (recovered ROM):** The scan prints 12345.73 with a total star. The exact square root is 12345.75; both independent emulator and RTL print 12345.750000000 with the square-root symbol.

### 11-2: Population standard deviation of 2,3,4,5,6

Printed page 26; PDF page 27. DP=6; 5/4 (round).

Square-root model only.

Continues on printed page 27 (PDF page 28).

| Operation | Expected printed output / lamps |
|---|---|
| `2 M+ * =` | 2.000000 =; 4.000000 * |
| `+` | - |
| `3 M+ * =` | 3.000000 =; 9.000000 * |
| `+` | - |
| `4 M+ * =` | 4.000000 =; 16.000000 * |
| `+` | - |
| `5 M+ * =` | 5.000000 =; 25.000000 * |
| `+` | - |
| `6 M+ * =` | 6.000000 =; 36.000000 * |
| `+` | - |
| `* 5 =` | 5 =; 450.000000 * |
| `+ CM * =` | 20.000000 =; 400.000000 * |
| `- / 5 =` | 5 =; 10.000000 * |
| `=` | 10.000000 =; 2.000000 * |
| `SQRT` | 2.000000 SQRT; 1.414214 * |

**Editorial note (recovered ROM):** Independent recovered-ROM execution prints the square-root symbol on the answer instead of the scanned total star.

### 11-3: Pythagorean theorem: sides 12 and 8

Printed page 28; PDF page 29. DP=6; 5/4 (round).

Square-root model only.

| Operation | Expected printed output / lamps |
|---|---|
| `C CM 1 2 * M=+` | 144.000000 M+ |
| `8 * M=+` | 8 =; 64.000000 M+ |
| `CM` | 208.000000 CM |
| `SQRT` | 208.000000 SQRT; 14.422205 * |

**Editorial note (recovered ROM):** Independent recovered-ROM execution prints the square-root symbol on the answer instead of the scanned total star.

### 14-1: Fourteen digit addition capacity

Printed page 30; PDF page 31. DP=6; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 7 8 +` | 12345678.000000 +; overflow lamp: off |

### 14-2: Entry alignment overflows addition capacity

Printed page 30; PDF page 31. DP=6; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 7 8 9 +` | dotted overflow line; overflow lamp: on |

### 14-3: Addition overflow and recovery

Printed page 30; PDF page 31. DP=8; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `9 0 0 0 0 0 +` | 900000.00000000 + |
| `1 0 0 0 0 0 +` | 100000.00000000 +; dotted overflow line; overflow lamp: on |
| `CE +` | 0.00000000 +; overflow lamp: off |
| `=` | 900000.00000000 * |

### 15-1: Capacity: within limit

Printed page 31; PDF page 32. DP=0; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 7 8 9 * 1 0 0 0 0 0 =` | 12345678900000 *; overflow lamp: off |

### 15-2: Capacity: overflow

Printed page 31; PDF page 32. DP=0; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 7 8 9 * 1 0 0 0 0 0 0 =` | dotted overflow line; overflow lamp: on |

### 15-3: Capacity: within limit

Printed page 31; PDF page 32. DP=8; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 * 1 =` | 123456.00000000 *; overflow lamp: off |

### 15-4: Capacity: overflow

Printed page 31; PDF page 32. DP=8; 5/4 (round).

| Operation | Expected printed output / lamps |
|---|---|
| `1 2 3 4 5 6 7 * 1 =` | dotted overflow line; overflow lamp: on |

### 16-1: Capacity: within limit

Printed page 32; PDF page 33. DP=0; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 0 0 0 0 0 / 0 . 0 0 0 0 0 0 3 =` | 13333333333333 *; overflow lamp: off |

### 16-2: Capacity: overflow

Printed page 32; PDF page 33. DP=0; FL (floating).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 0 0 0 0 0 0 / 0 . 0 0 0 0 0 0 3 =` | dotted overflow line; overflow lamp: on |

### 16-3: Capacity: within limit

Printed page 32; PDF page 33. DP=8; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 0 0 0 0 / 3 =` | 133333.33333333 *; overflow lamp: off |

### 16-4: Capacity: overflow

Printed page 32; PDF page 33. DP=8; IN (truncate).

| Operation | Expected printed output / lamps |
|---|---|
| `4 0 0 0 0 0 0 / 3 =` | dotted overflow line; overflow lamp: on |
