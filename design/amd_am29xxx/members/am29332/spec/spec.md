# Am29332 digital specification

Primary contract: AMD *Am29332 Instruction Manual* (1987, AMD doc 07995A,
190-page scan; SHA256s in `../references/README.md`). The manual's Chapter 1
gives the block/partition description, the instruction-set summary tables
(6-1 … 16) and the status-register map (Figure 3); Chapter 2 gives the
per-instruction detailed descriptions (124 defined opcodes); Appendix A gives
the BCD two-stage arithmetic rules with thirteen worked examples; Appendix B
gives the modified-Booth multiply and nonrestoring divide flow charts with a
one-byte unsigned multiply trace (65h × 48h = 1C68h) and a one-byte unsigned
divide trace (75h / 02h = 3Ah rem 01h). Supplemental contract: the Am29332
datasheet in the AMD 1988 *Am29C300/29300 Data Book* (PDF 162–170), whose
PIN DESCRIPTION section is the only signal-level definition of BOROW, RS,
HOLD, M/m, MCIN, MLINK, SLAVE, OE-Y and the parity pins.

A 32-bit non-cascadable bipolar ALU/shift register: two 32-bit input ports
(DA, DB), one 32-bit three-state output port (Y), a 9-bit instruction port
(I0–I8), 6-bit position (P0–P5) and 5-bit width (W0–W4) inputs, a clocked
32-bit status register and 32-bit Q register, byte even-parity check on A/B
and generate on Y, and a master/slave diagnostic mode with MSERR. The ALU
datapath is combinational (flow-through); the status and Q registers clock on
CP rising edges and are held when HOLD is HIGH. There is no reset pin: the
part powers up with the status and Q registers undefined and is initialized
by LDSTAT (the manual defines no power-up state).

## Instruction word

`instr[6:0]` = opcode (0x00–0x7F); opcodes 0x1E, 0x1F, 0x4C, 0x4D are not
defined (124 defined instructions). For FORMAT 1 (byte-aligned) instructions
`instr[8:7]` is the byte width: 00=4, 01=1, 10=2, 11=3 bytes. For FORMAT 2
(variable-field, N-bit shift, bit-manipulation and mask instructions)
`instr[8]` selects the position source (1 = STATUS<5:0> position register,
0 = P pins) and `instr[7]` selects the width source (1 = STATUS<12:8> width
register, 0 = W pins).

## Status register (Figure 3)

| Bits | Content |
| --- | --- |
| 7:0 | position register PR7–PR0 (PR5–PR0 used; PR7–PR6 readable/writable, unused) |
| 12:8 | width register WR4–WR0 |
| 13 | C+Z (borrow mode: !C+Z) — read-only, combinational |
| 14 | N XOR V — read-only, combinational |
| 15 | (N XOR V) OR Z — read-only, combinational |
| 16 | C carry/borrow |
| 17 | N negative |
| 18 | V overflow (V = carry into MSB XOR carry out of MSB, at the byte-width boundary) |
| 19 | Z zero (selected bytes only) |
| 20 | L link |
| 21 | M multiply/divide bit |
| 22 | S divide partial-remainder sign |
| 23 | always 0 |
| 31:24 | NC7–NC0 BCD nibble carry/borrow register |

STATUS<13:15> and bit 23 cannot be written (LDSTAT, SETBIT-STAT,
RSTBIT-STAT, PRIOR all leave them derived); bits 6–7 are writable and unused.

## General operand rules

- Byte-aligned two-operand instructions: unselected Y bytes pass the
  corresponding B bytes unaltered; single-operand instructions pass their
  source's unselected bytes; Z and N are defined over the selected bytes only
  (N = the selected-field sign bit of Y); C and V come from the adder at the
  byte-width boundary.
- Field instructions: width 0 means "entire field to the left of position"
  for p ≥ 0 (bits [p:31]) and the entire 32 bits for p < 0; a mask moved up
  over bit 31 is truncated (the bits above the word are ignored — "ONEs are
  inserted from the least significant end", i.e. no wraparound).
- Position as a 6-bit two's-complement value: positive = upshift 0..31,
  negative = downshift 1..32. Downshifted field sources rotate (ANDF/ORF/
  XORF/PASSF/NOTF-A, EXTF-A/B), N-bit shifts zero/sign-fill.

## Instruction classes (Y output / status contract)

- **Data movement (6-1/6-2/6-3):** ZERO-EXTA/B (00/01) pass the selected
  source bytes with zero high bytes; SIGN-EXTA/B (02/03) sign-fill;
  MERGEA-B/MERGEB-A (0E/0F) merge; PASS-STAT (04) and PASS-Q (05) pass the
  status register / Q register with B high bytes and update nothing;
  LOADQ-A/B (06/07) load the selected bytes into Q, Y = source with old-Q
  high bytes, Z/N per selected source bytes; LDSTAT-A/B (1C/1D) write the
  selected bytes of A/B into the status register (read-only bits protected)
  and output source/old-status.
- **Logical (Table 7):** NOT-A/B (08/09), ZERO (3C: selected zero bytes,
  Z always 1, N always 0), SIGN (3D: selected bytes = N ? -1 : 0, Z = !N),
  OR/XOR/AND/XNOR (3E/3F/40/41).
- **Arithmetic (10-1/10-2):** NEG-A/B (0A/0B), INCR/2/4-A and -B
  (12/16/1A, 13/17/1B), DECR/2/4-A and -B (10/14/18, 11/15/19), ADD (42),
  ADDC (43), SUB (44), SUBC (45), SUBR (46), SUBRC (47). C for the subtract
  class = adder carry-out XOR BOROW; the add class stores the raw carry
  (Appendix A: "borrow mode does not affect addition in any way"). ADDC/SUBC/
  SUBRC carry-in = M/m ? MCIN : status C, inverted into the adder for the
  subtract class when BOROW is HIGH (so the carry store is a borrow then).
  ADD/ADDC/INCR-class load the raw nibble carries into NC7–NC0;
  SUB/DECR/NEG-class store their complements (nibble borrows).
  SUM-CORR-A/B (48/49): correction word = 6 at each nibble whose NC is set,
  added to A (B); C = NC[2bw-1]; V = NC[2bw-1] XOR NC[2bw-2].
  DIFF-CORR-A/B (4A/4B): same correction subtracted; C = NC[2bw-1] XNOR
  BOROW; V = NC[2bw-1] XOR NC[2bw-2]. Nibble-carry rule (Appendix A): NCi =
  1 iff nibble sum ≥ 10, or nibble sum = 9 and NCi-1 = 1 and the binary
  carry out of nibble i-1 is 0.
- **Prioritize (Table 9):** PRIOR-A/B (0C/0D). Y = shift count bringing the
  selected-field MSB to the field sign position (Table 4; MSB-of-field active
  or all-zero field → 0); Y[31:8] = 0; Z per selected bytes; the count is
  also loaded into STATUS<7:0> (bits 7:5 forced 0). No other flags change.
- **Single-bit shifts (8-1/8-2):** DN1-0F/1F/LF/AR-A,-B (20/21/24/25/28/29/
  2C/2D), UP1-0F/1F/LF-A,-B (30/31/34/35/38/39) and the *Q double-precision
  variants (22/23/26/27/2A/2B/2E/2F, 32/33/36/37/3A/3B). Link fill =
  M/m ? MLINK : status L; sign fill = the source's selected sign bit.
  Downshifts: L ← source LSB (single) or Q LSB (double), N = Y sign (= fill),
  Z per selected Y. Upshifts: L ← source sign (single and double), the fill
  is 0/1/link, V = source sign XOR Y sign, N = Y sign, Z per selected Y.
  Double variants shift the selected Q bytes with the source LSB as fill
  (down) or with 0/1/link as fill and the old Q sign as the Y fill bit (up).
- **Multiply steps (Appendix B, flow charts B-1..B-5):** modified Booth,
  two bits/cycle, (w+2)-bit internal ALU (w = 8·bw). UMULFIRST (5B):
  B selected bytes internally zeroed, A* zero-extended; SMULFIRST (5F):
  A* sign-extended; F* per Q1Q0 of the pre-shift Q with implicit M=0
  (00→0, 01→+A*, 10→−2A*, 11→−A*). UMULSTEP (5C)/SMULSTEP (5E):
  A* zero/sign-extended, B* always sign-extended, F* per Q1Q0M =
  (000/111→B*, 001/010→B*+A*, 101/110→B*−A*, 011→B*+2A*, 100→B*−2A*).
  Y = F* downshifted 2 bits (the two extension bits fold into the selected
  field); unselected Y bytes = B. Q selected bytes downshift 2 with F*[1:0]
  as fill. M ← pre-shift Q1 (FIRST: also M ← pre-shift Q1). No other flags.
  UMULLAST (5D): if M = 1, selected bytes of Y = B + A, else Y = B; Z per
  selected bytes. (Trace-validated: 65h × 48h = 1C68h.)
- **Divide steps (Table 11-1, flow charts B-6/B-7).** Unsigned:
  UDIVFIRST (4F): Y = B<<1 | Q sign (selected bytes), L ← B sign,
  Q selected <<1 with 0 fill, M ← 1, S ← 0, Z/N per Y.
  UDIVSTEP (54): F = {S, B[w-1:0]} ± {0, A[w-1:0]} + carry-in over w+1 bits
  (M=1 subtract-with-carry, M=0 add-with-carry; carry-in = M/m ? MCIN :
  status C). Y = F[w-1:0]<<1 | pre-shift Q sign, unselected Y = B. The new
  quotient bit = complement of F[w] (the extended-result sign — ch2:
  "the complement of the sign of the (extended) result"); Q <<1 | quotient
  bit; M ← quotient bit; L ← S ← F[w-1] (sign of the w-bit remainder);
  C ← carry out of the extended add; Z/N per Y. Trace-validated end to end:
  75h / 02h → Q = 3Ah, remainder 01h, N = 1 after UDIVLAST.
  UDIVLAST (55): same F; Y = F (no upshift); Q <<1 | quotient bit; M ←
  quotient bit; S ← 0; C ← extended carry-out; N ← M ⊕ S ⊕ C evaluated with
  the pre-instruction M/S; Z per selected Y; L unchanged.
  Signed: SDIVFIRST (4E): Y = B<<1 | Q sign; L ← S ← B sign; Q <<1 with the
  quotient bit A[w-1] XNOR B[w-1]; M ← the quotient bit; Z/N per Y.
  SDIVSTEP (50): F = B ± A + carry-in over the selected bytes (M=1 subtract,
  M=0 add); Y = F<<1 | pre-shift Q sign; L ← F[w-1]; quotient bit = A[w-1]
  XNOR F[w-1]; Q <<1 | quotient bit; M ← quotient bit; C ← F carry-out;
  Z/N per Y. SDIVLAST1 (51): F = B ± A (no shift, no carry-in); Y = F;
  Q <<1 with a 1 fill; M ← F[w-1] XNOR A[w-1]; C ← F carry-out; Z/N per F.
  SDIVLAST2 (5A): divisor sign = Q's selected sign bit; F = divisor-sign ?
  B−A : B+A over selected bytes; Y = F (unselected = B); Z ← S ? (F = 0) : 0;
  no other flags.
  Multiprecision: MPDIVSTEP1 (52): full-word F = B ± A (no carry-in);
  C ← F carry-out; L ← F[31]; Y = F<<1 | Q sign (selected width); Q selected
  bytes <<1, zero fill; M unchanged; Z per selected Y. MPDIVSTEP2 (56):
  full-word F = B ± A + carry-in (macro/micro selected); Y = F<<1 | L;
  L ← F[31]; C ← carry-out; Z per selected Y. MPSDIVSTEP3 (53): selected-bytes
  F = B ± A + carry-in; Y = F<<1 | L (selected bytes); L ← F[w-1];
  quotient bit = A[w-1] XNOR F[w-1]; Q bit 0 ← quotient bit (Q not shifted);
  M ← quotient bit; C ← F carry-out; Z per selected Y. MPUDIVSTP3 (57):
  F = {S, B[w-1:0]} ± {0, A[w-1:0]} + carry-in over w+1 bits; Y =
  F[w-1:0]<<1 | L (selected bytes, unselected = B); L ← S ← F[w-1];
  quotient bit = M ⊕ S ⊕ C (ch2 formula, evaluated with the pre-instruction
  M and the instruction's carry-out C); Q bit 0 ← quotient bit; M ← quotient
  bit; C ← extended carry-out; Z per selected Y.
  Correction steps: REMCORR (58): F = M ? B−A : B+A over selected bytes
  (plain, no carry-in); Y = F (unselected = B); C ← F carry-out; nothing
  else. QUOCORR (59): F = B−1 (M=0) / B+1 (M=1) when Z⊕N⊕S = 1, else F = B;
  Y = F; C ← carry-out; V ← overflow; nothing else.
- **N-bit shifts/rotates (FORMAT 2, full word):** NB-SN-SHA/B (60/61):
  arithmetic shift by the signed position; NB-0F-SHA/B (62/63): logical
  shift (position −32 gives 0); NBROT-A/B (64/65): 5-bit unsigned rotate
  left; Z/N per the full result; no other flags; Q, status unchanged.
- **Bit manipulation (FORMAT 2):** EXTBIT-A/B (66/67): Y = {31'b0, src[pu]
  XOR p-sign}, L ← Y[0], Z = (Y = 0); SETBIT-A/B (68/69): Y = src | (1<<pu),
  Z always 0, N = Y31; RSTBIT-A/B (6A/6B): Y = src & ~(1<<pu), Z always 1,
  N = Y31 (pu = the 5-bit unsigned position). SETBIT-STAT (6C) /
  RSTBIT-STAT (6D): the status bit at pu is set/reset (read-only bits
  protected); Y = the new status value; no flags change.
  EXTBIT-STAT (7E): Y = {31'b0, STATUS[pu] XOR p-sign}, L ← Y[0],
  Z = (Y = 0), no other side effects.
- **Field logical (FORMAT 2):** non-aligned ANDF/ORF/XORF/PASSF/NOTF-A
  (78/74/76/72/70): p ≥ 0: A' = A << p, field at [p, p+w-1]; p < 0:
  A' = A rotate-right |p|, field LSB-aligned [0, w-1]; w = 0 per the general
  rule; Y = (B & ~mask) | (op-result & mask); Z per the selected field,
  N = Y31. Aligned (AL) variants ANDF/ORF/XORF/PASSF-AL-A (79/75/77/73),
  PASSF-AL-B (6F), NOTF-AL-A/B (71/6E): p treated as a 5-bit unsigned
  position; the op applies to A (or B) and B in place over [p, p+w-1];
  Y = (B & ~mask) | (op & mask); Z per the field, N = Y31. (PASSF-AL-B
  tests B's field: Y = B unchanged, Z per the field.)
- **Mask (Table 16):** PASS-MASK (7F): Y = the field mask [p5u, p5u+w-1]
  (w = 0 → [p5u, 31]) XOR {32{p-sign}}; no status side effects.

## Output pins

- Y bus: three-state, enabled when OE-Y is LOW and SLAVE is LOW; Y parity
  PY3:0 = even parity per byte of Y.
- C, Z, N, V, L pins: SLAVE LOW: (RS HIGH or HOLD HIGH) → the corresponding
  status-register bits; RS LOW → the instruction's new flag when the
  instruction generates that flag, else the status-register bit. SLAVE HIGH:
  the pins are inputs and are compared against the internally selected
  values for MSERR.
- PERR: HIGH when any DA/DB byte fails even parity against PA3:0/PB3:0;
  input in slave mode (compared).
- MSERR: HIGH on any mismatch: slave mode compares the externally driven
  Y (when OE-Y is LOW), PY3:0 (when OE-Y is LOW), C/Z/N/V/L and PERR against
  the internal results; master mode compares the driven outputs against the
  internal values (pad/buffer diagnostic).

## Timing

All internal state (status register, Q register) clocks on CP rising edges,
gated by HOLD (HIGH freezes both registers). Everything else — Y, flags,
parity, MSERR, the relational status bits — is combinational in the same
cycle. The register file (Am29334) is off-chip: the Y result is written back
externally and fed back over DA/DB the following cycle (the lockstep oracle
drives this feedback explicitly).

## Model scope

- The power-up state of the status and Q registers is undefined on the real
  part; the model defines a deterministic all-zero initial state at time 0.
  Initialization via LDSTAT is the documented bring-up path.
- Slave-mode Y/PY/flag comparison is modeled on the internal result vs. the
  external pin values. Master-mode buffer-open diagnostic (comparing the
  internal value against the externally observed pad) is modeled the same
  way; a silent pad fault cannot be distinguished from a correct drive in a
  digital model, so the master-mode MSERR path is exercised by the
  testbench driving the bus.
- No AC timing; the model is cycle-accurate at the CP interface.

## Assumption ledger

- ASSUMPTION: power-up state modeled as all-zero (the part has no reset pin;
  the manual defines no power-up value; bring-up is via LDSTAT).
- ASSUMPTION: M/m polarity — HIGH selects the MCIN/MLINK pins, LOW the
  status-register C/L (datasheet PIN DESCRIPTION and the ADDC/SUBC/DN1-LF
  instruction notes). The manual's MPDIVSTEP2/3 note states the inverted
  polarity ("SEL = 0 selects MACRO"); the datasheet pin definition is taken
  as authoritative.
- ASSUMPTION: C flag for the ADD class (ADD/ADDC/INCR/INCR2/INCR4) stores
  the raw carry regardless of BOROW (Appendix A "borrow mode does not affect
  addition in any way", ADD note 1). The INCR pages' "C EX-OR of carryout &
  BORROW-MODE" phrasing is not applied to the add class.
- ASSUMPTION: LDSTAT/C,Z,N,V,L output pins — LDSTAT/PASS-STAT/PASS-Q do not
  drive the direct ALU flags; with RS LOW the pins show the status-register
  bits (the flags are "not applicable" for these instructions). Chapter 2's
  "Status Generated: Z..A19 …" columns describe the post-edge register
  contents, which the byte-width write mask already produces.
- ASSUMPTION: PASS-Q updates no status flags (Chapter 2 lists no generated
  flags; Table 6-3's OCR is ambiguous).
- ASSUMPTION: DN1-AR fill bit = the source operand's own sign bit
  (Chapter 2: "the sign bit shifted in"; note 1 "arithmetic downshift").
  Table 8-1's "Ymsb = N" notation is read as the operand sign, not the
  status N flag.
- ASSUMPTION: UDIVSTEP/UDIVLAST quotient bit = complement of F[w], the
  extended-result sign bit (ch2 explicit sentence; matches the 75h/02h trace
  at every step). The equivalent "M ⊕ S ⊕ C" phrasing is the same value
  under the division invariant; the trace pins the complement form.
- ASSUMPTION: UDIVSTEP S/L ← F[w-1] (the w-bit remainder sign — flow chart
  B-6 "S ← SIGN(REM(B/W))"; algebraically required so {S, REM} is the true
  extended remainder). Chapter 2's "bit shifted out of F" could also read
  F[w]; every trace step has F[w-1] = F[w].
- ASSUMPTION: MPUDIVSTP3 quotient bit = M ⊕ S ⊕ C per its Chapter 2 text
  (with the instruction's carry-out); no worked example pins this member.
- ASSUMPTION: MPDIVSTEP1 "Z Set if Y equals zero" is evaluated over the
  selected bytes (the byte-width general rule).
- ASSUMPTION: divide-step C flag = raw extended adder carry-out (the
  "arithmetic carryout" feeds the next step's carry chain directly; BOROW
  polarity applies only to the add/subtract instruction class).
- ASSUMPTION: PRIOR loads the priority into STATUS<7:0> with bits 7:5 forced
  zero ("the most significant 3 bits of the position register are always
  forced to zero").
- ASSUMPTION: field masks truncate at bit 31 (no wraparound) — Chapter 2
  "the portion not falling within the word boundary is ignored", consistent
  with the mask-generator "ONEs inserted from the least significant end".
- ASSUMPTION: PASS-MASK position = the 5-bit unsigned p with p-sign as the
  whole-mask inverter (Chapter 2 and Table 16's Y = Ps form).
- ASSUMPTION: undefined opcodes 1E, 1F, 4C, 4D: outputs are not specified by
  the manual; the model passes B to Y and updates nothing (documented as
  unspecified; the verification never asserts behavior for them beyond Y = B
  and status/Q hold).
- ASSUMPTION: STATUS<15:13> and bit 23 have no storage cells — they are
  combinational functions of the stored flag bits (bit 13 also of the
  current BOROW pin) and every readout (PASS-STAT, LDSTAT unselected bytes,
  SETBIT/RSTBIT-STAT Y, EXTBIT-STAT) presents the combinational values, per
  EXTBIT-STAT note 2 ("read-only relational condition bits … STATUS <13> is
  affected by CARRY/BORROW mode") and PASS-STAT note 1.
- ASSUMPTION: MPUDIVSTP3's L/S update takes the w-bit remainder sign
  (F[w-1]), matching the trace-pinned UDIVSTEP rule; the multiprecision
  member has no worked example (ch2's "bit shifted out of F" phrasing is
  applied the same way across the divide family).
