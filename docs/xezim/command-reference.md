# Xezim Command Reference

## Basic Invocation

```bash
xezim <source_files> [+plusargs] [options]
```

## CLI Options

| Option | Purpose |
|--------|---------|
| `-D<MACRO>[=val]` | Define a preprocessor macro |
| `-I<dir>` | Add an include directory |
| `--simulate` | Run the simulation (vs `--parse` / `--compile` / `--preprocess`) |
| `-s <module>` | Select a top-level module. Repeat for multiple roots |
| `--dpi-lib <path>` | Load a DPI-C shared library. Repeatable |
| `--vpi-lib <path>` (`-m`) | Load a VPI module. Repeatable |
| `--module-timescale [mods=]<unit>/<prec>` | Assign timescale to modules without one |
| `--dump-timescales` | Print every module's resolved timescale |
| `--max-time <N>[ps\|ns\|us\|ms\|s]` | Stop simulation after N simulated time |
| `+trace` | Enable waveform tracing |
| `+seed=<n>` | Seed RNG for reproducible runs |
| `--sdf <file> --sdf-{min,typ,max}` | Annotate standard delays |
| `--sim-debug` | Print debug diagnostics |
| `--verbose` | Per-file compile progress |
| `--dump-files-list` | Print resolved file list and exit |
| `--dump-merged-sv <file>` | Write preprocessed self-contained .sv |
| `--artifact-compression <none\|1-22>` | Compression level for compiled artifact |
| `--cache-dir <dir>` | Select elaborated-design cache directory |
| `--no-cache` | Disable automatic elaborated-design cache |
| `-l, --log <file>` | Redirect stdout/stderr to log file |
| `-v <file>` | Library file: modules compiled on demand |
| `-y <dir>` | Library directory: `<module>.<ext>` loaded on demand |
| `+libext+<ext>+...` | Extension list for -y search |
| `+nospecify` | Suppress specify-block path delays |
| `+notimingcheck` | Accepted no-op for timing checks |
| `--fst <file>` | Emit FST waveform dump |
| `--fst-scope <hier>` | Restrict FST dump to scope (repeatable) |
| `--xtrace <file>` | Emit XTrace v1.0 dump |
| `--xtrace-scope <hier>` | Restrict XTrace dump to scope (repeatable) |
| `--relax-implicit-static` | Accept `int x = ...` inside static task with warning |
| `--error-exit` | Exit nonzero if any `$error` reported |

## Environment Variables

| Variable | Effect |
|----------|--------|
| `XEZIM_EVENT_EDGE=1` | Skip gateable clocked flop fires (1.13-1.30x speedup) |
| `XEZIM_JIT=1` | Compile bytecode to machine code in-process (needs `--features jit`) |
| `XEZIM_AOT=1` | Native code via generated Rust + rustc (requires `XEZIM_JIT=1`) |
| `XEZIM_AOT_OPT=0..3` | rustc optimization level (default 2) |
| `XEZIM_PROC_FSM=1` | Compile blocking always bodies into bytecode state machines |
| `XEZIM_NO_NATIVE_CACHE=1` | Disable persistent native-library cache |
| `XEZIM_REGIONS=1` | Fuse combinational entries into region blocks (experimental) |
| `XEZIM_STUCK_CLOCK=1` | Flag process parked on non-toggling clock |
| `XEZIM_INIT_ZERO=1` | Coerce X-initialized signals to 0 |
| `XEZIM_PROGRESS=N` | Emit progress line every N wall-seconds |
| `XEZIM_CACHE_DIR=<dir>` | Override elaborated-design cache directory |
| `XEZIM_NO_CACHE=1` | Disable elaborated-design cache |
| `XEZIM_COMPILE_PHASES=1` | Report compilation phase timings |
| `XEZIM_ALLOW_IMPLICIT_STATIC=1` | Same as `--relax-implicit-static` |
| `XEZIM_MAX_INST_DEPTH=N` | Instantiation-depth cap (default 200) |
| `XEZIM_STACK_MB=N` | Stack size of simulation worker thread (default 1024) |
| `XEZIM_VALUE_TRACE=<substr>` | Print every committed change of matching signals |
| `XEZIM_VALUE_TRACE_LIMIT=N` | Cap value-trace output lines (default 20000) |

## Examples

### Basic simulation
```bash
xezim --simulate -s top design.sv testbench.sv
```

### Gate-level simulation
```bash
xezim testbench.v synth.v \
    +firmware=firmware/firmware.hex --max-time 50000000
```

### UVM testbench
```bash
xezim --simulate -s top \
  -I $UVM/src -I rtl -I sv -I tb \
  -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
  $UVM/src/uvm_pkg.sv sv/pipe_pkg.sv sv/pipe_if.sv rtl/pipe.v tb/top.sv \
  +UVM_TESTNAME=data0_test
```

### Multiple top modules (hdl_top + hvl_top)
```bash
xezim --simulate -s hdl_top -s hvl_top \
  -I $UVM/src -I agent -I tb \
  -D UVM_NO_DPI \
  $UVM/src/uvm_pkg.sv agent/*.sv rtl/*.v \
  tb/hdl_top.sv tb/hvl_top.sv
```

### With DPI library
```bash
cc -shared -fPIC -I /path/to/xezim/include dpi_code.c -o dpi_code.so
xezim --dpi-lib ./dpi_code.so --simulate -s top design.sv
```

### Native compilation (JIT + AOT)
```bash
cargo build --release --features jit
XEZIM_JIT=1 XEZIM_AOT=1 XEZIM_PROC_FSM=1 \
  ./target/release/xezim --simulate -s top design.sv
```

### Waveform generation
```bash
# VCD (default with $dumpfile/$dumpvars in design)
xezim --simulate -s top design.sv +trace

# FST format
xezim --simulate -s top design.sv --fst output.fst

# XTrace format (with compression)
xezim --simulate -s top design.sv --xtrace output.xtrace.zst
```
