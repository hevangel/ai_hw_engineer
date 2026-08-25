# SymbiYosys Overview

Source: [yosyshq.readthedocs.io/projects/sby/](https://yosyshq.readthedocs.io/projects/sby/en/latest/)

## What is SymbiYosys?

SymbiYosys (sby) is a front-end driver program for Yosys-based formal hardware verification flows. It orchestrates:
- Design reading (via Yosys)
- Model generation
- Solver invocation
- Result reporting and trace generation

## Verification Modes

| Mode | Purpose |
|------|---------|
| `bmc` | Bounded Model Checking — find assertion violations within N cycles |
| `prove` | Unbounded proof — prove assertions hold for all time (k-induction) |
| `cover` | Find traces that reach `cover()` statements |
| `live` | Verify liveness properties (`assert(s_eventually ...)`) |

## Quick Start

### 1. Add assertions to your design

```systemverilog
module counter(input clk, rst, output reg [7:0] count);
  always @(posedge clk)
    if (rst) count <= 0;
    else count <= count + 1;

  // Formal properties
  `ifdef FORMAL
    always @(posedge clk) begin
      if (!rst && $past(!rst))
        assert(count == $past(count) + 1);
    end

    // Assumption: reset is active for first cycle
    initial assume(rst);
  `endif
endmodule
```

### 2. Create .sby configuration file

```ini
[options]
mode bmc
depth 20

[engines]
smtbmc z3

[script]
read -formal counter.v
prep -top counter

[files]
counter.v
```

### 3. Run SymbiYosys

```bash
sby counter.sby
```

Output: `PASS` or `FAIL` with counter-example VCD trace.

## How It Works

1. SymbiYosys reads the `.sby` file
2. Copies source files to a working directory
3. Runs the Yosys script to elaborate and prepare the design
4. Generates formal models (SMT2, BTOR2, or AIGER depending on engine)
5. Invokes the solver engine
6. Reports results and generates counter-example traces (VCD/FST)

## Engine Options

| Engine | Best For |
|--------|----------|
| `smtbmc z3` | General purpose, good default |
| `smtbmc yices` | Often faster for BMC |
| `smtbmc bitwuzla` | Good for bitvector-heavy designs |
| `abc pdr` | Fast unbounded proofs (prove mode) |
| `aiger suprove` | Liveness proofs |
| `btor btormc` | BTOR2-native model checking |

## Workflow Integration

```bash
# Run all tasks defined in .sby
sby design.sby

# Run specific task
sby design.sby task_name

# Continue on failure (for CI)
sby --prefix output_dir design.sby || true

# Check results
cat output_dir/status
```
