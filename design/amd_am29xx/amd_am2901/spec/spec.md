# Am2901 processor-slice specification

Contract: Am2901A's documented digital behavior, from AMD's 1978 Am2900 Family
Data Book, printed 2-3 through 2-21 (PDF 11–29). The original Am2901 family
dates to 1975; this specification does not assert identical electrical timing
or package pinouts across revisions. Figures 2–4 (PDF 14) define all 512
microinstructions; Figure 8 (PDF 16) defines status outputs in **every** mode.

## Interface and storage

`cp_i` is the physical clock. `instruction_i[8:0]` is I8..I0;
`a_i`, `b_i` select the two RAM ports; `d_i[3:0]` is direct data;
`cn_i` is active-high carry in; `oe_n_i` is active-low Y output enable.
There are sixteen four-bit working registers and a four-bit Q register.
There is no reset or power-up initialization in the device.

The RAM read-port latches are transparent while CP is HIGH and retain their
values while CP is LOW. RAM writes are transparent while CP is LOW, always
to the currently selected B address. Q loads/shifts on CP's rising edge.
Control/data/address setup and hold requirements remain caller obligations;
the model has zero propagation delay and does not model analog races.

The Y and RAM0/RAM3/Q0/Q3 bidirectional pins are represented by separate data
and output-enable ports. Y is enabled exactly when OE is LOW. Disabled data
values have no electrical meaning; a board adapter resolves tri-state buses.
`zero_o` represents the open-collector F=0 release level: HIGH when F is zero,
LOW otherwise. Multiple slices combine it with a wired AND. `f3_o` and
`ovr_o` are active high; `p_n_o` and `g_n_o` are the physical active-low group
propagate/generate pins. Cn+4 is active high and defined even in logic modes.

## Instruction fields

I2..I0 selects (R,S): 0=(A,Q), 1=(A,B), 2=(0,Q), 3=(0,B),
4=(0,A), 5=(D,A), 6=(D,Q), 7=(D,0).
I5..I3 selects ADD, S−R, R−S, OR, AND, (~R)&S, XOR, XNOR respectively.
Subtraction adds the complemented subtrahend and Cn; Cn=1 is ordinary
two's-complement subtraction, Cn=0 subtracts one more. Arithmetic overflow
is carry into bit 3 XOR carry out. Logical status is Figure 8, not an invented
carry=0 shortcut. Its overbars must be read from the rendered original.

I8..I6 destinations:

| Code | RAM | Q | Y | Enabled shift outputs |
|---:|---|---|---|---|
| 0 | retain | F | F | none |
| 1 | retain | retain | F | none |
| 2 | F into B | retain | A | none |
| 3 | F into B | retain | F | none |
| 4 | F right into B, RAM3 input | Q right, Q3 input | F | RAM0=F0, Q0=old Q0 |
| 5 | F right into B, RAM3 input | retain | F | RAM0=F0 |
| 6 | F left into B, RAM0 input | Q left, Q0 input | F | RAM3=F3, Q3=old Q3 |
| 7 | F left into B, RAM0 input | retain | F | RAM3=F3 |

Q shifts use its previous contents, not F. RAM shifts use F. F status and Y
describe the unshifted result; destination 2 reports A while storing F.

## Independent verification and assumptions

The separately authored MIT Am2900ME emulator is pinned before RTL exists.
Its source remains immutable. It supplies operand/result, destination and
shift expectations for stable complete microcycles. Its arithmetic G and
some logic status equations require independent manufacturer-table checking;
the verification adapter explicitly records any disagreement instead of
silently declaring the emulator infallible. Native latch-phase tests are
separate because its two-step API does not model transparent phases.

The actual signed multiplication microprogram, dated August 5, 1975 by J.S.
in Figure 21 (PDF 29), will run through cascaded real RTL slices; exact
microstore positions and next executed words will be checked. Initialization
is performed through actual writes. This is the manufacturer's published
microprogram, rather than a newly invented arithmetic demonstration.

ASSUMPTION: timing-valid stable controls at a phase transition represent a
legal manufacturer cycle. Validate using the original microcode and dedicated
phase tests before sign-off. Validated by the 69,732 original-program product
runs and directed native-phase checks; the zero-delay fixture holds its
external Q3 shift value across the rising edge. No reset, undefined-state clearing, or analog
behavior is inferred. Results before software initialization are unspecified.

Sources: [1978 manufacturer book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf),
[Am2900ME source](https://github.com/MaisiKoleni/Am2900ME/tree/8cf4747cdf3bb2b434359ddc248f230f9f06f81d),
[manufacturer microprogram](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
