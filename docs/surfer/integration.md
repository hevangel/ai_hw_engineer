# Surfer Integration with Simulation Tools

## Supported Waveform Formats

| Format | Extension | Source | Notes |
|--------|-----------|--------|-------|
| VCD | `.vcd` | IEEE standard | Universal, text-based, large files |
| FST | `.fst` | GTKWave | Binary, compressed, recommended |
| GHW | `.ghw` | GHDL | VHDL simulation |

## Generating Waveforms

### Xezim

```bash
# VCD (via $dumpfile/$dumpvars in design)
xezim --simulate -s top design.sv

# FST (binary, compressed)
xezim --simulate -s top design.sv --fst output.fst
xezim --simulate -s top design.sv --fst-scope top.dut output.fst

# XTrace (xezim native format)
xezim --simulate -s top design.sv --xtrace output.xtrace.zst
```

### Verilator

```bash
# VCD
verilator --binary --trace top.sv
./obj_dir/Vtop

# FST (recommended)
verilator --binary --trace-fst top.sv
./obj_dir/Vtop
```

C++ wrapper for FST:
```cpp
#include "verilated_fst_c.h"
VerilatedFstC* tfp = new VerilatedFstC;
top->trace(tfp, 99);
tfp->open("output.fst");
// ... tfp->dump(time) in loop ...
tfp->close();
```

### Icarus Verilog

```verilog
// In testbench
initial begin
  $dumpfile("output.vcd");
  $dumpvars(0, tb_top);
end
```

For FST output:
```bash
vvp -lxt2 sim_output  # Produces LXT2 (GTKWave can convert to FST)
```

### GHDL

```bash
ghdl -r testbench --wave=output.ghw
```

## Viewing Generated Waveforms

```bash
# Simple usage
surfer output.fst
surfer output.vcd

# Web version (no install needed)
# Open https://app.surfer-project.org and drag file
```

## Format Comparison

| Aspect | VCD | FST |
|--------|-----|-----|
| File size | Large (text) | Small (compressed) |
| Write speed | Moderate | Fast |
| Load speed | Moderate | Fast |
| Compatibility | Universal | GTKWave/Surfer |
| Human readable | Yes | No |
| Recommended | Small designs | Large designs |

## Workflow

```
Simulation (xezim/Verilator/iverilog)
    ↓
Waveform dump (.vcd / .fst)
    ↓
Surfer waveform viewer
    ↓
Debug and iterate
```

## Tips for Large Designs

1. **Use FST** — 10-50x smaller than VCD for large designs
2. **Limit scope** — Only trace signals you need (`--fst-scope`, `--trace-depth`)
3. **Conditional tracing** — Enable trace via plusarg only when debugging
4. **Split runs** — Short focused simulations for waveform, long runs for coverage

```systemverilog
// Conditional VCD dump controlled by plusarg
initial begin
  if ($test$plusargs("trace")) begin
    $dumpfile("trace.vcd");
    $dumpvars(0, top);
  end
end
```
