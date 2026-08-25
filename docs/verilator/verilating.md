# Verilating — Compiling Designs with Verilator

Source: [veripool.org/guide/latest/verilating.html](https://veripool.org/guide/latest/verilating.html)

## Basic Usage

```bash
# Generate C++ and compile to binary
verilator --binary -j 0 -Wall top.sv

# Generate C++ only (for manual compilation)
verilator --cc top.sv

# Generate SystemC
verilator --sc top.sv

# Lint only
verilator --lint-only top.sv
```

## Common Workflow

```bash
# 1. Verilate with tracing and optimization
verilator --binary --trace -j 0 -O3 -Wall \
  --top-module chip_top \
  -I./rtl -I./includes \
  rtl/chip_top.sv rtl/submodule.sv \
  sim_main.cpp

# 2. Run simulation
./obj_dir/Vchip_top +trace

# 3. View waveforms
surfer waveform.vcd
```

## Key Options

| Option | Description |
|--------|-------------|
| `--binary` | Generate C++ and compile to executable |
| `--cc` | Generate C++ model |
| `--sc` | Generate SystemC model |
| `--build` | Build after generating (implicit with `--binary`) |
| `--top-module <name>` | Specify top module |
| `-j <N>` | Parallel jobs (0 = auto-detect cores) |
| `-O0` to `-O3` | Optimization level |
| `--trace` / `--trace-fst` | Enable VCD/FST waveform tracing |
| `--coverage` | Enable coverage collection |
| `--assert` | Enable assertions |
| `-Wall` | Enable all warnings |
| `--Mdir <dir>` | Output directory (default: `obj_dir`) |
| `--prefix <name>` | Output file prefix |
| `--threads <N>` | Enable multithreaded model |
| `-I<dir>` | Add include search path |
| `-D<macro>[=value]` | Define preprocessor macro |
| `-f <file>` | Read options from file |
| `--exe` | Link user executable (with --cc/--sc) |
| `--main` | Generate default main() |

## Top Module Selection

Verilator determines "top modules" — modules not instantiated under other cells:
- If `--top-module` is used, that determines the top
- Otherwise, Verilator auto-detects (warns with MULTITOP if multiple)

## Module Finding and Binding

1. All files on command line and in `-f` files are parsed first
2. If a module is not found, Verilator searches using `-y` and `+libext`
3. Binding starts from `--top-module` and resolves downward

## File Lists

```bash
# Use -f for file lists
verilator --binary -f filelist.vc

# filelist.vc contents:
# -I./rtl
# -I./includes
# rtl/top.sv
# rtl/sub.sv
```

## Hierarchical Verilation

For large designs (10+ min, 100+ GB memory):

```verilog
module cpu; /* verilator hier_block */
  ...
endmodule
```

```bash
verilator --hierarchical --binary top.sv
```

This creates separate models for hierarchy blocks, reducing memory and allowing parallel compilation.

## Cross Compilation

Verilator supports generating code on one system (host) to be compiled on another (target). The generated code is self-contained and does not reference build-system-specific files.

## Verilation Summary Report

```
- V e r i l a t i o n   R e p o r t: Verilator 5.050
- Verilator: Built from 354 MB sources in 247 modules,
    into 74 MB in 89 C++ files needing 0.192 MB
- Verilator: Walltime 26.580 s (elab=2.096, cvt=18.268,
    bld=2.100); cpu 26.548 s on 1 threads; allocated 2894.672 MB
```
