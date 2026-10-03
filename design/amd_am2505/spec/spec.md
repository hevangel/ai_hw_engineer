# Am2505 functional specification

## Original sources

AMD [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf):
datasheet pp. 2-9 to 2-14, especially operation table/user notes on 2-12;
manufacturer application note pp. 8-84 to 8-107, particularly Booth Table I
and circuit decomposition on 8-87, sign extension on 8-88, and the 8x4
array of Figure 8 on 8-89. The application note explicitly applies to
Am2505, Am25L05 and Am25S05 despite discussing the latter by name.

## Interface and boundary

Pure combinational 4x2 partial-product slice with four K addend bits,
carry-in/carry-out, overlap bits for wider arrays, and six sum bits. No
clock or reset. Fixed historical widths; electrical delay/voltage/loading
and floating-input electrical behavior are not modeled.

| Port | Physical inputs/outputs | Meaning |
|---|---|---|
| `x_i[3:0]` | X3-X0, pins 3-6 | Four multiplicand bits |
| `x_prev_i` | X-1, pin 7 | Adjacent lower bit, for the 2X shift |
| `x_sign_i` | X4, pin 1 | Repeat X3 when S4/S5 are used |
| `y_i[1:0]` | Y1-Y0, pins 21-22 | Booth pair |
| `y_prev_i` | Y-1, pin 23 | Adjacent lower multiplier bit |
| `k_i[3:0]` | K3-K0, pins 16-19 | Incoming partial product or constant |
| `cn_i` | Cn, pin 2 | Carry into the four-bit adder |
| `polarity_i` | P-bar, pin 20 | LOW: active-high operands; HIGH: active-low |
| `s_o[5:0]` | S5-S0, pins 15,14,11,10,9,8 | Sum/partial product |
| `cn4_o` | Cn+4, pin 13 | Carry to next slice; not S4 |

All X/Y/K/overlap/carry/sum pins denote physical voltage logic levels. For
active-low operation, normalize each with XOR P, perform the logical
operation, and encode outputs with XOR P. P itself is a control level.

## Booth operation

Let normalized bits be xm=X-1, x=X3..X0, xs=X4, ym=Y-1, y0=Y0, y1=Y1,
k=K3..K0, cin=Cn. Booth selection is:

| ym | y0 | y1 | Selected magnitude | Arithmetic operation with cin=y1 |
|---:|---:|---:|---|---|
| 0 | 0 | 0 | 0 | K |
| 1 | 0 | 0 | X | K+X |
| 0 | 1 | 0 | X | K+X |
| 1 | 1 | 0 | 2X | K+2X |
| 0 | 0 | 1 | 2X | K-2X |
| 1 | 0 | 1 | X | K-X |
| 0 | 1 | 1 | X | K-X |
| 1 | 1 | 1 | 0 | K |

The four-bit selected magnitude is X for 1X, `{X2,X1,X0,X-1}` for 2X,
or zero. The selected bits are complemented when y1=1, then added to K
and cin. **The chip does not internally add the two's-complement +1**:
the first slice's Cn must connect to Y1; later slices get Cn+4 from their
neighbor. Independent Cn levels are legal and affect the result.

Cn+4 is the unsigned carry out of that four-bit addition, interpreted in
the selected logic polarity. This remains distinct from the signed S4.
Even subtracting zero has complemented adder bits, making carry behavior
different from a generic signed multiplication's carry flag.

For the most significant slice, repeat the signs of both X and K twice.
For 1X the six-bit selected magnitude is `{xs,xs,x[3:0]}`. For 2X it is
`{xs,x[3:0],xm}`. For 0X it is zero. Complement by y1 and add
`{k[3],k[3],k}` plus cin, retaining six bits. **S4/S5 are specified for
the documented wiring xs=x[3]**. On interior slices where X4 is left
unconnected, use S0-S3 and Cn+4 only; no S4/S5 behavior is promised for
an invalid sign connection. The RTL explicitly computes X4 extension
but does not model an electrically floating TTL pin.

Standalone signed 4x2 multiplication: xm=ym=0, xs=X3, cin=Y1. Then the
signed six-bit sum is signed(X)*signed(Y)+signed(K). Wider Y requires the
overlap ym, not a fresh signed two-bit multiplication at every row.

## Assumption ledger

No undocumented valid-wiring binary behavior is assumed. The restriction
on sign outputs follows AMD's explicit X4 connection requirement. Timing
and floating inputs are excluded boundaries; they must not be silently
treated as initialized registers or logic zeros.
