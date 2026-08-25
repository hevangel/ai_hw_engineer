# Yosys Command Reference

Source: [yosyshq.readthedocs.io/projects/yosys/en/latest/](https://yosyshq.readthedocs.io/projects/yosys/en/latest/)

## Input/Output

| Command | Description |
|---------|-------------|
| `read_verilog [-sv] <file>` | Read Verilog/SystemVerilog |
| `read_liberty <file>` | Read Liberty cell library |
| `read_blif <file>` | Read BLIF netlist |
| `write_verilog [-noattr] <file>` | Write Verilog netlist |
| `write_json <file>` | Write JSON netlist |
| `write_blif <file>` | Write BLIF netlist |
| `write_edif <file>` | Write EDIF netlist |
| `write_smt2 <file>` | Write SMT2 (for formal) |
| `write_btor <file>` | Write BTOR2 (for formal) |
| `write_aiger <file>` | Write AIGER (for formal) |

## Design Elaboration

| Command | Description |
|---------|-------------|
| `hierarchy -top <name>` | Set top module, resolve hierarchy |
| `hierarchy -check` | Check for missing modules |
| `proc` | Convert processes to logic |
| `flatten` | Flatten design hierarchy |
| `tribuf` | Handle tristate buffers |
| `deminout` | Handle inout ports |

## Optimization

| Command | Description |
|---------|-------------|
| `opt` | Run all standard optimizations |
| `opt -full` | Full optimization pass |
| `opt_expr` | Constant folding, expression simplification |
| `opt_merge` | Merge identical cells |
| `opt_reduce` | Reduce logic width |
| `opt_clean` | Remove unused wires/cells |
| `opt_share` | Resource sharing |
| `opt_dff` | DFF optimization |
| `opt_lut` | LUT optimization |
| `wreduce` | Reduce word sizes |
| `peepopt` | Peephole optimization |
| `share` | Resource sharing |
| `alumacc` | Extract ALU/MAC structures |

## FSM and Memory

| Command | Description |
|---------|-------------|
| `fsm` | Full FSM extraction and optimization |
| `fsm_detect` | Detect FSMs |
| `fsm_extract` | Extract FSMs |
| `fsm_opt` | Optimize FSMs |
| `fsm_recode` | Recode FSM states |
| `memory` | Full memory handling |
| `memory_dff` | Merge DFFs into memory |
| `memory_bram` | Map to block RAM |
| `memory_map` | Map to DFFs |

## Technology Mapping

| Command | Description |
|---------|-------------|
| `techmap` | Generic technology mapping |
| `abc` | ABC logic synthesis/optimization |
| `abc -liberty <lib>` | Map to standard cells |
| `abc -lut <N>` | Map to N-input LUTs |
| `dfflibmap -liberty <lib>` | Map flip-flops to library |
| `iopadmap` | Insert I/O pads |

## Built-in Synthesis Targets

| Command | Target |
|---------|--------|
| `synth` | Generic synthesis |
| `synth_ice40` | Lattice iCE40 |
| `synth_ecp5` | Lattice ECP5 |
| `synth_xilinx` | AMD/Xilinx 7-series+ |
| `synth_intel_alm` | Intel ALM-based FPGAs |
| `synth_gowin` | Gowin FPGAs |
| `synth_anlogic` | Anlogic FPGAs |
| `synth_achronix` | Achronix FPGAs |

## Analysis and Reporting

| Command | Description |
|---------|-------------|
| `stat` | Print design statistics |
| `check` | Check design for obvious issues |
| `show` | Graphical display of design |
| `dump` | Dump design in RTLIL format |
| `select` | Select parts of design |
| `ls` | List design objects |
| `cd` | Change current module |

## Formal Verification Support

| Command | Description |
|---------|-------------|
| `read -formal <file>` | Read with formal extensions |
| `prep -top <name>` | Prepare for formal (no tech mapping) |
| `assertpmux` | Convert assertions |
| `formalff` | Handle formal flip-flop initialization |
| `async2sync` | Convert async resets for formal |

## Scripting

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `help <cmd>` | Show help for command |
| `echo <msg>` | Print message |
| `log <msg>` | Log message |
| `tee <file> <cmd>` | Redirect output to file |
| `script <file>` | Execute script file |
| `shell` | Drop to system shell |

## Selection Syntax

```tcl
# Select by type
select t:$add         # All adder cells
select w:data*        # Wires matching pattern
select m:cpu          # Module named cpu

# Boolean operations
select -set A t:$dff
select -set B w:clk
select @A %ci @B      # Cells connected to clk

# Use selection
opt_clean @A          # Clean only selected
```
