# Yosys Overview

Source: [yosyshq.readthedocs.io/projects/yosys/](https://yosyshq.readthedocs.io/projects/yosys/en/latest/)

## What is Yosys?

Yosys is an open-source framework for RTL synthesis. It reads Verilog/SystemVerilog designs, performs logic optimization, and maps to target technology libraries (FPGA cells or ASIC standard cells).

## Key Features

- Full Verilog-2005 and partial SystemVerilog support
- FPGA synthesis for iCE40, ECP5, Gowin, Xilinx, Intel/Altera
- ASIC synthesis to standard cell libraries (Liberty format)
- Formal verification preparation (generates models for SymbiYosys)
- Extensible pass-based architecture
- Script-driven synthesis flows
- Built-in ABC integration for gate-level optimization
- JSON, BLIF, EDIF, and other netlist formats

## Synthesis Flow Overview

```
RTL Source → Parse → Elaborate → Coarse-Grain Optimize → Map to Technology → Fine-Grain Optimize → Output
```

Phases:
1. **Read**: Parse Verilog/SystemVerilog source
2. **Elaborate**: Resolve hierarchy, parameters, generates
3. **Coarse-grain synthesis**: High-level transforms (FSM extraction, memory mapping, MUX trees)
4. **Technology mapping**: Map to target cells (LUTs, DSPs, BRAMs, or std cells)
5. **Fine-grain optimization**: Gate-level optimization via ABC
6. **Output**: Write netlist in target format

## Basic Usage

```bash
# Interactive mode
yosys

# Script mode
yosys -s synth_script.ys

# One-liner
yosys -p "read_verilog design.v; synth_ice40 -top top; write_json design.json"
```

## Example Synthesis Script

```tcl
# synth.ys
read_verilog rtl/top.v
read_verilog rtl/sub.v

# Elaborate
hierarchy -top top

# Coarse-grain synthesis
proc
flatten
opt
fsm
opt
memory
opt

# Technology mapping (iCE40 FPGA)
synth_ice40 -top top

# Write output
write_json output.json
write_verilog -noattr output.v
```

## RTLIL — Internal Representation

Yosys uses RTLIL (Register Transfer Level Intermediate Language) internally. Key concepts:
- **Module**: Container for logic
- **Wire**: Signal/bus
- **Cell**: Logic primitive or instantiation
- **Process**: Behavioral logic (before `proc` pass converts to cells)
- **Memory**: Array storage (before `memory` pass converts to cells)

## Integration with Formal Verification

Yosys prepares designs for SymbiYosys formal verification:

```tcl
read_verilog -formal design.v
prep -top top
```

The `prep` command runs a minimal synthesis suitable for formal analysis (without technology mapping).
