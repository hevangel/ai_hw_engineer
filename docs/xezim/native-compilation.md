# Xezim Native Compilation

Xezim can compile hot bytecode into machine code for improved simulation performance.

## Build Requirement

```bash
cargo build --release --features jit
```

## Modes

### In-Process JIT

```bash
XEZIM_JIT=1 ./target/release/xezim <sources> -s <top>
```

### AOT (Ahead-of-Time)

Generates Rust code, builds with `rustc`, and loads the native library:

```bash
XEZIM_JIT=1 XEZIM_AOT=1 ./target/release/xezim <sources> -s <top>
```

**Note**: `XEZIM_JIT=1` is required — `XEZIM_AOT` alone is a no-op.

### AOT + Process FSMs

```bash
XEZIM_JIT=1 XEZIM_AOT=1 XEZIM_PROC_FSM=1 ./target/release/xezim <sources> -s <top>
```

## What Gets Compiled

The AOT backend covers:
- Combinational entries
- Edge-sensitive blocks
- Process FSMs (when `XEZIM_PROC_FSM=1`)

Blocks it cannot lower (values wider than 64 bits, unsupported opcodes, X/Z-carrying shapes) remain on the interpreter. Use `XEZIM_JIT_VERBOSE=1` to see compilation statistics.

## Caching

The native library is cached under:
1. `$XEZIM_CACHE_DIR`
2. `$XDG_CACHE_HOME/xezim/native`
3. `~/.cache/xezim/native`

Cache key: generated source + `XEZIM_AOT_OPT` level + xezim build.

First run pays the `rustc` cost; later runs load cached `.so` directly.

| Variable | Effect |
|----------|--------|
| `XEZIM_NO_NATIVE_CACHE=1` | Force rebuild |
| `XEZIM_AOT_OPT=0` | Trade speed for faster build |

## Performance Results

On C910 CoreMark (native compilation):
- 18,916 / 21,305 edge blocks compile natively
- 108,248 / 215,494 combinational entries compile natively
- 1.13-1.30x speedup with event-edge gating

## Warm Design Cache

Simulation stores a content-addressed elaborated design and compiled combinational worklist after the first run:

- Cache hit skips parsing, elaboration, and dependency-index construction
- Simulator state, plusargs, and event scheduling rebuild every run
- Cache key covers source contents, defines, include paths, top selection, timescale settings

```bash
# Custom cache directory
xezim --cache-dir ./my_cache <sources>

# Cold run (bypass cache)
xezim --no-cache <sources>
```

Log messages: `[CACHE] miss`, `[CACHE] stored`, `[CACHE] hit`
