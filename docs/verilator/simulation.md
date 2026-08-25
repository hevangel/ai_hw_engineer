# Verilator Simulation — Running the Generated Model

Source: [veripool.org/guide/latest/](https://veripool.org/guide/latest/)

## C++ Wrapper (sim_main.cpp)

A minimal wrapper file instantiates and drives the model:

```cpp
#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"  // For VCD tracing

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);

    // Create instance of model
    Vtop* top = new Vtop;

    // Enable tracing (optional)
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");

    // Simulate
    int time = 0;
    while (!Verilated::gotFinish() && time < 1000) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(time);
        time++;
    }

    // Cleanup
    tfp->close();
    delete top;
    return 0;
}
```

## Using --binary (No Wrapper Needed)

```bash
verilator --binary --trace -j 0 top.sv
./obj_dir/Vtop
```

Verilator auto-generates `main()` when `--binary` is used.

## Simulation Runtime

### Command Line Arguments

The generated model accepts plusargs:
```bash
./obj_dir/Vtop +trace +seed=42 +firmware=test.hex
```

Access in SystemVerilog via `$value$plusargs` / `$test$plusargs`.

### Environment Variables

| Variable | Effect |
|----------|--------|
| `VERILATOR_NUMA_STRATEGY` | Thread scheduling strategy (`none` to disable) |

## Time Management

```cpp
// Using VerilatedContext (recommended for multi-instance)
VerilatedContext* contextp = new VerilatedContext;
contextp->commandArgs(argc, argv);

Vtop* top = new Vtop{contextp};

while (!contextp->gotFinish()) {
    contextp->timeInc(1);  // Advance time
    top->clk = !top->clk;
    top->eval();
}
```

## DPI-C Interface

Verilator supports DPI-C for C/C++ function calls:

```systemverilog
// In SystemVerilog
import "DPI-C" function int my_c_func(input int a);
```

```cpp
// In C++ (linked with model)
extern "C" int my_c_func(int a) {
    return a * 2;
}
```

## Assertions

Enable with `--assert`:
```bash
verilator --binary --assert top.sv
```

Assertions that fail will call `$stop` or `$fatal`.

## Coverage

Enable with `--coverage`:
```bash
verilator --binary --coverage top.sv
./obj_dir/Vtop
verilator_coverage --annotate logs/annotated coverage.dat
```
