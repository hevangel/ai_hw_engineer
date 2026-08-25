# Xezim Overview

Xezim is an extensible, AI-native SystemVerilog simulator written in Rust. It is built so new language features and analyses can be added one verified step at a time, with AI agents as first-class contributors to the codebase.

Source: [github.com/aionhw/xezim](https://github.com/aionhw/xezim)

## Key Features

- **IEEE 1800-2023 grammar** by default (`--sv2017` opts back to the earlier edition)
- **4-state event-driven simulation** with full X/Z propagation
- **UVM support** — runs real Accellera UVM testbenches end-to-end (1.2, 1800.2-2017, 1800.2-2020)
- **Waveform dumps** — VCD, FST (GTKWave binary format), XTrace v1.0
- **DPI-C** — load shared libraries via `--dpi-lib`
- **VPI** — classic VPI module loading via `--vpi-lib` / `-m`
- **cocotb** — Python testbenches via VPI backend
- **Native compilation** — JIT and AOT backends for performance
- **Warm design cache** — content-addressed elaborated design caching

## Verified Workloads

End-to-end TEST PASSED with bit-identical results:

| Design | Test | Baseline Wall |
|--------|------|---------------|
| XuanTie C910 (dual-core) | hello | 95s |
| XuanTie C910 | memcpy x7000 | 216s |
| XuanTie C910 | cmark x1 | 87 min |
| XuanTie C906 (single-core) | memcpy x50 | 99s |
| XuanTie C906 | cmark x1 | 714s |
| lowRISC Ibex | CoreMark x10 | 447s |
| riscv-dv (UVM 1.2) | 10 random RV32IMC | 10/10 assemble clean |

## Compliance

- sv-tests overall: 4354/4768 (91.3%)
- UVM (1800.2-2017): 484/487 (99.4%)
- Non-ivtest: 2153/2237 (96.2%)

## Quick Start

```bash
# Build from source (requires Rust)
git clone https://github.com/aionhw/xezim.git
cd xezim
cargo build --release

# Run a simulation
./target/release/xezim --simulate -s top design.sv testbench.sv

# With UVM
./target/release/xezim --simulate -s top \
  -I $UVM/src -D UVM_NO_DPI \
  $UVM/src/uvm_pkg.sv design.sv tb.sv \
  +UVM_TESTNAME=my_test
```

## Architecture

```
xezim (this repo)          — bytecode interpreter + simulator (binary: xezim)
xezim-core (git dep)       — shared library: parser, elaboration, value, SDF, VCD sink
```

The project is split across two repos; this repo depends on xezim-core as a git dependency (Cargo clones it automatically).
