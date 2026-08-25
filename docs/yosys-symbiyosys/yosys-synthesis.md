# Yosys Synthesis Flows

Source: [yosyshq.readthedocs.io/projects/yosys/en/latest/using_yosys/synthesis/](https://yosyshq.readthedocs.io/projects/yosys/en/latest/using_yosys/synthesis/)

## Synthesis Flow Structure

Synthesis breaks into coarse-grain and fine-grain phases:

```
Read → Elaborate → Coarse Optimization → Technology Mapping → Fine Optimization → Write
```

## Common Synthesis Script Template

```tcl
# Read design
read_verilog -sv rtl/top.sv
read_verilog -sv rtl/sub.sv

# Elaborate
hierarchy -top top -check

# Process behavioral code
proc

# Flatten hierarchy (optional)
flatten

# Coarse-grain optimization
opt -full
fsm -norecode
opt
memory -nomap
opt

# Technology mapping
techmap
abc -liberty cells.lib

# Fine-grain cleanup
opt_clean
write_verilog -noattr synth_output.v
```

## FPGA Synthesis (Built-in Flows)

### iCE40
```tcl
read_verilog design.v
synth_ice40 -top top -json output.json
```

### ECP5
```tcl
read_verilog design.v
synth_ecp5 -top top -json output.json
```

### Xilinx
```tcl
read_verilog design.v
synth_xilinx -top top -family xc7
write_edif output.edif
```

### Intel/Altera
```tcl
read_verilog design.v
synth_intel_alm -top top -family cyclonev
```

### Gowin
```tcl
read_verilog design.v
synth_gowin -top top
write_verilog -noattr output.v
```

## ASIC Synthesis (Standard Cell)

```tcl
# Read RTL
read_verilog -sv design.sv
hierarchy -top top

# Synthesis
proc
opt
fsm
opt
memory
opt
techmap
opt

# Map to standard cell library
dfflibmap -liberty cells.lib
abc -liberty cells.lib
opt_clean

# Write gate-level netlist
write_verilog -noattr gate_level.v
stat
```

### Liberty File (.lib)

Yosys reads Liberty format cell libraries:
```tcl
# Map flip-flops
dfflibmap -liberty mylib.lib

# Map combinational logic
abc -liberty mylib.lib
```

## Key Synthesis Commands

| Command | Description |
|---------|-------------|
| `hierarchy` | Manage design hierarchy |
| `proc` | Convert processes to netlists |
| `flatten` | Flatten design hierarchy |
| `opt` | Perform general optimizations |
| `opt_clean` | Remove unused signals/cells |
| `fsm` | Extract and optimize FSMs |
| `memory` | Map memories to cells |
| `techmap` | Map to technology primitives |
| `abc` | ABC logic optimization |
| `dfflibmap` | Map flip-flops to library |
| `stat` | Print design statistics |

## Optimization Passes

```tcl
# Full optimization
opt -full

# Individual passes
opt_expr      # Constant folding
opt_merge     # Merge identical cells
opt_reduce    # Reduce MUX/logic
opt_clean     # Remove unused
opt_share     # Share arithmetic
```

## Memory Inference

```tcl
# Automatic memory inference
memory

# Or step by step:
memory_dff       # Merge DFFs into memory read ports
memory_bram      # Map to block RAM
memory_map       # Map remaining to DFFs
```

## Reports

```tcl
# Print statistics
stat

# Print timing estimate (with liberty file)
sta

# Check design
check
```

## Scripting with Yosys

```bash
# Run script file
yosys -s script.ys

# Run inline command
yosys -p "synth_ice40 -top top" design.v

# Batch multiple commands
yosys -p "read_verilog a.v; read_verilog b.v; synth_ice40 -top top"

# With tcl
yosys -c script.tcl
```
