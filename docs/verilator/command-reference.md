# Verilator Command Reference

Source: [veripool.org/guide/latest/](https://veripool.org/guide/latest/)

## Invocation

```bash
verilator [options] [source_files.v ...] [source_files.sv ...]
```

## Major Mode Options

| Option | Description |
|--------|-------------|
| `--binary` | Generate C++ and compile to executable binary |
| `--cc` | Generate C++ output files |
| `--sc` | Generate SystemC output files |
| `--lint-only` | Lint the design, do not generate output |
| `--json-only` | Generate JSON AST output |
| `-E` | Preprocess only, write to stdout |

## Commonly Used Options

### Input Control
| Option | Description |
|--------|-------------|
| `--top-module <name>` | Specify top-level module |
| `-f <file>` | Read additional options/files from file |
| `-I<dir>` | Include directory for `\`include` |
| `-D<name>[=<value>]` | Define preprocessor macro |
| `-U<name>` | Undefine preprocessor macro |
| `-y <dir>` | Module search directory |
| `+libext+<ext>` | File extension for `-y` search |
| `-v <file>` | Library file |

### Output Control
| Option | Description |
|--------|-------------|
| `--Mdir <dir>` | Output directory (default: `obj_dir`) |
| `--prefix <name>` | Prefix for output files |
| `--exe` | Generate executable (with user C++) |
| `--main` | Generate default `main()` function |
| `--build` | Build after verilating |
| `-j <N>` | Parallel build jobs (0 = auto) |

### Optimization
| Option | Description |
|--------|-------------|
| `-O0` | No optimization |
| `-O1` | Some optimization |
| `-O2` | Default optimization |
| `-O3` | Maximum optimization (slower compile) |
| `--unroll-count <N>` | Max loop unroll iterations |
| `--unroll-stmts <N>` | Max statements in unrolled loop |

### Simulation Features
| Option | Description |
|--------|-------------|
| `--trace` | Enable VCD waveform tracing |
| `--trace-fst` | Enable FST waveform tracing |
| `--trace-depth <N>` | Limit trace hierarchy depth |
| `--coverage` | Enable all coverage |
| `--coverage-line` | Enable line coverage |
| `--coverage-toggle` | Enable toggle coverage |
| `--coverage-user` | Enable user cover points |
| `--assert` | Enable assertions |
| `--threads <N>` | Number of simulation threads |
| `--savable` | Enable save/restore |

### Warnings
| Option | Description |
|--------|-------------|
| `-Wall` | Enable all warnings |
| `-Werror-<msg>` | Promote warning to error |
| `-Wno-<msg>` | Disable specific warning |
| `--Wno-fatal` | Don't exit on warnings |

### Language Control
| Option | Description |
|--------|-------------|
| `--language <lang>` | Default language standard |
| `--default-language <lang>` | Language for files without extension |
| `+1364-1995ext+<ext>` | Verilog-1995 file extension |
| `+1364-2001ext+<ext>` | Verilog-2001 file extension |
| `+1800-2005ext+<ext>` | SV-2005 file extension |
| `+1800-2012ext+<ext>` | SV-2012 file extension |
| `+1800-2017ext+<ext>` | SV-2017 file extension |

### Performance Tuning
| Option | Description |
|--------|-------------|
| `--threads <N>` | Multithreaded simulation (N >= 2) |
| `--threads-dpi all\|pure\|none` | DPI thread safety |
| `--instr-count-dpi <N>` | DPI execution cost estimate |
| `--output-split <N>` | Split output into files of N statements |
| `--output-split-cfuncs <N>` | Split C functions at N statements |

### Debug
| Option | Description |
|--------|-------------|
| `--debug` | Enable debug mode |
| `--debugi <N>` | Debug verbosity level |
| `--dump-tree` | Dump AST trees |
| `--prof-exec` | Enable execution profiling |
| `--prof-pgo` | Enable profile-guided optimization |
| `--stats` | Print design statistics |

## Examples

### Simple Binary Build
```bash
verilator --binary -j 0 -Wall top.sv
```

### Full-Featured Compilation
```bash
verilator --binary -j 0 \
  --trace-fst --coverage --assert \
  --threads 4 -O3 -Wall \
  --top-module soc_top \
  -I./rtl -I./includes \
  -DSIMULATION \
  rtl/soc_top.sv rtl/cpu.sv rtl/bus.sv \
  sim_main.cpp
```

### Lint Check
```bash
verilator --lint-only -Wall \
  --top-module my_module \
  -I./rtl my_module.sv
```

### With File List
```bash
verilator --binary -j 0 -f design.vc sim_main.cpp
```
