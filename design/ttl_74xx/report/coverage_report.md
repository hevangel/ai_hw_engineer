# Functional Coverage Report: alu_74181

Date: 2026-08-24

## Coverage Model

The DUT has 14 functional input bits: `A[3:0]`, `B[3:0]`, `S[3:0]`, `M`, and active-LOW `Cn`. The procedural xezim regression enumerates the complete `2^14 = 16,384` input space and compares five output fields (`F`, `Cn+4`, `A=B`, `P_bar`, and `G_bar`) against the normalized datasheet golden table as coded separately from the structural RTL.

| Coverage item | Hit | Total | Result |
|---|---:|---:|---|
| Complete functional input vectors | 16,384 | 16,384 | 100% |
| Output-field comparisons | 81,920 | 81,920 | 100% pass |
| `(M,S,Cn)` bins | 64 | 64 | 100% |
| A/B pairs within every `(M,S,Cn)` bin | 256 | 256 | 100% |
| Logic selectors | 16 | 16 | 100% |
| Arithmetic selectors | 16 | 16 | 100% |
| Carry-input states per selector/mode | 2 | 2 | 100% |

Final xezim result:

```text
74181 exhaustive result: 16384 vectors, 81920 field checks,
Failures: 0 vectors, 0 fields
TEST PASSED
```

## UVM Functional Smoke Coverage

The IEEE 1800.2-2017 UVM sequence separately drove every `(M,S,Cn)` combination using deterministic nontrivial A/B patterns. Its scoreboard re-implements the same normalized datasheet golden table used by the exhaustive and formal environments. The monitor and scoreboard checked exactly 64 transactions.

```text
Checked 64 selector/mode/carry transactions
UVM_ERROR : 0
UVM_FATAL : 0
```

The Accellera library emits 23 known false `UVM/COMP/NAME` warnings under `UVM_NO_DPI`; its own diagnostic states that the component-name checker requires DPI. These warnings do not represent missing transactions or DUT failures.

## Formal Reachability

SymbiYosys cover mode reached all 10 requested cover statements, including both modes and active/inactive states for `Cn+4`, `P_bar`, `G_bar`, and `A=B`.

## Code Coverage

Line/toggle instrumentation was not used. Exhaustive functional input coverage is stronger for this small, purely combinational design: every legal binary input assignment is evaluated. There are no clocks, states, FSMs, memories, or reset branches in the DUT.
