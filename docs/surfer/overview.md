# Surfer Overview

Source: [surfer-project.org](https://surfer-project.org/)

## What is Surfer?

Surfer is a modern waveform viewer for digital hardware simulation. It is built in Rust using the egui library, providing fast rendering and a responsive interface for inspecting simulation output.

## Key Features

- **Multiple formats**: VCD, FST, and other waveform dump formats
- **Cross-platform**: Linux, macOS, Windows
- **Web version**: Available at https://app.surfer-project.org
- **VS Code extension**: Integrate directly into your editor
- **Fast**: Built in Rust for performance with large waveform files
- **Modern UI**: Clean interface based on egui

## Supported Formats

| Format | Source | Description |
|--------|--------|-------------|
| VCD | IEEE 1800 §21.7 | Standard value change dump |
| FST | GTKWave | Binary format, compressed, fast |
| GHW | GHDL | GHDL waveform format |

## Comparison with GTKWave

| Feature | Surfer | GTKWave |
|---------|--------|---------|
| Language | Rust | C |
| UI Framework | egui (modern) | GTK (classic) |
| Performance | Fast | Fast |
| VCD support | Yes | Yes |
| FST support | Yes | Yes |
| Platform | Linux/Mac/Windows/Web | Linux/Mac/Windows |
| Web version | Yes | No |
| VS Code extension | Yes | No |
| Analog waveforms | Basic | Full |

## Use Cases

- Debugging RTL simulations (Verilator, Icarus, xezim, etc.)
- Viewing protocol transactions
- Analyzing timing relationships
- Checking signal integrity in simulation
- Sharing waveform views via web version

## Quick Start

```bash
# Install
cargo install surfer

# Open a waveform file
surfer dump.vcd
surfer dump.fst

# Or use the web version
# https://app.surfer-project.org
```
