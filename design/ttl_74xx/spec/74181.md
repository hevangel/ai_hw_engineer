# SN74LS181 / SN74S181 — 4-Bit Arithmetic Logic Unit / Function Generator

Source: Texas Instruments SDLS136, December 1972, Revised March 1988.
Secondary: Fairchild 74F181PC datasheet; National Semiconductor DM74LS181.

---

## 1. Overview

The 'LS181 and 'S181 are arithmetic logic units (ALU)/function generators with the complexity of 75 equivalent gates on a monolithic chip. These circuits perform 16 binary arithmetic operations on two 4-bit words and 16 logic operations on two 4-bit words, as shown in Tables 1 and 2.

The device features full internal carry lookahead for high-speed arithmetic operations on long words when used with the 'S182 or 'LS182 carry lookahead generator.

## 2. Features

- Performs 16 arithmetic operations: ADD, SUBTRACT, COMPARE, DOUBLE, plus 12 other arithmetic operations
- Performs all 16 logic operations of two variables: Exclusive-OR, Compare, AND, NAND, NOR, OR, plus 10 other logic operations
- Full internal carry lookahead for high-speed arithmetic operation on long words
- Carry-propagate (P) and carry-generate (G) outputs for use with 74182 carry lookahead generator
- Comparator output (A=B)
- Can operate with active-HIGH or active-LOW data

## 3. Pin Configuration (24-pin DIP)

| Pin | Name | Direction | Description |
|-----|------|-----------|-------------|
| 1 | B0 | Input | Operand B, bit 0 (LSB) |
| 2 | A0 | Input | Operand A, bit 0 (LSB) |
| 3 | S3 | Input | Function select, bit 3 (MSB) |
| 4 | S2 | Input | Function select, bit 2 |
| 5 | S1 | Input | Function select, bit 1 |
| 6 | S0 | Input | Function select, bit 0 (LSB) |
| 7 | Cn | Input | Carry input (active LOW for active-HIGH data) |
| 8 | M | Input | Mode control: H = Logic, L = Arithmetic |
| 9 | F0 | Output | Function output, bit 0 (LSB) |
| 10 | F1 | Output | Function output, bit 1 |
| 11 | F2 | Output | Function output, bit 2 |
| 12 | GND | Power | Ground |
| 13 | F3 | Output | Function output, bit 3 (MSB) |
| 14 | A=B | Output | Comparator output (open collector on some variants) |
| 15 | P̄ | Output | Carry propagate (active LOW) |
| 16 | Cn+4 | Output | Carry output (active LOW for active-HIGH data) |
| 17 | Ḡ | Output | Carry generate (active LOW) |
| 18 | B3 | Input | Operand B, bit 3 (MSB) |
| 19 | A3 | Input | Operand A, bit 3 (MSB) |
| 20 | B2 | Input | Operand B, bit 2 |
| 21 | A2 | Input | Operand A, bit 2 |
| 22 | B1 | Input | Operand B, bit 1 |
| 23 | A1 | Input | Operand A, bit 1 |
| 24 | VCC | Power | Supply voltage (+5V) |

## 4. Function Tables

### Conventions

- Active-HIGH data: H = logic 1, L = logic 0
- Carry input Cn: L = carry (i.e., Cn is active LOW — L means "carry in present")
- Arithmetic operations are in 2's complement notation
- "plus" denotes arithmetic addition; "minus" denotes arithmetic subtraction
- Overbar (NOT) denotes logical complement
- Juxtaposition (AB) denotes logical AND
- Plus sign in logic column (+) denotes logical OR
- ⊕ denotes Exclusive-OR

### Table 1: Function Table (Active-HIGH Data)

| S3 | S2 | S1 | S0 | M=H (Logic) | M=L, Cn=H (Arith, no carry) | M=L, Cn=L (Arith, with carry) |
|----|----|----|----|--------------|-----------------------------|-------------------------------|
| L | L | L | L | F = NOT A | F = A | F = A plus 1 |
| L | L | L | H | F = NOT(A OR B) | F = A OR B | F = (A OR B) plus 1 |
| L | L | H | L | F = (NOT A) AND B | F = A OR (NOT B) | F = (A OR NOT B) plus 1 |
| L | L | H | H | F = 0 (logic zero) | F = minus 1 (2's comp) | F = 0 (zero) |
| L | H | L | L | F = NOT(A AND B) | F = A plus (A AND NOT B) | F = A plus (A AND NOT B) plus 1 |
| L | H | L | H | F = NOT B | F = (A OR B) plus (A AND NOT B) | F = (A OR B) plus (A AND NOT B) plus 1 |
| L | H | H | L | F = A XOR B | F = A minus B minus 1 | F = A minus B |
| L | H | H | H | F = A AND (NOT B) | F = (A AND NOT B) minus 1 | F = A AND (NOT B) |
| H | L | L | L | F = (NOT A) OR B | F = A plus (A AND B) | F = A plus (A AND B) plus 1 |
| H | L | L | H | F = NOT(A XOR B) | F = A plus B | F = A plus B plus 1 |
| H | L | H | L | F = B | F = (A OR NOT B) plus (A AND B) | F = (A OR NOT B) plus (A AND B) plus 1 |
| H | L | H | H | F = A AND B | F = (A AND B) minus 1 | F = A AND B |
| H | H | L | L | F = 1 (logic one) | F = A plus A | F = A plus A plus 1 |
| H | H | L | H | F = A OR (NOT B) | F = (A OR B) plus A | F = (A OR B) plus A plus 1 |
| H | H | H | L | F = A OR B | F = (A OR NOT B) plus A | F = (A OR NOT B) plus A plus 1 |
| H | H | H | H | F = A | F = A minus 1 | F = A |

### Table 2: Function Table (Active-LOW Data)

| S3 | S2 | S1 | S0 | M=H (Logic) | M=L, Cn=L (Arith, no carry) | M=L, Cn=H (Arith, with carry) |
|----|----|----|----|--------------|-----------------------------|-------------------------------|
| L | L | L | L | F = NOT A | F = A minus 1 | F = A |
| L | L | L | H | F = NOT(A AND B) | F = (A AND B) minus 1 | F = A AND B |
| L | L | H | L | F = (NOT A) OR B | F = (A AND NOT B) minus 1 | F = A AND (NOT B) |
| L | L | H | H | F = 1 (logic one) | F = minus 1 (all ones) | F = 0 (zero) |
| L | H | L | L | F = NOT(A OR B) | F = A plus (A OR NOT B) | F = A plus (A OR NOT B) plus 1 |
| L | H | L | H | F = NOT B | F = (A AND B) plus (A OR NOT B) | F = (A AND B) plus (A OR NOT B) plus 1 |
| L | H | H | L | F = NOT(A XOR B) | F = A minus B minus 1 | F = A minus B |
| L | H | H | H | F = A OR (NOT B) | F = A OR NOT B | F = (A OR NOT B) plus 1 |
| H | L | L | L | F = (NOT A) AND B | F = A plus (A OR B) | F = A plus (A OR B) plus 1 |
| H | L | L | H | F = A XOR B | F = A plus B | F = A plus B plus 1 |
| H | L | H | L | F = B | F = (A AND NOT B) plus (A OR B) | F = (A AND NOT B) plus (A OR B) plus 1 |
| H | L | H | H | F = A OR B | F = A OR B | F = (A OR B) plus 1 |
| H | H | L | L | F = 0 (logic zero) | F = A plus A | F = A plus A plus 1 |
| H | H | L | H | F = A AND (NOT B) | F = (A AND B) plus A | F = (A AND B) plus A plus 1 |
| H | H | H | L | F = A AND B | F = (A AND NOT B) plus A | F = (A AND NOT B) plus A plus 1 |
| H | H | H | H | F = A | F = A | F = A plus 1 |

**Derivation:** For active-LOW logical words, each row is the negative-logic dual
`F_low(A, B) = NOT F_high(NOT A, NOT B)`, with all complements applied
bitwise. The arithmetic carry convention is also dual: `Cn=L` means no carry
and `Cn=H` means carry present. The table has been exhaustively checked over
all 256 four-bit `A,B` pairs for every selector and both arithmetic carry cases.

## 5. Internal Logic Equations (Active-HIGH)

The logic diagram can be expressed with two active-HIGH terms per bit. For bit `i`:

```text
X_i = A_i + B_i S0 + (NOT B_i) S1
Y_i = A_i (NOT B_i) S2 + A_i B_i S3
```

Here `+` means OR and juxtaposition means AND. The selector positions are significant: `S0` qualifies `B`, while `S1` qualifies `NOT B`; `S2` qualifies `A AND NOT B`, while `S3` qualifies `A AND B`.

Define active-HIGH internal carries, while retaining the physical part's active-LOW external carry pins:

```text
C0 = (NOT Cn) (NOT M)
C1 = Y0 (NOT M) + X0 C0
C2 = Y1 (NOT M) + X1 C1
C3 = Y2 (NOT M) + X2 C2
C4 = Y3 (NOT M) + X3 C3
```

The function output is:

```text
F_i = X_i XOR Y_i XOR C_i XOR M
```

Consequences:

- In logic mode (`M=1`), every internal carry is zero and `F_i = NOT (X_i XOR Y_i)`.
- In arithmetic mode (`M=0`), `F_i = X_i XOR Y_i XOR C_i` and `C0 = NOT Cn`.
- `Cn=0` therefore inserts the arithmetic carry required by the active-HIGH table's “with carry” column.

The group lookahead outputs are active LOW:

```text
P_bar = NOT (X3 X2 X1 X0)
G_bar = NOT (Y3 + X3 Y2 + X3 X2 Y1 + X3 X2 X1 Y0)
Cn+4  = NOT C4
```

Equivalently in arithmetic mode, `NOT Cn+4 = NOT G_bar + (NOT P_bar)(NOT Cn)`. `P_bar` and `G_bar` depend on A, B, and S, not on M or Cn, so they remain available for cascading through a 74182.

The comparator output is exactly:

```text
A=B = F3 F2 F1 F0
```

It indicates that every F output is HIGH; it is not an unconditional equality comparison of the A and B pins. For equality comparison, use `S=0110`, `M=0`, and `Cn=1`, which computes `A-B-1`; equal operands produce `F=1111` and assert `A=B`.

## 6. Timing Parameters (SN74LS181)

### Propagation Delays (typical / maximum)

| Parameter | From | To | Typical | Maximum | Unit |
|-----------|------|----|---------|---------|------|
| tPLH | S inputs | F outputs | 17 | 24 | ns |
| tPHL | S inputs | F outputs | 17 | 24 | ns |
| tPLH | A, B inputs | F outputs | 17 | 24 | ns |
| tPHL | A, B inputs | F outputs | 17 | 24 | ns |
| tPLH | Cn | F outputs | 14 | 22 | ns |
| tPHL | Cn | F outputs | 12 | 17 | ns |
| tPLH | Cn | Cn+4 | 12 | 17 | ns |
| tPHL | Cn | Cn+4 | 12 | 17 | ns |
| tPLH | A, B | P̄, Ḡ | 17 | 27 | ns |
| tPHL | A, B | P̄, Ḡ | 15 | 22 | ns |
| tPLH | S inputs | P̄, Ḡ | 20 | 30 | ns |
| tPHL | S inputs | P̄, Ḡ | 15 | 22 | ns |

### SN74S181 (Schottky)

| Parameter | Typical | Maximum | Unit |
|-----------|---------|---------|------|
| S to F | 11 | 16 | ns |
| A,B to F | 11 | 16 | ns |
| Cn to F | 8 | 11 | ns |
| Cn to Cn+4 | 7 | 10 | ns |

## 7. Electrical Characteristics (SN74LS181)

| Parameter | Condition | Min | Typ | Max | Unit |
|-----------|-----------|-----|-----|-----|------|
| VIH | Input HIGH voltage | 2.0 | — | — | V |
| VIL | Input LOW voltage | — | — | 0.8 | V |
| VOH | Output HIGH voltage (IOH = -400µA) | 2.7 | 3.4 | — | V |
| VOL | Output LOW voltage (IOL = 8mA) | — | 0.25 | 0.4 | V |
| ICC | Supply current | — | 38 | 58 | mA |
| VCC | Supply voltage | 4.75 | 5.0 | 5.25 | V |

## 8. Operating with 74182 Carry Lookahead Generator

For multi-chip configurations (8-bit, 16-bit, 32-bit, 64-bit words):

```
                    74182 CLA Generator
                   ┌─────────────────────┐
  74181 #0 ─ P̄,Ḡ ─┤ P0,G0    Cn+x      ├─── to 74181 #1 Cn
  74181 #1 ─ P̄,Ḡ ─┤ P1,G1    Cn+y      ├─── to 74181 #2 Cn
  74181 #2 ─ P̄,Ḡ ─┤ P2,G2    Cn+z      ├─── to 74181 #3 Cn
  74181 #3 ─ P̄,Ḡ ─┤ P3,G3    P̄,Ḡ       ├─── to next 74182
              Cn ──┤ Cn                  │
                   └─────────────────────┘
```

This allows 16-bit addition in 2 gate delays beyond a single 74181, rather than ripple carry through 4 chips.

## 9. Application Notes

### Subtraction (A minus B)
- Select S3=0, S2=1, S1=1, S0=0 (S=0110)
- Mode M=L (arithmetic)
- Cn=L (carry in) for true subtraction: F = A - B
- Cn=H (no carry) for: F = A - B - 1

### Addition (A plus B)
- Select S3=1, S2=0, S1=0, S0=1 (S=1001)
- Mode M=L (arithmetic)
- Cn=L (carry in): F = A + B + 1
- Cn=H (no carry): F = A + B

### Increment (A plus 1)
- Select S3=0, S2=0, S1=0, S0=0 (S=0000)
- Mode M=L, Cn=L: F = A + 1

### Decrement (A minus 1)
- Select S3=1, S2=1, S1=1, S0=1 (S=1111)
- Mode M=L, Cn=H: F = A - 1

### 2's Complement (negate)
- Connect the value to negate to B and force A=0000
- Select S=0110, M=L, Cn=L: F = 0 minus B = two's complement of B
- Equivalently, complement a value with logic S=0000 and then increment it with arithmetic S=0000, M=L, Cn=L in a second operation

### Left Shift (A × 2)
- Select S3=1, S2=1, S1=0, S0=0 (S=1100)
- Mode M=L: F = A + A (= 2A = left shift)
- Cn=H: F = A + A (shift, zero fill)
- Cn=L: F = A + A + 1 (shift with 1 fill in LSB)

### Compare
- Use subtraction (S=0110, M=L, Cn=L): F = A - B
- A=B output goes HIGH when result is all-ones (S=0110, Cn=H: F=A-B-1, all-1s when A=B)
- Actually use the A=B output with appropriate mode
- For cascading comparators: AND the A=B outputs together

## 10. Package Information

- 24-pin DIP (Dual In-line Package)
- Also available in 24-pin SOIC (surface mount)
- Military temperature range: -55°C to +125°C (SN54LS181)
- Commercial temperature range: 0°C to +70°C (SN74LS181)

## 11. Implementation Notes for RTL

For a synthesizable SystemVerilog implementation:

1. The design is purely combinational (no clock, no flip-flops)
2. Implement using the active-HIGH function table (Table 1)
3. Cn is active-LOW in the original TTL part — for RTL, we can choose either convention
4. The carry lookahead logic (P̄, Ḡ) must be implemented for correctness
5. The A=B output is simply the AND-reduction of F
6. For simulation with xezim, wrap in a module with clock/reset for testbench integration

### Recommended RTL port naming (active-HIGH, Cn active-LOW matching original):

```systemverilog
module alu_74181 (
    input  logic [3:0] a,       // Operand A
    input  logic [3:0] b,       // Operand B
    input  logic [3:0] s,       // Function select
    input  logic       m,       // Mode: 1=logic, 0=arithmetic
    input  logic       cn,      // Carry in (active LOW: 0=carry, 1=no carry)
    output logic [3:0] f,       // Function output
    output logic       cn4,     // Carry out (active LOW)
    output logic       a_eq_b,  // A equals B (HIGH when F=1111)
    output logic       p_bar,   // Carry propagate (active LOW)
    output logic       g_bar    // Carry generate (active LOW)
);
```
