# AI Hardware Engineer Workspace

A complete environment for AI-driven RTL design, verification, and formal analysis.

## Quick Start

```bash
# Build Docker image with all tools
docker build -t ai-hw-engineer .

# Run interactive session
docker run -it -v $(pwd):/workspace ai-hw-engineer

# Create a new chip design
./scripts/new_design.sh my_chip
```

## Workspace Structure

```
ai_hw_engineer/
├── Dockerfile              — Docker image with all EDA tools
├── README.md               — This file
├── docs/                   — Tool documentation (markdown)
│   ├── xezim/             — Xezim SystemVerilog simulator
│   ├── verilator/         — Verilator compiler/simulator
│   ├── yosys-symbiyosys/  — Yosys synthesis + SymbiYosys formal
│   └── surfer/            — Surfer waveform viewer
├── libs/                   — Reference libraries
│   └── uvm/               — UVM reference (1.1d, 1.2, 1800.2-2017, 1800.2-2020)
├── design/                 — Chip designs (one folder per chip)
│   ├── TEMPLATE.md        — Design folder conventions
│   └── _template/         — Template for new designs
└── scripts/                — Project-level utility scripts
    └── new_design.sh      — Create new chip design from template
```

## Design Folder Structure

Each chip design lives under `design/<chip_name>/`:

```
design/<chip_name>/
├── spec/       — Chip specification
├── src/        — RTL source (SystemVerilog)
├── tb/         — UVM testbench
├── formal/     — SVA assertions + .sby files
├── scripts/    — Run scripts (sim, formal, synth, coverage)
├── plans/      — Implementation plan, test plan, formal plan
└── report/     — Coverage reports and final sign-off report
```

## Tools

| Tool | Purpose | Docs |
|------|---------|------|
| **Xezim** | 4-state event-driven SystemVerilog simulator (Rust) | `docs/xezim/` |
| **Verilator** | Fast cycle-accurate SV-to-C++ compiler | `docs/verilator/` |
| **Yosys** | Open-source RTL synthesis framework | `docs/yosys-symbiyosys/` |
| **SymbiYosys** | Formal verification front-end (BMC, prove, cover) | `docs/yosys-symbiyosys/` |
| **Surfer** | Modern waveform viewer (VCD, FST) | `docs/surfer/` |

## Typical Workflow

```
1. Spec          — Define the chip in design/<chip>/spec/
2. Plan          — Write implementation + test + formal plans
3. RTL           — Implement in design/<chip>/src/
4. Formal first  — Add SVA, run SymbiYosys → fix bugs early
5. UVM TB        — Build testbench in design/<chip>/tb/
6. Simulate      — Run with xezim (or Verilator for speed)
7. Coverage      — Analyze and close coverage holes
8. Synthesize    — Confirm synthesis with Yosys
9. Report        — Document results in design/<chip>/report/
```

## UVM Library

The UVM reference library is at `libs/uvm/`. Recommended version: **1800.2-2017**.

```bash
# Set UVM path for simulation scripts
export UVM_HOME=$(pwd)/libs/uvm/1800.2-2017

# Run UVM testbench with xezim
xezim --simulate -s tb_top \
  -I $UVM_HOME/src -D UVM_NO_DPI \
  $UVM_HOME/src/uvm_pkg.sv \
  design/<chip>/src/*.sv design/<chip>/tb/*.sv \
  +UVM_TESTNAME=my_test
```

## Running Tools

### Simulation (xezim)
```bash
cd design/<chip>
./scripts/run_sim.sh <test_name>
```

### Formal Verification (SymbiYosys)
```bash
cd design/<chip>
./scripts/run_formal.sh
```

### Synthesis (Yosys)
```bash
cd design/<chip>
./scripts/run_synth.sh generic
```

### Full Flow
```bash
cd design/<chip>
./scripts/run_all.sh
```

## Docker Image Contents

The Dockerfile builds a multi-stage image with:
- **Verilator** (latest stable) — from source
- **Yosys** — from source
- **SymbiYosys** — with Z3 and Yices2 solvers
- **Xezim** — with JIT/AOT support
- **Surfer** — waveform viewer
- **UVM** — all versions pre-cloned at `/opt/uvm`

## License

- Xezim: Apache-2.0
- Verilator: LGPL-3.0 or Artistic-2.0
- Yosys: ISC
- SymbiYosys: ISC
- Surfer: EUPL-1.2
- UVM: Apache-2.0
