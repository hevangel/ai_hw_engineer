# Verible Formatter Guide

`verible-verilog-format` automatically formats SystemVerilog source files for consistent style. It uses a penalty-based line-breaking algorithm to produce readable output within configurable constraints.

## Basic Usage

```bash
# Format a file (print to stdout)
verible-verilog-format src/alu.sv

# Format in-place
verible-verilog-format --inplace src/alu.sv

# Format multiple files in-place
verible-verilog-format --inplace src/*.sv

# Format from stdin
cat src/alu.sv | verible-verilog-format -
```

## Key Formatting Options

```bash
# Set column limit (default: 100)
verible-verilog-format --column_limit=80 src/alu.sv

# Set indentation spaces (default: 2)
verible-verilog-format --indentation_spaces=4 src/alu.sv

# Set wrap spaces (default: 4)
verible-verilog-format --wrap_spaces=4 src/alu.sv

# Combine options
verible-verilog-format --inplace --column_limit=100 --indentation_spaces=2 src/*.sv
```

## All Formatting Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--column_limit` | 100 | Target line length limit |
| `--indentation_spaces` | 2 | Spaces per indentation level |
| `--wrap_spaces` | 4 | Spaces for continuation wraps |
| `--line_break_penalty` | 2 | Penalty per introduced line break |
| `--over_column_limit_penalty` | 100 | Baseline penalty for exceeding column limit |
| `--line_terminator` | auto | Line ending style: `auto`, `LF`, `CR`, `CRLF` |

## Alignment Options

These control alignment behavior for various code sections:

| Flag | Default | Options |
|------|---------|---------|
| `--assignment_statement_alignment` | infer | `align`, `flush-left`, `preserve`, `infer` |
| `--case_items_alignment` | infer | `align`, `flush-left`, `preserve`, `infer` |
| `--class_member_variable_alignment` | infer | `align`, `flush-left`, `preserve`, `infer` |
| `--compact_indexing_and_selections` | true | Compact binary expressions in indexing |
| `--distribution_items_alignment` | infer | `align`, `flush-left`, `preserve`, `infer` |

Alignment modes:
- **infer** — Formatter examines original code to determine if alignment was intended
- **align** — Always align matching elements into columns
- **flush-left** — No alignment, just respect indentation
- **preserve** — Keep original spacing as-is

## Disabling Formatting

Exempt code sections from formatting:

```systemverilog
// verilog_format: off
// This section keeps manual alignment
assign data_out  = mem[addr];
assign valid_out = valid_reg;
// verilog_format: on
```

Include a reason as good practice:

```systemverilog
// verilog_format: off  // manual truth-table alignment
always_comb begin
  case (sel)
    2'b00: out = a;
    2'b01: out = b;
    2'b10: out = c;
    2'b11: out = d;
  endcase
end
// verilog_format: on
```

## Incremental Formatting (Git)

Format only changed lines in your git working tree:

```bash
# Format all modified SystemVerilog files (changed lines only)
git-verible-verilog-format.sh

# Dry-run (show what would be formatted)
git-verible-verilog-format.sh --dry-run

# Pass extra formatter flags
git-verible-verilog-format.sh -- --column_limit=80
```

To undo formatting changes:

```bash
git diff | git apply --reverse -
```

## Parsing Mode for Snippets

For files that aren't standalone compilation units (e.g., included snippets):

```systemverilog
// verilog_syntax: parse-as-module-body
// This file contains only module body items
assign foo = bar;
always_ff @(posedge clk) begin
  q <= d;
end
```

## Verify Convergence

By default, the formatter verifies that re-formatting produces no further changes:

```bash
# Disable convergence check (faster, less safe)
verible-verilog-format --verify_convergence=false src/*.sv
```

## Recommended Project Configuration

For this project, we recommend:

```bash
verible-verilog-format --inplace \
  --column_limit=100 \
  --indentation_spaces=2 \
  --wrap_spaces=4 \
  src/*.sv
```

This matches common RTL coding standards with 100-character lines and 2-space indentation.
