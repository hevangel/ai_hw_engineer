# Verilator Overview

Source: [veripool.org/guide/latest/](https://veripool.org/guide/latest/)

## What is Verilator?

Verilator converts Verilog and SystemVerilog hardware description language (HDL) designs into a C++ or SystemC model that, after compiling, can be executed. Verilator is not a traditional simulator but a **compiler**.

## How It Works

1. **Verilating**: The `verilator` executable reads SystemVerilog code, lints it, optionally adds coverage and waveform tracing support, and compiles the design into a source-level multithreaded C++ or SystemC "model". Output is `.cpp` and `.h` files.

2. **Wrapper**: A small user-written C++ wrapper defines `main()` and instantiates the Verilated model as a C++/SystemC object.

3. **Compilation**: The wrapper, Verilator-generated files, and the runtime library are compiled with a C++ compiler to create a simulation executable.

4. **Simulation**: The executable performs the actual simulation.

5. **Analysis**: The executable may generate waveform traces and coverage data.

## Key Characteristics

- **Cycle-accurate**: Models the design at cycle-level granularity
- **Synthesizable subset**: Supports synthesizable Verilog/SystemVerilog plus some verification constructs
- **Performance**: Generally 10-100x faster than interpreted simulators for synthesizable designs
- **Multithreaded**: Supports parallel simulation with `--threads N`
- **Open source**: LGPL-3.0 or Artistic-2.0 license

## Supported Language Features

- All synthesizable SystemVerilog constructs
- Most verification constructs
- Intra-assignment delays (e.g., `#10`)
- Events
- Limited tristate-bus (z) and unknown (x) handling
- Assertions (with some limitations)
- DPI-C interface
- Constrained randomization (with Z3 solver)

## Output Modes

| Option | Description |
|--------|-------------|
| `--binary` | Translate + compile into executable |
| `--cc` | Generate C++ code |
| `--sc` | Generate SystemC code |
| `--lint-only` | Lint without generating output |
| `--json-only` | Generate JSON for external tools |
| `-E` | Preprocess only |

## Typical Use Case

```bash
# Verilate the design
verilator --binary --trace -j 0 -Wall design.sv sim_main.cpp

# Run the simulation
./obj_dir/Vdesign

# View waveforms
surfer dump.vcd
```
