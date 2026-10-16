# Original Intel ARRSUM regression

Source: Intel, *The 8086 Family User's Manual, Numerics Supplement*, July
1980, figure S-24, printed S-64–S-66 (PDF pages 78–80), linked in the
[reference manifest](../references/README.md).

The manufacturer program accumulates sum(X), sum(i*X[i]) and sum(X[i]^2).
The regression transcribes its numeric instruction sequence and original
reverse traversal:

```asm
FLDCW CONTROL_87       ; 033Eh, manufacturer's value
FLDZ
FLDZ
FLDZ
; CPU supplies reverse array index and N_OF_X for each iteration:
FLD X_ARRAY[SI]
FADD ST(3),ST
FLD ST
FMUL ST,ST
FADDP ST(2),ST
FIMUL N_OF_X
FADDP ST(2),ST
; after the original CPU loop:
FSTP SUM_SQUARES
FSTP SUM_INDEXES
FSTP SUM_X
```

The OCR misreads `F` as `P` and `3` as `5`; the stack diagram and running-sum
layout identify ST(3). Eight fixture values exercise the original CW; all
three stored results and final empty tags are checked. CPU loop/index
instructions are supplied by the harness: this is an original numeric
program replay, **not execution of an unchanged binary on an 8086**.
