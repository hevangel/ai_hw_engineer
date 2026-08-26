# Verible Overview

Verible is an open-source suite of SystemVerilog developer tools maintained by the [CHIPS Alliance](https://github.com/chipsalliance/verible). It parses SystemVerilog (IEEE 1800-2017) without preprocessing, making it suitable for single-file applications like linting and formatting.

## Tool Suite

Verible provides the following command-line tools:

| Tool | Purpose |
|------|---------|
| `verible-verilog-lint` | Style linter — checks code against configurable lint rules |
| `verible-verilog-format` | Formatter — auto-formats SystemVerilog source |
| `verible-verilog-syntax` | Syntax checker — visualizes parse tree (useful for debugging) |
| `verible-verilog-ls` | Language server — provides IDE features (diagnostics, formatting) |
| `verible-verilog-diff` | Structural diff — compares files using syntax structure |
| `verible-verilog-obfuscate` | Obfuscator — replaces identifiers for sharing code |
| `verible-verilog-preprocessor` | Preprocessor — expands macros for analysis |
| `verible-verilog-project` | Project tool — analyzes multi-file projects |
| `verible-verilog-kythe-extractor` | Kythe extractor — emits cross-reference data |

## Key Features

- **No preprocessing required** — operates on raw source files, preserving comments and macro names
- **IEEE 1800-2017 compliant** — handles modern SystemVerilog constructs
- **Configurable rules** — lint rules can be enabled/disabled per-project or per-file
- **Autofix support** — many lint violations can be fixed automatically
- **Waiver system** — suppress specific findings via in-file comments or external waiver files
- **Language server** — integrates with editors for real-time diagnostics and formatting
- **Incremental formatting** — format only changed lines in git workflows

## How It Fits in Our Workflow

In our design flow, Verible serves as the **style enforcement** layer:

1. **During development** — Run `verible-verilog-lint` to catch style violations early
2. **Before commit** — Run `verible-verilog-format` to normalize formatting
3. **In CI** — Enforce lint and format compliance as a gate

Verible complements Verilator's `--lint-only` mode: Verilator checks for synthesizability and semantic correctness, while Verible enforces coding style and naming conventions.
