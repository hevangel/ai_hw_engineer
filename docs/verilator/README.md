# Verilator Documentation

Verilator is an open-source SystemVerilog simulator and lint system. It compiles synthesizable Verilog/SystemVerilog into multithreaded C++ or SystemC code, producing a fast simulation executable.

## Documentation Files

- [Overview](overview.md) - What Verilator is and how it works
- [Installation](installation.md) - Building and installing Verilator
- [Verilating](verilating.md) - Compiling designs with Verilator
- [Simulation](simulation.md) - Running the generated simulation
- [Waveforms & Coverage](waveforms-coverage.md) - Tracing and coverage analysis
- [Command Reference](command-reference.md) - CLI options and flags
- [CMake Integration](cmake-integration.md) - Using Verilator with CMake
- [Multithreading](multithreading.md) - Parallel simulation

## Key Links

- Website: https://verilator.org
- Repository: https://github.com/verilator/verilator
- User Guide: https://veripool.org/guide/latest/
- License: LGPL-3.0 or Artistic-2.0

## Qualified baseline

Verilator is qualified for lint, `--binary --timing` simulation, FST trace, coverage and syntax-error rejection; it is not used for UVM.

Pins, license, compatibility with the other pinned tools, and supported/unsupported behavior are recorded in [EDA tool baseline](../eda-tool-baseline.md) and the probe results in [EDA tool qualification](../eda-tool-qualification.md).
