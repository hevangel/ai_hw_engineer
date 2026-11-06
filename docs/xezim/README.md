# Xezim Documentation

Xezim is an open-source, AI-native SystemVerilog simulator written in Rust. It features 4-state event-driven simulation, IEEE 1800-2023 compliance, and runs real UVM testbenches end-to-end.

## Documentation Files

- [Overview & Quick Start](overview.md) - Introduction, features, and basic usage
- [UVM Guide](uvm-guide.md) - Running UVM testbenches on xezim
- [DPI Guide](dpi-guide.md) - Compiling and loading DPI-C libraries
- [Command Reference](command-reference.md) - CLI options and environment variables
- [Build & Install](build-install.md) - Building xezim from source
- [Native Compilation](native-compilation.md) - JIT and AOT compilation modes

## Source

- Repository: https://github.com/aionhw/xezim
- License: Apache License 2.0

## Qualified baseline

Xezim is qualified natively for simulation, `--error-exit`, VCD output and UVM, and compared against Verilator on SystemVerilog semantics cases.

Pins, license, compatibility with the other pinned tools, and supported/unsupported behavior are recorded in [EDA tool baseline](../eda-tool-baseline.md) and the probe results in [EDA tool qualification](../eda-tool-qualification.md).
