# UVM Library Usage Guide

This repository contains multiple UVM versions for use with xezim and Verilator.

## Available Versions

| Directory | Version | Notes |
|-----------|---------|-------|
| `1.1d/` | UVM 1.1d | Legacy |
| `1.2/` | UVM 1.2 | Widely used in industry |
| `1800.2-2017/` | IEEE 1800.2-2017 | Current standard |
| `1800.2-2020/` | IEEE 1800.2-2020.3.1 | Latest standard |

## Using with xezim

### UVM 1.2

```bash
UVM=$PWD/libs/uvm/1.2
xezim --simulate -s top \
  -I $UVM/src -D UVM_NO_DPI \
  $UVM/src/uvm_pkg.sv \
  <design files> \
  +UVM_TESTNAME=my_test
```

### UVM 1800.2-2017 (Recommended)

```bash
UVM=$PWD/libs/uvm/1800.2-2017
xezim --simulate -s top \
  -I $UVM/src -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
  $UVM/src/uvm_pkg.sv \
  <design files> \
  +UVM_TESTNAME=my_test
```

### UVM 1800.2-2020

```bash
UVM=$PWD/libs/uvm/1800.2-2020
xezim --simulate -s top \
  -I $UVM/src -D UVM_NO_DPI \
  $UVM/src/uvm_pkg.sv \
  <design files> \
  +UVM_TESTNAME=my_test
```

## Using with Verilator

Verilator supports UVM via the same UVM source. See the
GettingVerilatorStartedWithUVM example for a working flow.

## Key Files

- `<version>/src/uvm_pkg.sv` — Main UVM package (include this)
- `<version>/src/uvm_macros.svh` — UVM macros (auto-included via `uvm_pkg.sv`)
- `<version>/src/` — Full UVM source tree

## Notes

- Use `-D UVM_NO_DPI` with xezim (it handles UVM reporting/cmdline natively)
- For UVM-1.2 testbenches on 1800.2 library: add `-D UVM_ENABLE_DEPRECATED_API`
- Source: https://github.com/nitronis/UVM
