# SymbiYosys .sby File Format Reference

Source: [yosyshq.readthedocs.io/projects/sby/en/latest/reference.html](https://yosyshq.readthedocs.io/projects/sby/en/latest/reference.html)

## File Structure

A `.sby` file consists of sections in square brackets:

```ini
[tasks]       # Optional: multiple verification tasks
[options]     # Required: verification mode and settings
[engines]     # Required: solver engines
[script]      # Required: Yosys script
[files]       # Required: source files
```

---

## [tasks] Section

Configure multiple verification tasks in one file:

```ini
[tasks]
bmc_basic bmc_tasks
bmc_deep bmc_tasks
prove_all

[options]
bmc_tasks: mode bmc
bmc_basic: depth 20
bmc_deep: depth 100
prove_all: mode prove
```

Use `~<taskname>:` for negation:
```ini
~prove_all: mode bmc
prove_all: mode prove
```

Run specific task: `sby example.sby bmc_basic`
Run all tasks: `sby example.sby`

---

## [options] Section

### Required

| Option | Values | Description |
|--------|--------|-------------|
| `mode` | `bmc`, `prove`, `cover`, `live`, `prep` | Verification mode |

### Common Options

| Option | Default | Description |
|--------|---------|-------------|
| `depth` | 20 | BMC/cover depth (number of cycles) |
| `expect` | `pass` | Expected result: `pass`, `fail`, `unknown`, `error`, `timeout` |
| `timeout` | none | Timeout in seconds |
| `multiclock` | `off` | Multi-clock/async design support |
| `wait` | `off` | Wait for all engines before reporting |

### Trace Options

| Option | Default | Description |
|--------|---------|-------------|
| `vcd` | `on` | Generate VCD counter-example traces |
| `fst` | `off` | Generate FST traces (via Yosys sim) |
| `append` | 0 | Extra cycles after counter-example |
| `tbtop` | — | Top module for test bench generation |

### Advanced Options

| Option | Default | Description |
|--------|---------|-------------|
| `skip` | none | Skip N initial time steps (smtbmc only) |
| `append_assume` | `on` | Uphold assumptions in appended cycles |
| `smtc` | none | Additional SMT constraints file |
| `make_model` | — | Force model generation |
| `skip_prep` | `off` | Skip internal preparation step |

---

## [engines] Section

Format: `<engine> [engine_options] <solver> [solver_options]`

```ini
[engines]
smtbmc z3
```

### Available Engines and Solvers

| Engine | Solvers | Modes |
|--------|---------|-------|
| `smtbmc` | z3, yices, bitwuzla, boolector, cvc4, cvc5, mathsat | bmc, prove, cover |
| `abc` | bmc3, sim3, pdr | bmc (bmc3/sim3), prove (pdr) |
| `btor` | btormc, pono, rIC3 | bmc, prove, cover |
| `aiger` | aigbmc, avy, suprove, rIC3 | bmc, prove, live |

### smtbmc Engine Options

| Option | Description |
|--------|-------------|
| `--nomem` | Don't use SMT arrays for memories |
| `--syn` | Synthesize to gates before solving |
| `--stbv` | Use bitvectors for state |
| `--stdt` | Use SMT datatypes for state |
| `--nopresat` | Skip pre-SAT consistency check |
| `--keep-going` | Continue after first failure (BMC) |
| `--unroll` / `--nounroll` | Control problem unrolling |
| `--dumpsmt2` | Write SMT2 trace for debugging |
| `--progress` | Show timer display |

### abc Engine Options

| Option | Description |
|--------|-------------|
| `--keep-going` | Report per-property results (prove/pdr) |

### Examples

```ini
# Z3 with options
[engines]
smtbmc --syn --nopresat z3 rewriter.cache_all=true

# Multiple engines (first to finish wins)
[engines]
smtbmc yices
abc pdr

# ABC for fast proofs
[engines]
abc pdr
```

---

## [script] Section

Yosys commands to read and elaborate the design:

```ini
[script]
read -formal counter.v
prep -top counter
```

Common patterns:
```ini
# SystemVerilog
[script]
read -sv design.sv
read -sv assertions.sv
prep -top design

# Multiple files with defines
[script]
read -define FORMAL=1
read -sv rtl/top.sv
read -sv rtl/sub.sv
read -sv formal/props.sv
prep -top top

# Using Verific (if available)
[script]
verific -sv design.sv
verific -import design
prep -top design
```

---

## [files] Section

Source files to copy to working directory:

```ini
[files]
top.sv
../common/defines.vh
/data/project/modules/sub.sv
```

Rename on copy:
```ini
[files]
top.sv
defines.vh ../common/defines_custom.vh
foo/bar.sv /data/project/modules/foobar.sv
```

### Inline File Sections

```ini
[file params.vh]
`define DEPTH 8
`define WIDTH 32
```

---

## Complete Example

```ini
[tasks]
bmc
prove
cover

[options]
bmc: mode bmc
bmc: depth 50
prove: mode prove
cover: mode cover
cover: depth 30

[engines]
bmc: smtbmc z3
prove: abc pdr
cover: smtbmc z3

[script]
read -formal design.sv
read -formal properties.sv
prep -top design

[files]
design.sv
properties.sv
```

---

## Running

```bash
# Run default/all tasks
sby design.sby

# Run specific task
sby design.sby prove

# Custom output directory
sby -d output_dir design.sby

# Force rerun
sby -f design.sby

# List tasks
sby --dumptasks design.sby
```
