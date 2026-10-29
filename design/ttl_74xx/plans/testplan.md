# Test Plan: alu_74181

## Scope

Verify the active-HIGH SN74LS181 function table and all externally visible combinational outputs. Analog voltage, package, fan-out, and propagation-delay characteristics are outside RTL simulation scope.

## Reference Model

The scoreboards use the same normalized datasheet golden table, independently coded in each verification environment rather than imported from the RTL. This provides structural independence from the DUT equations, but not specification independence between simulation, UVM, and formal; a shared datasheet transcription error remains a review risk.

- Logic mode: a 16-entry `case (s)` implements TI table 1.
- Arithmetic mode: a 16-entry 5-bit base-expression table models the `Cn=1` column; `~cn` is then added as the active-HIGH carry input.
- `cn4` is the inverse of arithmetic bit 4 and is inactive in logic mode.
- `p_bar` and `g_bar` are calculated from independently selected per-bit X/Y truth tables.
- `a_eq_b` is checked as the reduction AND of expected `f`.

## Testbench Layers

### Exhaustive procedural regression

Iterate every combination:

```text
16 A values × 16 B values × 16 S values × 2 M values × 2 Cn values
= 16,384 vectors
```

For every vector, compare `f`, `cn4`, `p_bar`, `g_bar`, and `a_eq_b` with 4-state case inequality. Any mismatch ends with `$fatal`; success reports exact vector and output-check counts.

### UVM 1800.2-2017 smoke regression

Use a transaction, sequence, sequencer, driver, monitor, scoreboard, environment, and test selected by `+UVM_TESTNAME=alu_74181_all_modes_test`. Drive all 64 `(M,S,Cn)` combinations with deterministic nontrivial operand patterns. The scoreboard must receive exactly 64 transactions and report zero UVM errors/fatals.

## Coverage Matrix

| Feature | Exhaustive target | UVM smoke target |
|---|---:|---:|
| Logic selectors | 16/16 | 16/16 |
| Arithmetic selectors | 16/16 | 16/16 |
| `Cn` states per selector/mode | 2/2 | 2/2 |
| A/B pairs | 256/256 for every S/M/Cn | Directed patterns |
| `f` comparison | Every vector | Every transaction |
| `cn4` comparison | Every vector | Every transaction |
| `p_bar`, `g_bar` comparison | Every vector | Every transaction |
| `a_eq_b` comparison | Every vector | Every transaction |
| Logic carry independence | Exhaustive through both Cn states | Both Cn states |

## Corner Cases

- All-zero and all-one operands.
- Addition overflow and no overflow.
- Subtraction with and without borrow.
- Constant-zero, constant-one, minus-one, increment, decrement, and double-A selectors.
- Group generate and group propagate active/inactive.
- `f == 4'hf` and `f != 4'hf` comparator cases.

## Pass/Fail Criteria

- Exhaustive simulation: 16,384/16,384 vectors and 81,920/81,920 output fields pass; process exits zero only on success.
- UVM smoke: 64/64 transactions checked, `UVM_ERROR : 0`, `UVM_FATAL : 0`.
- No simulator timeout, unknown output, or skipped selector/carry combination.
