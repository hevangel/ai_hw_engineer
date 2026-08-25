# Verilator CMake Integration

Source: [veripool.org/guide/latest/verilating.html](https://veripool.org/guide/latest/verilating.html)

## Minimal CMakeLists.txt

```cmake
project(my_simulation)
find_package(verilator HINTS $ENV{VERILATOR_ROOT})
add_executable(Vtop sim_main.cpp)
verilate(Vtop SOURCES top.sv)
```

## Build Commands

```bash
mkdir build && cd build
cmake -GNinja ..
ninja
./Vtop
```

Or with default generator:
```bash
mkdir build && cd build
cmake ..
cmake --build .
```

## verilate() Function

```cmake
verilate(target SOURCES source ...
  [TOP_MODULE top]
  [PREFIX name]
  [COVERAGE]
  [SYSTEMC]
  [TRACE_FST]
  [TRACE_VCD]
  [THREADS num]
  [INCLUDE_DIRS dir ...]
  [OPT_SLOW ...]
  [OPT_FAST ...]
  [OPT_GLOBAL ...]
  [DIRECTORY dir]
  [VERILATOR_ARGS ...]
)
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `SOURCES` | List of Verilog/SV files (required) |
| `TOP_MODULE` | Top module name (default: first source file name) |
| `PREFIX` | Output file prefix (must be unique per call) |
| `COVERAGE` | Enable coverage |
| `SYSTEMC` | Enable SystemC mode |
| `TRACE_FST` | Enable FST tracing |
| `TRACE_VCD` | Enable VCD tracing |
| `THREADS` | Enable multithreaded model |
| `INCLUDE_DIRS` | Include directories (same as -y) |
| `OPT_SLOW` | Compiler options for slow path |
| `OPT_FAST` | Compiler options for fast path |
| `OPT_GLOBAL` | Compiler options for runtime library |
| `DIRECTORY` | Override output directory |
| `VERILATOR_ARGS` | Additional Verilator arguments |

## SystemC Integration

```cmake
verilate(Vtop
  SOURCES top.sv
  SYSTEMC
)
verilator_link_systemc(Vtop)
```

SystemC path variables:
- `SYSTEMC_INCLUDE` — direct path to includes
- `SYSTEMC_LIBDIR` — direct path to libraries
- `SYSTEMC_ROOT` — installation prefix

## Full Example

```cmake
cmake_minimum_required(VERSION 3.12)
project(soc_sim)

find_package(verilator HINTS $ENV{VERILATOR_ROOT})

add_executable(Vsoc sim_main.cpp)

verilate(Vsoc
  SOURCES
    rtl/soc_top.sv
    rtl/cpu_core.sv
    rtl/bus_fabric.sv
  TOP_MODULE soc_top
  TRACE_FST
  COVERAGE
  THREADS 4
  INCLUDE_DIRS rtl includes
  VERILATOR_ARGS -Wall -O3
  OPT_FAST "-O2 -march=native"
)
```

## Notes

- `find_package` auto-detects installed Verilator or uses `VERILATOR_ROOT`
- `verilate()` can be called multiple times to add modules to a target
- CMake >= 3.12 with Ninja generator is recommended
- Sets `verilator_FOUND`, `VERILATOR_ROOT`, `VERILATOR_BIN` variables
