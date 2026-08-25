# Running UVM Testbenches on Xezim

Xezim runs UVM 1800.2-2017 and 1800.2-2020.3.1 testbenches end-to-end on its event-driven 4-state core: build → connect → topology → `run_phase` stimulus → sequencer↔driver TLM handshake → packet collection → objection-driven termination → report summary.

Source: [xezim docs/uvm-guide.md](https://github.com/aionhw/xezim/blob/main/docs/uvm-guide.md)

---

## Quick Start (Single Top)

Point xezim at the UVM library, the include dirs, and source files:

```bash
xezim --simulate -s top \
  -I <UVM>/src -I <rtl> -I <sv> -I <tb> \
  -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
  <UVM>/src/uvm_pkg.sv \
  <design and testbench files...> \
  +UVM_TESTNAME=<test_name>
```

Key flags:
- `-I <UVM>/src` — makes `` `include "uvm_macros.svh" `` resolve
- `-D UVM_NO_DPI` — xezim services UVM reporting/cmdline directly instead of via DPI
- `+UVM_TESTNAME=<name>` — selects the test class

### Worked Example — GettingVerilatorStartedWithUVM

```bash
xezim --simulate -s top \
  -I $UVM/src -I rtl -I sv -I tb \
  -D UVM_REPORT_DISABLE_FILE_LINE -D UVM_NO_DPI -D SVA_ON \
  $UVM/src/uvm_pkg.sv sv/pipe_pkg.sv sv/pipe_if.sv rtl/pipe.v tb/top.sv \
  +UVM_TESTNAME=data0_test
```

Expected output: topology table, both monitors reporting `COLLECTED PACKETS = 76`, `UVM_ERROR : 0` / `UVM_FATAL : 0`, and a clean `$finish`.

---

## Multiple Top Modules (hdl_top + hvl_top)

Many UVM testbenches declare two unconnected top modules. Pass each with its own `-s`:

```bash
xezim --simulate -s hdl_top -s hvl_top \
  -I <UVM>/src -I <agent> -I <tb> \
  -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
  <UVM>/src/uvm_pkg.sv <agent files...> <rtl files...> \
  <tb>/hdl_top.sv <tb>/hvl_top.sv
```

Xezim elaborates all specified top modules under a synthetic wrapper root.

---

## UVM Library Versions

| Library | Status |
|---------|--------|
| **1800.2-2017** | Reference target. 32/35 sv-tests examples pass |
| **1800.2-2020.3.1** | Green — monitors agree (77/77 packets), `UVM_ERROR`/`UVM_FATAL` = 0 |
| **UVM 1.2** | Supported with `-D UVM_ENABLE_DEPRECATED_API` when using 1800.2 library source |

### Version-specific notes

- **UVM-1.2 testbenches against 1800.2 library**: Add `-D UVM_ENABLE_DEPRECATED_API` to make deprecated globals like `uvm_top` available.
- **1800.2-2020 inline conditionals**: Handled automatically by the preprocessor.

---

## Supported Features

- `uvm_test` / `uvm_env` / `uvm_agent` / `uvm_driver` / `uvm_monitor` / `uvm_sequencer` / `uvm_scoreboard`
- Sequences: `body`, `start`, `start_item`/`finish_item`, `` `uvm_do ``/`` `uvm_do_with ``
- TLM: analysis ports, `uvm_*_imp`/export, `put`/`get`, TLM fifos
- Virtual interfaces: member reads, event sensitivity, assignment, task-arg aliasing
- `uvm_config_db#(T)::set/get/exists` — scope-aware with wildcard matching
- Objection model: `raise_objection` / `drop_objection` / `set_drain_time`
- Factory (`type_id::create`), overrides, parameterized components

---

## Known Limitations

- Deprecated UVM-1.0 API (`` `uvm_sequencer_utils ``, sequence libraries)
- DPI backdoor access (`uvm_hdl_*`)
- RAL (register abstraction layer)
- Sequence lock/grab arbitration beyond common path

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `config_db ... ::get(...) failed` (NOVIF) | Pass all top modules with `-s` |
| `No test specified` (UVM_FATAL NOTEST) | Add `+UVM_TESTNAME=<name>` |
| `Requested test "X" not found` | Check test class name spelling and file inclusion |
| `Undeclared identifier 'uvm_top'` | Add `-D UVM_ENABLE_DEPRECATED_API` |
| Run never terminates | Set `--max-time <N>` to bound it |
| Monitor collects 0 packets | Confirm driver's `seq_item_port` connects in `connect_phase` |
