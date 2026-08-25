# Building and Installing Xezim

Source: [github.com/aionhw/xezim](https://github.com/aionhw/xezim)

## Prerequisites

- **Rust**: https://www.rust-lang.org/tools/install
- No other external dependencies required — `xezim-core` is a git dependency, and `cargo build` pulls it automatically.

## Build from Source

```bash
git clone https://github.com/aionhw/xezim.git
cd xezim
cargo build --release            # Optimized (recommended for large designs)
```

The release binary is at `target/release/xezim`.

### With JIT/AOT support

```bash
cargo build --release --features jit
```

## Modifying xezim-core

xezim-core (parser + elaboration) is a separate repo consumed as a git dependency pinned to the exact revision this xezim revision was tested against.

To work on core locally:

```bash
git clone https://github.com/aionhw/xezim-core.git ../xezim-core
./scripts/use-local-core.sh        # Detects ./xezim-core or ../xezim-core
cargo build --release              # Builds against local checkout
```

To revert to pinned version:
```bash
./scripts/use-local-core.sh --remove
```

## UVM Library Setup

UVM libraries are cloned automatically during build. Manual setup:

```bash
# Set path to UVM checkout
export XEZIM_UVM_DIR=/path/to/UVM

# Or clone as sibling
git clone https://github.com/nitronis/UVM.git ../UVM
```

The UVM repo contains:
- `1.1d/` — UVM 1.1d
- `1.2/` — UVM 1.2
- `1800.2-2017/` — Accellera 1800.2-2017
- `1800.2-2020/` — Accellera 1800.2-2020.3.1

## Docker

See the project root `Dockerfile` for a containerized build with all tools.

## Development Workflow

```
edit code
    ↓
cargo build
    ↓
run tests (cargo test / cargo test --features jit)
    ↓
add new SystemVerilog features
```

## Running Tests

```bash
cargo test                     # Bytecode interpreter mode
cargo test --features jit      # JIT mode
```

The test suite contains ~2,200 integration tests covering both execution modes, with many differential tests validated against commercial reference simulators.
