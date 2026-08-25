# Verilator Waveforms and Coverage

## Waveform Tracing

### VCD Tracing

```bash
verilator --binary --trace top.sv
./obj_dir/Vtop
# Produces dump.vcd (or as configured in wrapper)
```

In C++ wrapper:
```cpp
#include "verilated_vcd_c.h"

Verilated::traceEverOn(true);
VerilatedVcdC* tfp = new VerilatedVcdC;
top->trace(tfp, 99);  // Trace 99 levels of hierarchy
tfp->open("dump.vcd");

// In simulation loop:
tfp->dump(sim_time);

// At end:
tfp->close();
```

### FST Tracing (Compressed, Faster)

```bash
verilator --binary --trace-fst top.sv
```

In C++ wrapper:
```cpp
#include "verilated_fst_c.h"

Verilated::traceEverOn(true);
VerilatedFstC* tfp = new VerilatedFstC;
top->trace(tfp, 99);
tfp->open("dump.fst");
```

FST is GTKWave's binary format — smaller files and faster writing than VCD.

### Trace Options

| Option | Description |
|--------|-------------|
| `--trace` | Enable VCD tracing |
| `--trace-fst` | Enable FST tracing |
| `--trace-depth <N>` | Limit trace depth |
| `--trace-max-array <N>` | Max array depth to trace |
| `--trace-max-width <N>` | Max signal width to trace |
| `--trace-underscore` | Trace signals starting with underscore |
| `--trace-structs` | Show struct member names |

### Viewing Waveforms

```bash
# Surfer (recommended, modern)
surfer dump.vcd
surfer dump.fst

# GTKWave (classic)
gtkwave dump.vcd
gtkwave dump.fst
```

## Coverage

### Types of Coverage

| Type | Flag | Description |
|------|------|-------------|
| Line | `--coverage-line` | Which lines executed |
| Toggle | `--coverage-toggle` | Signal toggle counting |
| User | `--coverage-user` | User-inserted cover points |
| All | `--coverage` | All coverage types |

### Collecting Coverage

```bash
# Build with coverage
verilator --binary --coverage top.sv
./obj_dir/Vtop

# Produces coverage.dat in current directory
```

### Analyzing Coverage

```bash
# Annotate source with coverage data
verilator_coverage --annotate logs/annotated coverage.dat

# Write coverage info
verilator_coverage --write-info merged.info coverage.dat

# Rank tests by coverage contribution
verilator_coverage --rank coverage1.dat coverage2.dat
```

### Coverage in SystemVerilog

```systemverilog
// Cover point (user coverage)
always @(posedge clk) begin
    cover property (req && gnt);
end

// Cover group
covergroup cg @(posedge clk);
    cp_state: coverpoint state;
endgroup
```

### Merging Coverage

```bash
# Multiple simulation runs
./obj_dir/Vtop +coverage_file=run1.dat
./obj_dir/Vtop +coverage_file=run2.dat

# Merge
verilator_coverage --write merged.dat run1.dat run2.dat
```

## Best Practices

1. Use `--trace-fst` for large designs (smaller, faster)
2. Use `--trace-depth` to limit what gets traced
3. Enable tracing conditionally in simulation via plusarg
4. Run multiple seeds for coverage, then merge
5. Target >95% line coverage, >80% toggle coverage for tapeout quality
