# Verible Linter Guide

`verible-verilog-lint` checks SystemVerilog source files against configurable style rules. It operates on unpreprocessed files, making it fast and suitable for single-file analysis.

## Basic Usage

```bash
# Lint a single file
verible-verilog-lint src/alu_74181.sv

# Lint multiple files
verible-verilog-lint src/*.sv

# Non-fatal mode (report issues but exit 0)
verible-verilog-lint --lint_fatal=false src/*.sv
```

## Output Format

Diagnostics are printed as:

```
FILE:LINE:COL: message [rule-name]
```

Example:

```
src/alu.sv:12:5: Packed dimension range must be in decreasing order. [packed-dimensions-range-ordering]
```

## Rule Configuration

### Command-Line Rules

```bash
# Enable specific rules (+ prefix or no prefix)
verible-verilog-lint --rules=enum-name-style,+line-length src/*.sv

# Disable specific rules (- prefix)
verible-verilog-lint --rules=-no-tabs,-line-length src/*.sv

# Configure rule parameters
verible-verilog-lint --rules="line-length=length:80" src/*.sv

# Multiple parameters (use quotes due to semicolons)
verible-verilog-lint --rules="undersized-binary-literal=hex:true;lint_zero:true" src/*.sv
```

### Rulesets

```bash
# Use all rules
verible-verilog-lint --ruleset=all src/*.sv

# Use no rules (combine with --rules to cherry-pick)
verible-verilog-lint --ruleset=none --rules=line-length src/*.sv

# Use default ruleset (standard)
verible-verilog-lint --ruleset=default src/*.sv
```

### Configuration File

Create `.rules.verible_lint` in your project directory:

```
# Enable rules (one per line or comma-separated)
+line-length=length:100
+enum-name-style
+module-filename
-no-tabs
```

Use with:

```bash
verible-verilog-lint --rules_config=.rules.verible_lint src/*.sv
```

Or enable automatic search (walks up from each file to find config):

```bash
verible-verilog-lint --rules_config_search src/*.sv
```

## Waiving Violations

### In-File Waivers

```systemverilog
// Waive the next non-comment line
// verilog_lint: waive rule-name
assign foo = bar;

// Waive on the same line
assign foo = bar;  // verilog_lint: waive rule-name

// Waive a range of lines
// verilog_lint: waive-start rule-name
assign a = b;
assign c = d;
// verilog_lint: waive-stop rule-name
```

### External Waiver File

Create a waiver file (e.g., `lint_waivers.vlt`):

```
waive --rule=line-length --line=42
waive --rule=no-tabs --line=5:10
waive --rule=enum-name-style --regex="^\s*legacy_.*"
waive --rule=module-filename --location=".*testbench.*"
```

Use with:

```bash
verible-verilog-lint --waiver_files=lint_waivers.vlt src/*.sv
```

### Auto-Generate Waivers

```bash
# Generate waiver rules for all current violations
verible-verilog-lint --autofix=generate-waiver --autofix_output_file=waivers.vlt src/*.sv
```

## Autofix

Some violations have automatic fixes:

```bash
# Apply all fixes in-place
verible-verilog-lint --autofix=inplace src/*.sv

# Interactive mode (choose per-fix)
verible-verilog-lint --autofix=inplace-interactive src/*.sv

# Generate a unified diff patch
verible-verilog-lint --autofix=patch --autofix_output_file=fixes.patch src/*.sv
```

## Listing Available Rules

```bash
# Print help for all rules
verible-verilog-lint --help_rules=all

# Print help for a specific rule
verible-verilog-lint --help_rules=line-length

# Generate markdown documentation
verible-verilog-lint --generate_markdown
```

## Common Rules for RTL Projects

| Rule | Description |
|------|-------------|
| `line-length` | Enforce maximum line width |
| `no-tabs` | Disallow tab characters |
| `no-trailing-spaces` | Disallow trailing whitespace |
| `module-filename` | Module name must match filename |
| `enum-name-style` | Enforce naming convention for enums |
| `struct-union-name-style` | Enforce naming for structs/unions |
| `package-filename` | Package name must match filename |
| `always-comb` | Flag bare `always` blocks (prefer `always_comb`) |
| `always-ff-non-blocking` | Non-blocking assignments in `always_ff` |
| `packed-dimensions-range-ordering` | Packed dims in decreasing order |
| `unpacked-dimensions-range-ordering` | Unpacked dims in increasing order |

## Integration with Project Scripts

Add to your design's `scripts/run_all.sh`:

```bash
echo "=== Running Verible Lint ==="
verible-verilog-lint --rules_config_search src/*.sv
```
