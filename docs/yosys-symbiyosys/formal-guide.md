# Practical Formal Verification Guide

## What is Formal Verification?

Formal verification mathematically proves that a design satisfies its specification for all possible inputs and states — unlike simulation which only tests specific scenarios.

## When to Use Formal

| Use Case | Formal Advantage |
|----------|-----------------|
| Protocol compliance | Exhaustive input coverage |
| Control logic | Find corner cases simulation misses |
| Arithmetic correctness | All possible operand values |
| FSM properties | Prove no illegal transitions |
| Interface handshakes | Verify ready/valid protocols |
| Memory coherence | Prove read-after-write correctness |
| Security properties | No information leakage paths |

## Workflow

```
1. Write RTL
2. Add formal properties (assertions, assumptions, covers)
3. Create .sby file
4. Run sby — iterate until PASS
5. Review cover traces to confirm properties are meaningful
```

## Step-by-Step Example

### 1. RTL Design

```systemverilog
// arbiter.sv
module arbiter #(parameter N = 4) (
  input  logic        clk, rst,
  input  logic [N-1:0] req,
  output logic [N-1:0] gnt
);
  logic [N-1:0] gnt_r;
  assign gnt = gnt_r;

  always_ff @(posedge clk) begin
    if (rst) begin
      gnt_r <= '0;
    end else begin
      gnt_r <= '0;
      for (int i = 0; i < N; i++)
        if (req[i] && gnt_r == '0)
          gnt_r[i] <= 1'b1;
    end
  end
endmodule
```

### 2. Formal Properties

```systemverilog
// arbiter_formal.sv
module arbiter_formal;
  parameter N = 4;

  logic clk, rst;
  logic [N-1:0] req, gnt;

  arbiter #(.N(N)) dut (.*);

  // Clock generation
  always #5 clk = ~clk;
  initial clk = 0;

  // Reset assumption
  initial assume(rst);
  always @(posedge clk)
    if ($past(rst))
      assume(!rst);

  // === ASSERTIONS ===

  // At most one grant at a time (mutex)
  always @(posedge clk)
    assert($onehot0(gnt));

  // Grant implies request
  always @(posedge clk)
    assert((gnt & ~req) == '0 || rst);

  // No grant during reset
  always @(posedge clk)
    if (rst) assert(gnt == '0);

  // === COVER ===
  // Can grant each port
  generate
    for (genvar i = 0; i < N; i++)
      always @(posedge clk)
        cover(!rst && gnt[i]);
  endgenerate

  // Can have all requests simultaneously
  always @(posedge clk)
    cover(req == '1 && !rst);
endmodule
```

### 3. .sby Configuration

```ini
[tasks]
bmc
prove
cover

[options]
bmc: mode bmc
bmc: depth 30
prove: mode prove
prove: depth 30
cover: mode cover
cover: depth 20

[engines]
bmc: smtbmc z3
prove: abc pdr
cover: smtbmc z3

[script]
read -formal arbiter.sv
read -formal arbiter_formal.sv
prep -top arbiter_formal

[files]
arbiter.sv
arbiter_formal.sv
```

### 4. Run

```bash
sby arbiter.sby
# Runs all tasks: bmc, prove, cover
```

### 5. View Counter-Example (on failure)

```bash
surfer arbiter_bmc/engine_0/trace.vcd
```

## Proof Strategies

### Bounded Model Checking (BMC)

- Checks N cycles from initial state
- Fast but incomplete — only finds bugs within depth
- Good first step: find bugs quickly

```ini
[options]
mode bmc
depth 50
```

### K-Induction (Prove)

- Proves property holds for ALL time
- Two steps: base case + inductive step
- May need helper assertions (invariants) to strengthen induction

```ini
[options]
mode prove
depth 30
```

### PDR (Property Directed Reachability)

- Often faster than k-induction for proofs
- Does not need depth parameter
- Cannot produce bounded counter-examples

```ini
[engines]
abc pdr
```

## Common Pitfalls

### 1. Over-constraining

Too many assumptions can make the proof vacuous. Always run cover mode to verify interesting traces exist.

### 2. Induction Failure

If prove mode gives "UNKNOWN", the property may need strengthening:
- Add helper invariants (additional assertions)
- Constrain initial state more precisely
- Use BMC first to find actual bugs

### 3. State Space Explosion

Large designs may timeout. Strategies:
- Reduce depth
- Use `--syn` to simplify
- Try different solvers (yices often faster for BMC)
- Decompose into smaller sub-proofs
- Use `abc pdr` for prove mode

### 4. Clock Domain Issues

Multi-clock designs need `multiclock on`:
```ini
[options]
multiclock on
```

## Integration with CI

```bash
#!/bin/bash
# formal_check.sh
set -e
for sby_file in formal/*.sby; do
  echo "=== Running $sby_file ==="
  sby -f "$sby_file"
done
echo "All formal proofs PASSED"
```

## Formal vs. Simulation

| Aspect | Formal | Simulation |
|--------|--------|-----------|
| Coverage | Exhaustive (all inputs) | Sample-based |
| Depth | Limited cycles | Unlimited |
| Speed | Exponential in state bits | Linear in time |
| Debugging | Counter-example trace | Waveform |
| Scalability | Small-medium blocks | Any size |
| Setup | Properties + .sby | Testbench + stimulus |

## Recommended Approach

1. **Block-level formal** — prove each module's interface properties
2. **Integration simulation** — verify system-level behavior
3. **Cover in formal** — ensure properties are reachable (not vacuously true)
4. **Regression** — run formal proofs in CI alongside simulation
