# Compiling and Loading DPI Libraries for Xezim

Xezim loads DPI-C (Direct Programming Interface, IEEE 1800 §35) shared libraries at simulation start via `--dpi-lib`.

Source: [xezim docs/dpi-guide.md](https://github.com/aionhw/xezim/blob/main/docs/dpi-guide.md)

---

## Quick Start — One-File C Library

```bash
# Compile
cc -shared -fPIC -I path/to/xezim/include simple_dpi.c -o simple_dpi.so

# Run
xezim --dpi-lib ./simple_dpi.so simple_dpi_test.sv
```

---

## What Xezim Expects

`--dpi-lib <path>` accepts a shared library that exports C symbols declared by `import "DPI-C"` statements in SystemVerilog. The mechanism is `dlopen()` + `dlsym()`.

| Element | Source |
|---------|--------|
| `.so` / `.dylib` / `.dll` | You build it |
| `import "DPI-C" function ...` | In your SV source |
| Matching exported C symbols | The shared library |
| `svdpi.h` (optional) | `<repo>/include/svdpi.h` |
| `vpi_user.h` (optional) | `<repo>/include/vpi_user.h` |
| `sv_vpi_user.h` (optional) | `<repo>/include/sv_vpi_user.h` |

---

## Minimal Working Example

### `simple_dpi.c`
```c
#include <stdint.h>

int add_c(int a, int b) {
    return a + b;
}
```

### `simple_dpi_test.sv`
```systemverilog
module simple_dpi_test;
  import "DPI-C" function int add_c(input int a, input int b);

  initial begin
    $display("DPI_RESULT=%0d", add_c(20, 22));
    if (add_c(20, 22) != 42) begin
      $display("TEST_FAIL");
      $finish;
    end
    $display("TEST_PASS");
    $finish;
  end
endmodule
```

### Build and run
```bash
cc -shared -fPIC -I . simple_dpi.c -o simple_dpi.so
xezim --dpi-lib ./simple_dpi.so simple_dpi_test.sv
```

---

## C++ Sources

```bash
g++ -shared -fPIC -std=c++17 -I path/to/xezim/include dpi_module.cc -o dpi_module.so
```

Important: DPI exports must be wrapped in `extern "C" { ... }` — the DPI loader does not perform C++ name-mangling recovery.

---

## Multi-File Libraries (UVM DPI)

```bash
g++ -shared -fPIC -std=c++17 -Wno-format-security \
    -I path/to/xezim/include -I path/to/uvm-core/src/dpi \
    path/to/xezim/include/uvm_dpi_xezim.cc \
    -o uvm.so
```

Or use the shipped script:
```bash
/path/to/xezim/scripts/build_uvm_so.sh
```

---

## Linking External Libraries

```bash
# Compile shim
g++ -shared -fPIC -std=c++17 \
    -I path/to/xezim/include -I $SPIKE_PREFIX/include \
    -c xezim_spike_dpi.cpp -o xezim_spike_dpi.o

# Link with external library
g++ -shared -fPIC \
    -L $SPIKE_PREFIX/lib -Wl,-rpath,$SPIKE_PREFIX/lib \
    xezim_spike_dpi.o -lriscv -lfesvr -lsoftfloat \
    -o xezim_spike_dpi.so
```

Rules:
- Libraries go after sources in the link line
- Use `-Wl,-rpath,<dir>` to bake runtime search path
- Never use `-static` with DPI libraries
- Use `SV_PUBLIC` attribute for visibility in `-fvisibility=hidden` builds

---

## VPI Modules (`--vpi-lib`)

```bash
cc -shared -fPIC -I <xezim_dir>/include -o my_vpi.so my_vpi.c
xezim --vpi-lib my_vpi.so design.sv
```

Supported VPI surface:
- `vpi_register_systf` — system tasks and functions
- `vpiSysTfCall` / `vpiArgument` — argument access
- Design walk: `vpi_iterate`/`vpi_scan` over modules, nets, regs, parameters
- `vpi_handle_by_name`, `vpi_get`, `vpi_get_str`, `vpi_get_value`/`vpi_put_value`
- `vpi_control(vpiStop/vpiFinish)`, `vpi_chk_error`, `vpi_printf`

---

## Cross-Platform

| Platform | Extension | Compiler | Recipe |
|----------|-----------|----------|--------|
| Linux | `.so` | `cc` / `g++` | `cc -shared -fPIC foo.c -o foo.so` |
| macOS | `.dylib` | `cc` / `clang++` | `cc -shared -fPIC foo.c -o foo.dylib` |
| Windows | `.dll` | `cl.exe` / MinGW | `cl /LD foo.c /Fe:foo.dll` |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `failed to load DPI library` | Missing transitive dependency | Add `-Wl,-rpath` or set `LD_LIBRARY_PATH` |
| `undefined symbol: my_dpi_fn` | C++ mangling / missing `extern "C"` | Wrap in `extern "C"`, mark `SV_PUBLIC` |
| Symbol returns garbage | ABI mismatch | Match C signature exactly to DPI import |
| `failed to resolve path` (VPI) | Signal not elaborated | Check hierarchical path matches design |
