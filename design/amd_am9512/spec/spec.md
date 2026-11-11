# Am9512 specification

## Source priority and modeling boundary

This is a synthesizable digital functional reconstruction of the AMD Am9512
floating-point processor. It is not a transistor, analog, propagation-delay or
original microcode reconstruction.

Primary sources, in priority order:

1. AMD, *Am9500 Peripheral Products Interface Guide* (1980), the Am9512 chapter
   at printed pages 4-27 through 4-39 (PDF pages 74-86). This is the detailed
   Am9512 datasheet text used for the command, format, status and algorithm
   contract. The scan is text-searchable; OCR errors are resolved against the
   command bit diagrams and the 1981 manual where they overlap.
2. AMD, *Am9511A/Am9512 Floating Point Processor Manual*, Steven Cheng (May
   1981), section 5.3 and the Am9512 command descriptions. The scan is
   image-only; its readable text and the 1980 guide agree on the command set,
   stack effects, status names and the 32/64-bit formats.
3. AMD, *Am9512* datasheet (the 1980 chapter above is the canonical datasheet
   text; the separate 943 KB scan carries the same content).
4. *Electronics*, 5 July 1979, describes the device; AMD's 1981 manual dates
   the Am9512 introduction to 1979. No exact launch month is asserted.

The 1981 manual is later than the 1980 guide. Where they differ, the 1980
guide is the target for this reconstruction. The Am9512 is not an IEEE 754
implementation in the later, complete sense: it has no infinities, NaNs,
signed zeros, subnormals or IEEE exception results. It uses an IEEE-like
format with round-to-nearest-even and a zero/one status-flag model.

Illegal command bytes and unlisted opcodes are undefined. The Am9512 command
table defines exactly 16 operations; all other 7-bit opcodes are outside the
contract. Stack locations below the current logical top are outside the
documented result contract after an operation. The host is responsible for
pushing exactly four bytes for a single-precision operand and eight bytes for a
double-precision operand; a misaligned byte pointer is a host error.

## Features

- 32-bit single-precision and 64-bit double-precision binary floating point.
- Add, subtract, multiply and divide for both precisions.
- Eight data-manipulation operations: change sign, duplicate TOS, pop TOS,
  exchange single-precision TOS/NOS, and clear status.
- Sixteen-byte LIFO operand stack, organized as four single-precision or two
  double-precision operands.
- 8-bit bidirectional host bus with programmed I/O and DMA-friendly PAUSE
  handshake.
- Busy, end-of-execution, error and service-request outputs.
- Status register with sign, zero, exponent-overflow, exponent-underflow and
  divide-exception bits.
- Round-to-nearest-even arithmetic.

## Pins and interface

| Pin | Direction | Description |
|---|---|---|
| `clk_i` | input | Sampling clock. |
| `reset_i` | input | Active HIGH. Terminates operation, clears status, initializes the stack pointer, clears END/ERR/SVREQ. Must be HIGH for at least five clocks. |
| `cs_n_i` | input | Active LOW chip select. |
| `rd_n_i` | input | Active LOW read. |
| `wr_n_i` | input | Active LOW write. |
| `cd_i` | input | Command/data select. HIGH for command writes and status reads; LOW for stack-byte accesses. |
| `eack_n_i` | input | Active LOW end acknowledge. Clears END. Tied LOW gives a one-clock END pulse. |
| `svack_n_i` | input | Active LOW service acknowledge. Clears SVREQ. |
| `data_i[7:0]` | input | Host data bus. |
| `data_o[7:0]` | output | Read data bus. |
| `data_oe_o` | output | HIGH when the read data bus is driving. |
| `pause_n_o` | output | Active LOW pause/handshake. LOW while a selected transaction is waiting; HIGH when acknowledged. |
| `end_o` | output | HIGH when the current command is complete; cleared by EACK, any access, or reset. |
| `err_o` | output | HIGH when the latched error condition is present; cleared by a status read or reset. |
| `svreq_o` | output | HIGH when a completed command had service request enabled; cleared by SVACK, reset, or a later command with service request disabled. |

The interface is clock-sampled in this reconstruction. RESET, EACK and SVACK
are sampled on rising clock edges. A read or write cycle is accepted once, with
one-clock interface latency. PAUSE is LOW while the selected cycle is waiting
and returns HIGH when the cycle has completed. The host must hold C/D, the data
bus and the control inputs until PAUSE returns HIGH. Status reads remain
available while a command is executing.

The physical part is asynchronous; setup, hold, propagation and the exact
PAUSE pulse widths are outside this functional contract. The documented
execution-time table is recorded in the verification plan, but the RTL does not
claim those cycle counts.

## Command format

A command byte is `{svreq, opcode[6:0]}`. Bit 7 is the service request enable.
Bit 7 does not change the arithmetic operation. The 16 documented opcodes are:

| Opcode | Mnemonic | Operation |
|---:|---|---|
| 0x00 | CLR | Clear all status bits. Stack unchanged. |
| 0x01 | SADD | Single-precision NOS + TOS -> NOS, pop TOS. |
| 0x02 | SSUB | Single-precision NOS - TOS -> NOS, pop TOS. |
| 0x03 | SMUL | Single-precision NOS * TOS -> NOS, pop TOS. |
| 0x04 | SDIV | Single-precision NOS / TOS -> NOS, pop TOS. |
| 0x05 | CHSS | Complement sign of single-precision TOS. |
| 0x06 | PTOS | Duplicate single-precision TOS into NOS (push). |
| 0x07 | POPS | Pop single-precision TOS; old NOS becomes TOS; old TOS rotates to bottom. |
| 0x08 | XCHS | Exchange single-precision TOS and NOS. |
| 0x29 | DADD | Double-precision NOS + TOS -> NOS, pop TOS. |
| 0x2A | DSUB | Double-precision NOS - TOS -> NOS, pop TOS. |
| 0x2B | DMUL | Double-precision NOS * TOS -> NOS, pop TOS. |
| 0x2C | DDIV | Double-precision NOS / TOS -> NOS, pop TOS. |
| 0x2D | CHSD | Complement sign of double-precision TOS. |
| 0x2E | PTOD | Duplicate double-precision TOS into NOS (push). |
| 0x2F | POPD | Pop double-precision TOS; old NOS becomes TOS; old TOS rotates to bottom. |

There is no double-precision exchange command and no transcendental function.
The Am9511 XCHD/PUPI/TRIG commands are not part of the Am9512.

The command table in `references/commands.csv` records the source pages and the
stack effect of every command. `scripts/generate_commands.py` regenerates the
SystemVerilog opcode constants and checks that table against the RTL.

## Stack semantics

The external stack is sixteen bytes. The RTL models it as a 128-bit register
whose most significant byte is the current TOS byte.

- Writing a data byte with C/D LOW pushes it at the top: the old top byte is
  discarded after shifting down.
- Reading a data byte with C/D LOW returns the current top byte, then rotates it
  to the bottom. The read does not destroy the byte; it moves the byte pointer.
  Reading more bytes than the stack holds wraps and rereads older bytes.
- Single-precision operands occupy four bytes, least significant byte first.
  Double-precision operands occupy eight bytes, least significant byte first.
- Results are read most significant byte first, the same way.
- A single-precision arithmetic result is four bytes. It replaces NOS and pops
  TOS, so the logical stack loses one four-byte slot.
- A double-precision arithmetic result is eight bytes. It replaces NOS and pops
  TOS, so the logical stack loses one eight-byte slot.
- PTOS/PTOD duplicate TOS; POPS/POPD move TOS to the bottom and promote NOS.
- CHSS/CHSD leave the stack depth unchanged.

The internal Am9512 block diagram describes an eight-word by seventeen-bit
two-port stack. The extra bit is not externally visible. This reconstruction
uses a byte-addressed 128-bit model; that preserves every documented external
stack effect and byte order without claiming the internal word width.

## Data formats

### Single precision

```
31    30      23 22            0
+-----+----------+---------------+
| S   | E[7:0]   | M[22:0]       |
+-----+----------+---------------+
```

- S is the sign.
- E is an 8-bit biased exponent, bias 127.
- M is a 23-bit fraction. The binary point is between an implied leading 1 and
  M[22]. The significand is `1.M`, a 24-bit normalized value.
- The represented value is `(-1)^S * 2^(E-127) * 1.M`.
- E = 0 denotes zero. The Am9512 zero test examines the exponent field, not the
  mantissa: a word with E = 0 is zero even if its mantissa bits are nonzero.
  Results are canonicalized to all zero when the exponent field is zero.
- E = 255 is outside the normalized range in this reconstruction. The format
  is IEEE-like but does not define infinities or NaNs; the RTL treats E = 255
  as an overflow encoding and documents the result assumption below.

### Double precision

```
63    62      52 51            0
+-----+----------+---------------+
| S   | E[10:0]  | M[51:0]       |
+-----+----------+---------------+
```

- S is the sign.
- E is an 11-bit biased exponent, bias 1023.
- M is a 52-bit fraction with an implied leading 1; the significand is 53 bits.
- The represented value is `(-1)^S * 2^(E-1023) * 1.M`.
- E = 0 denotes zero, with the same exponent-only zero test.
- E = 2047 is outside the normalized range in this reconstruction.

## Status register

```
7   6   5   4   3   2   1   0
+-----------------+---+---+---+
| Busy | S | Z | 0 | D | U | V | 0 |
+-----------------+---+---+---+
```

| Bit | Name | Meaning |
|---:|---|---|
| 0 | reserved | Reads as 0. |
| 1 | V | Exponent overflow. |
| 2 | U | Exponent underflow. |
| 3 | D | Divide exception (attempt to divide by zero). |
| 4 | reserved | Reads as 0. |
| 5 | Z | Result at TOS is zero. |
| 6 | S | Result at TOS is negative. |
| 7 | Busy | Command in progress. |

On command issue, bits 6:0 are cleared. On completion, the result status is
written. While Busy is 1, only Busy and possibly the error bits are meaningful;
the other bits are not guaranteed. CLR clears all eight bits. A status read
does not clear the status register; it clears the latched ERR output.

`ERR` is HIGH when the latched error condition is present. It is set when an
error bit becomes 1 and cleared by a status read or RESET. The physical part
may update ERR during execution; this reconstruction sets the latch at command
completion and clears it on a status read or reset.

## Arithmetic contract

### Zero and special values

- A word with E = 0 is zero. The mantissa is ignored for the zero test.
- Arithmetic with a zero operand follows the identity:
  - `0 + x = x`, `x + 0 = x`.
  - `0 - x = -x`, `x - 0 = x`; `0 - 0 = 0`.
  - `0 * x = 0`.
  - `0 / x = 0`.
  - `x / 0` is a divide exception: the result is the numerator (NOS), D = 1.
- Zero results are canonical all-zero words. The sign of a zero result is 0.
- There are no infinities, NaNs or subnormal encodings.

### Round-to-nearest-even

The manual defines round-to-even with guard, round and sticky bits:

- Let the retained significand be B1..Bn, with guard G, round R and sticky ST.
- Add 1 at the G position. If G = R = ST = 0 after that addition, clear the
  retained LSB (round to even). Truncate the extra bits.
- For multiplication, G is the first discarded product bit, R the second, and
  ST the OR of the remaining discarded product bits.
- For division, G is the first discarded quotient bit, R the second, and ST is
  1 only if the remainder is nonzero.
- For addition/subtraction, the aligned and normalized accumulator supplies G,
  R and ST. A subtraction that required a left shift needs no rounding because
  the shifted-in bits are zero.

The RTL implements this exact rule with an explicit three-bit guard/round/sticky
field. Tests compare against an independent exact-rational oracle, not against
the RTL's own arithmetic.

### Exponent overflow and underflow

The 1980 Am9512 chapter specifies the status bits but does not define a special
result value for overflow or underflow. The Am9511 has a separate documented
"exponent offset by 128" behavior; that is not stated for the Am9512 and is not
applied here. This reconstruction uses the fixed-width exponent register
behavior:

- On exponent overflow, the biased exponent is wrapped modulo `2^EXP_W`, the
  computed mantissa is retained, and V is set.
- On exponent underflow, the result is canonical zero, and U is set.
- The mantissa and exponent are computed from the exact intermediate result;
  no attempt is made to emulate an unspecified internal microcode path.

This is an explicit reconstruction assumption, recorded in the ledger below.
It is not a claim about undocumented Am9512 silicon.

## Command details

### Arithmetic commands

For SADD/SSUB/SMUL/SDIV and DADD/DSUB/DMUL/DDIV:

1. Unpack TOS (A) and NOS (B). Restore the implied leading 1.
2. For subtraction, complement the sign of A, then add.
3. If either operand is zero, use the zero identities above.
4. Add or subtract:
   - Align the smaller-exponent mantissa right, tracking guard, round and
     sticky bits.
   - Add magnitudes for equal signs; subtract smaller from larger for opposite
     signs.
   - Normalize the result. A carry out shifts right one and increments the
     exponent. A subtraction left-shifts until the leading 1 is in the hidden
     position and decrements the exponent.
   - Round to nearest even.
5. Multiply:
   - Add unbiased exponents.
   - Multiply the 24-bit or 53-bit significands.
   - Normalize the double-length product and round to the target precision.
6. Divide:
   - Subtract exponents.
   - Divide the NOS significand by the TOS significand with guard, round and
     sticky bits.
   - Normalize and round.
7. Set S from the result sign, Z if the result is zero, V/U on exponent
   overflow/underflow, and D on a zero divisor. Add/subtract/multiply clear D;
   divide sets D only for a zero TOS.

The status bits S and Z describe the result at TOS after the operation.
Preserved bits are the ones not listed as affected; for arithmetic, the
affected set is S, Z, U, V and, for divide, D.

### Data-manipulation commands

| Command | Stack effect | Status |
|---|---|---|
| CLR | none | all bits cleared |
| CHSS | complement bit 31 of TOS; if E = 0, TOS becomes all zero | S, Z from result; U,V,D = 0 |
| CHSD | complement bit 63 of TOS; if E = 0, TOS becomes all zero | S, Z from result; U,V,D = 0 |
| PTOS | duplicate single TOS into NOS; if old TOS E = 0, new TOS is zero and NOS is the old TOS | S, Z from new TOS; U,V,D = 0 |
| PTOD | duplicate double TOS into NOS | S, Z from new TOS; U,V,D = 0 |
| POPS | TOS rotates to bottom; NOS becomes TOS | S, Z from new TOS; U,V,D = 0 |
| POPD | double TOS rotates to bottom; NOS becomes TOS | S, Z from new TOS; U,V,D = 0 |
| XCHS | exchange single TOS and NOS | S, Z from new TOS; U,V,D = 0 |

PTOS has the documented single-precision special case: if the old TOS exponent
field is zero, the new TOS is all zero and NOS is an exact copy of the old TOS.
PTOD has no such special case in the 1980 chapter; it duplicates the 64-bit
word exactly.

## Reset and initialization

RESET is active HIGH and synchronous in this reconstruction. It:

- terminates any command,
- clears the status register,
- initializes the byte pointer to the top of the stack,
- clears END, ERR and SVREQ,
- clears the stack contents.

The physical part says the stack contents "may be affected" but does not
guarantee a value. Clearing is an allowed reconstruction choice, not a silicon
claim. The reset is held for at least one clock; the physical part requires
five clocks.

## Assumption ledger

| Assumption | Basis | Verification |
|---|---|---|
| Clock-sampled interface, one-clock acceptance latency, sampled EACK/SVACK/RESET | Explicit digital adapter to the documented asynchronous handshake; physical delays are outside the contract | Directed PAUSE/read/write and reset tests |
| Stack cleared on RESET | 1980 guide: RESET initializes the stack pointer and "contents may be affected"; value unspecified | Reset test checks all-zero stack and pointer |
| Zero is E = 0, mantissa ignored; results canonicalized to all-zero | 1980 guide zero checks and CHSS/PTOS descriptions | Directed zero, denormal-looking mantissa, and status tests |
| Round-to-nearest-even with the manual's G/R/ST rule | 1980 guide section 6 | Independent exact-rational oracle over directed and random vectors |
| Overflow result wraps the biased exponent; underflow result is zero | 1980 guide states the flags but not the result value; fixed-width exponent register is the reconstruction choice. The Am9511's exponent-offset-by-128 rule is explicitly not applied | Directed overflow/underflow cases; documented as a reconstruction assumption |
| Status bits not listed as affected hold their previous value | Individual command descriptions list affected bits; the Am9511 design uses the same convention. The Am9512 chapter does not explicitly state preservation | Directed tests seed all flags before each command and check the affected set |
| CLR clears all status and leaves the stack unchanged | 1980 guide CLR description | Directed CLR test |
| ERR latch set at completion and cleared by status read/reset | 1980 guide ERR description | Directed status-read and error tests |
| No infinities, NaNs, signed zeros or subnormals | 1980 guide defines only the finite format and E = 0 zero; later IEEE 754 behavior is not claimed | Format tests and report limits |

Every assumption that affects RTL behavior carries an `ASSUMPTION:` comment in
the source. Illegal opcodes, misaligned byte counts, non-canonical zero
encodings and unspecified microarchitectural details are outside the result
contract, not silently defined cases.

## Verification boundary

In scope:

- All 16 commands and their service-request variants.
- Single- and double-precision add, subtract, multiply and divide for normal,
  zero, signed and boundary operands.
- Stack byte order, push/pop/duplicate/exchange behavior and the documented
  wrap on over-pop.
- Status bits, CLR, ERR, END, SVREQ, PAUSE and RESET.
- Lint, directed and randomized simulation, formal stack/status properties,
  reachable covers, and generic synthesis.

Out of scope:

- Original microcode, microcycle counts and execution-time table values.
- Analog timing, propagation delays, drive strength and electrical levels.
- Internal 17-bit stack word, constant ROM and working-register contents.
- Physical silicon errata and undocumented behavior.

## IEEE 754 differences

The Am9512 format is an early, draft-IEEE-like binary format, not IEEE 754 as
later standardized:

- No signed zero: E = 0 is zero regardless of the sign bit, and results are
  canonicalized to all-zero.
- No infinities or NaNs; E = all ones is outside the implemented normalized
  range.
- No subnormals or gradual underflow; E = 0 is the only zero encoding.
- Overflow and underflow set status bits; the returned finite encoding is a
  reconstruction assumption, not an IEEE-defined infinity or zero.
- Round-to-nearest-even is the only rounding mode; there is no rounding-mode
  register.
- The status register is a simple five-flag word, not the IEEE exception model
  with invalid-operation, division-by-zero, overflow, underflow and inexact
  flags.

These differences are part of the historical contract and are tested directly.