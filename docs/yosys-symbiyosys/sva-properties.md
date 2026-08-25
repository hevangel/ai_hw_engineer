# SVA Properties for Formal Verification

Source: [yosyshq.readthedocs.io/projects/sby/en/latest/verilog.html](https://yosyshq.readthedocs.io/projects/sby/en/latest/verilog.html)

## Basic Assertion Types

### assume(expr)

Restricts the input space — solver only considers traces where assumptions hold.

```systemverilog
always @(posedge clk)
  assume(req |-> ##[1:3] gnt);
```

### assert(expr)

Property the solver tries to disprove. Proof fails if any reachable state violates it.

```systemverilog
always @(posedge clk)
  assert(state != INVALID);
```

### cover(expr)

Used in cover mode — solver finds a trace reaching the covered state.

```systemverilog
always @(posedge clk)
  cover(fifo_full && write_en);
```

## Assertion Contexts

### Combinational (always @(*))

Checked every time step:
```systemverilog
always @(*)
  assert(!error_flag);
```

### Clocked (always @(posedge clk))

Checked on clock edge — required for `$past` and related functions:
```systemverilog
always @(posedge clk)
  assert(count == $past(count) + 1);
```

**Important**: Clocked assertions check the condition at the *next* clock edge, not the current time step.

## SystemVerilog Functions

| Function | Description |
|----------|-------------|
| `$past(expr)` | Value of expr one clock ago |
| `$past(expr, N)` | Value of expr N clocks ago |
| `$stable(expr)` | `expr == $past(expr)` |
| `$changed(expr)` | `expr != $past(expr)` |
| `$rose(expr)` | `expr && !$past(expr)` (LSB only) |
| `$fell(expr)` | `!expr && $past(expr)` (LSB only) |

**Note**: `$past` has no initial value — use `$past` only after the first clock.

## Unconstrained Variables (Formal Attributes)

### anyconst — Solver-chosen constant
```systemverilog
(* anyconst *) reg [7:0] addr;
// Solver picks one constant value for addr
// Useful for memory verification
```

### anyseq — Solver-chosen sequence
```systemverilog
(* anyseq *) reg [7:0] data_in;
// Solver picks a different value each cycle
// Like a free input
```

### allconst / allseq — Universal quantification
```systemverilog
(* allconst *) reg [3:0] idx;
// Property must hold for ALL values of idx
```

## Multi-Clock Designs

Enable with `multiclock on` in .sby options.

```systemverilog
(* gclk *) reg formal_timestep;

always @(posedge formal_timestep)
  assume(clk_a == !$past(clk_a));  // Define clock_a behavior
```

## Common Patterns

### Reset Handling

```systemverilog
reg [2:0] cycle_count = 0;
always @(posedge clk)
  cycle_count <= cycle_count + (cycle_count != 3'h7);

// Only check after reset
always @(posedge clk)
  if (cycle_count > 3)
    assert(data_valid |-> data != 0);

// Assume reset pattern
initial assume(rst);
always @(posedge clk)
  if (cycle_count < 2)
    assume(rst);
  else
    assume(!rst);
```

### FIFO Verification

```systemverilog
`ifdef FORMAL
  // Track fill level
  reg [DEPTH_W:0] f_fill;
  always @(posedge clk)
    if (rst) f_fill <= 0;
    else f_fill <= f_fill + write_en - read_en;

  // Never overflow
  assert property (@(posedge clk)
    f_fill <= DEPTH);

  // Never underflow
  assert property (@(posedge clk)
    f_fill >= 0);

  // Full flag correct
  assert property (@(posedge clk)
    full == (f_fill == DEPTH));

  // Empty flag correct
  assert property (@(posedge clk)
    empty == (f_fill == 0));

  // Data integrity with anyconst
  (* anyconst *) reg [DEPTH_W-1:0] f_addr;
  reg [DATA_W-1:0] f_data;
  reg f_valid = 0;
  // ... track write/read of f_addr slot
`endif
```

### Handshake Protocol

```systemverilog
`ifdef FORMAL
  // Valid must stay high until ready
  assert property (@(posedge clk)
    disable iff (rst)
    valid && !ready |=> valid);

  // Data must be stable while valid and not ready
  assert property (@(posedge clk)
    disable iff (rst)
    valid && !ready |=> $stable(data));

  // No valid during reset
  assert property (@(posedge clk)
    rst |-> !valid);
`endif
```

### Memory Verification

```systemverilog
`ifdef FORMAL
  (* anyconst *) reg [ADDR_W-1:0] f_addr;
  reg [DATA_W-1:0] f_shadow;
  reg f_written = 0;

  always @(posedge clk) begin
    if (we && waddr == f_addr) begin
      f_shadow <= wdata;
      f_written <= 1;
    end
    if (f_written && re && raddr == f_addr)
      assert(rdata == f_shadow);
  end
`endif
```

## Best Practices

1. **Always wrap formal code in `` `ifdef FORMAL ``** — keeps it out of synthesis
2. **Assume reset** at the beginning — `initial assume(rst);`
3. **Use $past only in clocked blocks** — it needs a clock reference
4. **Don't over-constrain** — too many assumptions can hide bugs
5. **Start with BMC** (bounded) before attempting prove (unbounded)
6. **Use cover to verify liveness** — make sure interesting states are reachable
7. **Use anyconst for address verification** — proves properties for all addresses with one proof
