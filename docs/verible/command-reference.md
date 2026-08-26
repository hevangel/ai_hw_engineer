# Verible Command Reference

Quick reference for all Verible tools available in the Docker image.

## verible-verilog-lint

Style linter for SystemVerilog.

```bash
verible-verilog-lint [options] <file> [<file>...]

# Key flags
--rules=<rule-list>              # Comma-separated rules (+enable, -disable, =config)
--rules_config=<path>            # Path to rules configuration file
--rules_config_search            # Search upward for .rules.verible_lint
--ruleset=[default|all|none]     # Base rule set
--waiver_files=<paths>           # Comma-separated waiver file paths
--lint_fatal=[true|false]        # Exit nonzero on violations (default: true)
--autofix=[no|inplace|patch|inplace-interactive|patch-interactive|generate-waiver]
--autofix_output_file=<path>     # Output file for patch/waiver autofix modes
--help_rules=[all|<rule-name>]   # Print rule descriptions
--generate_markdown              # Print all rules as markdown
--show_diagnostic_context        # Show source line with marker
```

## verible-verilog-format

Formatter for SystemVerilog.

```bash
verible-verilog-format [options] <file> [<file>...]

# Key flags
--inplace                        # Modify files in-place
--column_limit=<N>               # Line length limit (default: 100)
--indentation_spaces=<N>         # Spaces per indent (default: 2)
--wrap_spaces=<N>                # Continuation indent (default: 4)
--line_break_penalty=<N>         # Penalty per line break (default: 2)
--over_column_limit_penalty=<N>  # Penalty for exceeding column (default: 100)
--assignment_statement_alignment=[align|flush-left|preserve|infer]
--case_items_alignment=[align|flush-left|preserve|infer]
--lines=<start>-<end>            # Format only specified line ranges
--stdin_name=<name>              # Diagnostic name when reading stdin
--verbose                        # Verbose output
--verify_convergence=[true|false] # Check formatting is stable (default: true)
```

## verible-verilog-syntax

Syntax tree visualizer and checker.

```bash
verible-verilog-syntax [options] <file> [<file>...]

# Key flags
--printtree                      # Print the concrete syntax tree
--printtokens                    # Print the token stream
--export_json                    # Export syntax tree as JSON
--error_limit=<N>                # Limit number of errors reported
--veritreeast                    # Print tree in alternative format
```

## verible-verilog-ls

Language Server Protocol implementation.

```bash
verible-verilog-ls [options]

# Capabilities: diagnostics, formatting, go-to-definition, symbol search
# Communicates via stdio (JSON-RPC)
# Configure in editors via LSP client settings
```

## verible-verilog-diff

Structural diff between SystemVerilog files.

```bash
verible-verilog-diff <file1> <file2>

# Compares files based on syntax structure, not raw text
# Useful for seeing semantic changes beyond whitespace
```

## verible-verilog-obfuscate

Identifier obfuscator for sharing code without revealing proprietary names.

```bash
verible-verilog-obfuscate [options] <file>

# Replaces identifiers with randomized names
# Preserves syntactic structure
# Useful for creating reproducible bug reports
```

## verible-verilog-preprocessor

Standalone preprocessor.

```bash
verible-verilog-preprocessor [options] <file>

# Expands `include, `define, `ifdef, etc.
# Useful for debugging macro expansions
```

## verible-verilog-project

Multi-file project analysis.

```bash
verible-verilog-project [options] <file-list-config>

# Analyzes relationships between multiple files
# Used for cross-file symbol resolution
```

## Helper Scripts

```bash
# Format only changed lines in git
git-verible-verilog-format.sh [-- <formatter-flags>]

# Interactive formatting with diff review
verible-transform-interactive.sh -- verible-verilog-format -- <files>

# Interactive incremental formatting
verible-verilog-format-changed-lines-interactive.sh [--rev <base-ref>]
```

## Common Workflows

### Lint before commit

```bash
verible-verilog-lint --rules_config_search src/*.sv
```

### Format all source files

```bash
verible-verilog-format --inplace src/*.sv
```

### Check syntax only (no lint rules)

```bash
verible-verilog-syntax src/*.sv
```

### Generate lint report for CI

```bash
verible-verilog-lint --lint_fatal=true --show_diagnostic_context src/*.sv
```
