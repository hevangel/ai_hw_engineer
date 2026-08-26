# Implementation Plan: alu_74181

## Objective

Implement a synthesizable, purely combinational SN74LS181-compatible 4-bit ALU using the active-HIGH data table from TI SDLS136. Preserve the original active-LOW `Cn`, `Cn+4`, `P`, and `G` conventions.

## Interface

| Signal | Direction | Meaning |
|---|---|---|
| `a[3:0]`, `b[3:0]` | input | Active-HIGH operands |
| `s[3:0]` | input | Function selector |
| `m` | input | `1`: logic, `0`: arithmetic |
| `cn` | input | Active-LOW carry input; `0` means carry present |
| `f[3:0]` | output | Active-HIGH result |
| `cn4` | output | Active-LOW carry output |
| `p_bar`, `g_bar` | output | Active-LOW group propagate/generate |
| `a_eq_b` | output | HIGH exactly when `f == 4'hf` |

## Architecture

For each bit `i`, compute the datasheet terms:

```text
X[i] = A[i] OR (B[i] AND S0) OR (NOT B[i] AND S1)
Y[i] = (A[i] AND NOT B[i] AND S2) OR (A[i] AND B[i] AND S3)
```

The internal carry is active HIGH:

```text
C0   = NOT Cn AND NOT M
C1   = (Y0 AND NOT M) OR (X0 AND C0)
C2   = (Y1 AND NOT M) OR (X1 AND C1)
C3   = (Y2 AND NOT M) OR (X2 AND C2)
C4   = (Y3 AND NOT M) OR (X3 AND C3)
F[i] = X[i] XOR Y[i] XOR C[i] XOR M
```

The lookahead outputs are:

```text
P_bar = NOT (X3 X2 X1 X0)
G_bar = NOT (Y3 + X3Y2 + X3X2Y1 + X3X2X1Y0)
Cn+4  = NOT C4
A=B   = F3 F2 F1 F0
```

## Work Phases

1. Correct the gate-equation RTL and retain a combinational-only module boundary.
2. Add a structurally independent case-table oracle and exhaustively simulate all 16,384 `A/B/S/M/Cn` combinations.
3. Add an IEEE 1800.2-2017 UVM smoke environment covering every selector, mode, and carry-input state.
4. Prove all outputs against the normalized datasheet table as separately coded in the formal harness.
5. Run Verilator and Verible lint, xezim simulations, SymbiYosys BMC/prove/cover, and Yosys generic synthesis.
6. Record exact commands, versions, counts, and synthesis statistics in the final report.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Data convention | Active HIGH | Matches TI function table 1 |
| Carry convention | Active LOW externally | Matches physical 74181 pins |
| Internal representation | Active-HIGH `X`, `Y`, and carry | Makes carry-lookahead equations explicit |
| RTL style | Structural combinational equations | Closely follows the datasheet and remains synthesizable |
| Functional oracle | Structurally independent `case` tables | Avoids reproducing DUT equations; all environments share the normalized datasheet table |
| Timing | No delays in RTL | Datasheet delays are technology-specific and not synthesizable behavior |
