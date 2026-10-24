# Xezim Overview

Xezim is an extensible, AI-native SystemVerilog simulator written in Rust. It is built so new language features and analyses can be added one verified step at a time, with AI agents as first-class contributors to the codebase.

Source: [github.com/aionhw/xezim](https://github.com/aionhw/xezim)

## Key Features

- **IEEE 1800-2023 grammar** by default (`--sv2017` opts back to the earlier edition)
- **4-state event-driven simulation** with full X/Z propagation
- **UVM support** — runs real Accellera UVM testbenches end-to-end (1.2, 1800.2-2017, 1800.2-2020)
- **Waveform dumps** — VCD, FST (GTKWave binary format), XTrace v1.0
- **DPI-C** — load shared libraries via `--dpi-lib`
- **VPI** — classic VPI module loading via `--vpi-lib` / `-m`
- **cocotb** — Python testbenches via VPI backend
- **Native compilation** — JIT and AOT backends for performance
- **Warm design cache** — content-addressed elaborated design caching

## Verified Workloads

End-to-end TEST PASSED with bit-identical results:

| Design | Test | Baseline Wall |
|--------|------|---------------|
| XuanTie C910 (dual-core) | hello | 95s |
| XuanTie C910 | memcpy x7000 | 216s |
| XuanTie C910 | cmark x1 | 87 min |
| XuanTie C906 (single-core) | memcpy x50 | 99s |
| XuanTie C906 | cmark x1 | 714s |
| lowRISC Ibex | CoreMark x10 | 447s |
| riscv-dv (UVM 1.2) | 10 random RV32IMC | 10/10 assemble clean |

## Compliance

- sv-tests overall: 4354/4768 (91.3%)
- UVM (1800.2-2017): 484/487 (99.4%)
- Non-ivtest: 2153/2237 (96.2%)

## Quick Start

```bash
# Build from source (requires Rust)
git clone https://github.com/aionhw/xezim.git
cd xezim
cargo build --release

# Run a simulation
./target/release/xezim --simulate -s top design.sv testbench.sv

# With UVM
./target/release/xezim --simulate -s top \
  -I $UVM/src -D UVM_NO_DPI \
  $UVM/src/uvm_pkg.sv design.sv tb.sv \
  +UVM_TESTNAME=my_test
```

## Architecture

```
xezim (this repo)          — bytecode interpreter + simulator (binary: xezim)
xezim-core (git dep)       — shared library: parser, elaboration, value, SDF, VCD sink
```

The project is split across two repos; this repo depends on xezim-core as a git dependency (Cargo clones it automatically).

## Observed Discrepancies

- **0.11.0, packed `localparam` table indexed by a loop variable** (found
  2026-10-23 in `design/mos_6560`): inside an `always_comb` `for` loop,
  `(div_q & PRESCALE[ch]) == 0` with
  `localparam logic [3:0][7:0] PRESCALE = {...}` behaved in xezim as though
  every element were selected (all channels advanced), while Verilator and
  the independent reference agreed. Small standalone reproductions did *not*
  fail, so the trigger depends on surrounding context (the module was
  instantiated once per profile inside a generate loop). Workaround: return
  the table entry from a `case`-based function. If a replay diverges only in
  xezim, compare internal state record by record against Verilator before
  changing RTL semantics. **Re-checked 2026-10-24 on 0.11.3:** still present —
  with the packed-localparam form restored, the 200,000-record VIC replay
  fails at the same record 46934 on 0.11.0 and 0.11.3 with identical vectors,
  so the `case`-based workaround must stay.
- **0.11.0, function ports with non-zero-based ranges** (found 2026-10-23 in
  `design/mos_6567`): a function declared with `input logic [3:1] mem` and
  `input logic [6:5] cr`, called inside a large `always_comb` with slices of
  a two-dimensional packed register array, returned `X` in exactly the
  result bits derived from those ports, while Verilator and the oracle
  agreed. A small standalone reproduction did not fail. Workaround: declare
  function ports zero-based (`[2:0]`, `[1:0]`) and pass the slice.
  **Re-checked 2026-10-24 on 0.11.3:** could not re-trigger on *either*
  version — with the non-zero-based declarations restored, the recorded
  25,724-record debug replay passes 6/6 runs on 0.11.0 and 0.11.3, and its
  per-record state trace is identical to the failing run's through record
  25722, so the original X was nondeterministic (scheduling-dependent) in
  0.11.0. The zero-based workaround stays because fixed behavior is not
  demonstrated.
- **0.11.0, settle-limit exhaustion on one large `always_comb`** (found
  2026-10-23 in `design/mos_6581`): the SID core's single next-state block
  makes xezim report "settle limit hit (1000 iters)" in many time slots,
  listing block-internal variables as still changing, although Verilator
  evaluates it once. The oracle-checked replay still matches on every
  record (26,000 checked), but each affected slot costs 1,000 iterations.
  Reading an output port back inside the block was ruled out; the trigger
  is not yet isolated. Keep xezim replays of such designs short.
  **Re-checked 2026-10-24 on 0.11.3:** unchanged — the same 30,000-record SID
  replay still emits exactly 8 settle-limit warnings and still passes, so the
  extra iterations (and their wall-clock cost) remain.
