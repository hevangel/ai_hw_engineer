# SystemC reference implementation

Tracker: [#83](https://github.com/hevangel/ai_hw_engineer/issues/83). The Accellera
SystemC class library is the upstream reference of the extended EDA overlay
(`eda_extended/`). The Rust implementation
([ai_sw_engineer#115](https://github.com/hevangel/ai_sw_engineer/issues/115)) is
checked against the corpus recorded here.

## Specification

| Item | Value |
| --- | --- |
| Source | https://github.com/accellera-official/systemc, release `3.0.2` |
| Pinned revision | `70b0fc8e4a74acc677b0fc73cea08f940c2115d5` |
| License | Apache-2.0 |
| Standard and profile | IEEE 1666 SystemC class library (the 3.0.2 release); applications build with `-std=c++17`, the standard set in the CMake configuration |
| Compiler and tools | GNU C++ 15.2.0, CMake 4.2.3 (both from the pinned Ubuntu snapshot); Python 3 for the upstream regression runner |
| Library build | static (`BUILD_SHARED_LIBS=OFF`), `Release`, `ENABLE_ASSERTIONS=ON` (the default), `CMAKE_INSTALL_LIBDIR=lib`; processes use the library default process (coroutine) package |
| Install path | `/opt/systemc` (`include/`, `lib/libsystemc.a`, `lib/cmake/`); `SYSTEMC_HOME=/opt/systemc` |
| Platform | Linux x86_64 container only. Windows, macOS, shared-library and `arm64` builds are not qualified. |

The installation contract for an application is:

```sh
g++ -std=c++17 -O1 -I/opt/systemc/include app.cpp \
    -L/opt/systemc/lib -lsystemc -pthread -o app
```

## Implementation plan

1. Pin a released revision and build it in an overlay stage, leaving the SV base
   image and its Java support unchanged.
2. Qualify with a small corpus: modules, ports, signals, methods and threads,
   events and delta cycles, FIFO channels, reset and VCD tracing.
3. Add negative programs and check that each ends with a nonzero status and its
   documented diagnostic.
4. Run the upstream examples and regression tests from the retained build stage.
5. Keep sources and `expected.txt` files as the Rust port's reference corpus.

## Corpus

Each case is a standalone `sc_main` program in
`eda_extended/systemc/corpus/<case>/`. Output is compared to `expected.txt`;
SystemC `Info:` reports and blank lines are dropped first.

| Case | Exercises | Expected output from |
| --- | --- | --- |
| `counter` | `SC_MODULE`, `sc_in`/`sc_out`, `sc_signal`, `SC_METHOD` on `clk.pos()`, `SC_THREAD` stimulus, `sc_clock` with offset, `sc_uint`, VCD tracing | The same independent model as the VHDL counter (`nvc/corpus/counter/reference.py`) |
| `delta_events` | Evaluate/update (a written signal keeps its old value until the update phase), `wait(SC_ZERO_TIME)`, `sc_delta_count`, zero-time and timed `sc_event::notify`, a lost immediate notification, replacement of a later notification by an earlier one | IEEE 1666 section 4 semantics, stated in the source |
| `fifo` | `sc_fifo` with capacity 4, a blocking producer, a slower consumer, timed `wait` | Independent discrete-event model (`fifo/reference.py`) |
| `reset_thread` | `SC_THREAD` with `reset_signal_is`; a synchronous reset restarts the thread at the next clock edge and loses local state | Stated in the source from the reset semantics |

Expected-failure programs in `eda_extended/systemc/negative/`:

| Program | Observed behavior |
| --- | --- |
| `fatal` | `SC_REPORT_FATAL` aborts: exit 134, `Fatal: extended-eda: intentional fatal report`, nothing after it runs |
| `assert_fail` | `sc_assert(false)` (enabled in this build) aborts: exit 134, `Fatal: (F4) assertion failed` |
| `error_throw` | `SC_REPORT_ERROR` throws; uncaught it exits 1 with `Error: extended-eda: intentional error report` |
| `exit_code` | The value returned by `sc_main` is the exit status (3) |
| `unbound_port` | `Error: (E109) complete binding failed: port not bound` and exit 1; the simulation never starts |

## Reset, determinism and timing assumptions

- A synchronous `reset_signal_is` is sampled when the thread is triggered by its
  clock. A reset raised between edges takes effect at the next edge.
- Within one delta cycle SystemC does not specify the order in which processes
  run. The corpus avoids depending on it: each case prints from one process, or
  relies only on ordering the standard guarantees (a signal read before the update
  phase, a blocked FIFO writer resuming in a later delta).
- Time resolution is the library default of 1 ps; the corpus reports whole
  nanoseconds.
- `sc_event::timed_out()` is deprecated in this release and prints an `I804`
  information report; the corpus does not use it.

## Waveform output and interfaces

- `sc_create_vcd_trace_file` writes VCD. The pinned Surver loads the file
  (`interop surver-loads-systemc-vcd`), so Surfer can view it. WIF tracing is
  not qualified.
- No SystemVerilog co-simulation, Verilator-SystemC wrapper or HDL Workbench
  adapter is qualified. Verilator documents SystemC output, but installing both
  tools in one image is not evidence that they interoperate. A later adapter
  must define its boundary and be qualified separately.
- TLM-2.0 headers are installed with the library but no TLM program is in the
  corpus.

## Verification

| Evidence | Result |
| --- | --- |
| `scripts/check_extended_eda.py` SystemC and interoperability rows | See [`extended-results.json`](../eda-tool-qualification/extended-results.json) |
| Upstream examples (`check-examples`) | 35 of 35 pass (`check-examples`, 0 failed) |
| Upstream regression tests (`check-tests`) | 916 of 916 pass (895 `systemc` + 21 `tlm`; `check-tests`, 0 failed) |

Reproduce the upstream suites:

```sh
docker build --target systemc-build -f eda_extended/Dockerfile \
    --build-arg ENGINEER_IMAGE=ai-hw-engineer -t eda-ext-systemc-build .
docker run --rm eda-ext-systemc-build sh -c \
    'cd /opt/systemc-src/build && cmake --build . --target check-examples -j4 && cmake --build . --target check-tests -j4'
```

(`ctest` at the top of the build tree finds nothing: the examples and tests are
`EXCLUDE_FROM_ALL` and are built and run through the `check-*` targets.)

## Known limitations

- Linux x86_64 container only; static library only; one compiler.
- Debug builds, `ENABLE_PTHREADS`/`ENABLE_STD_THREADS` process packages, and
  `ENABLE_ASSERTIONS=OFF` are not qualified.
- Process-ordering inside one delta cycle is implementation-defined and not
  asserted.
- The Rust port is not part of this record and is not claimed.
