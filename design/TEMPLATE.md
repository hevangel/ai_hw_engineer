# Design Folder Template

Each chip design is stored in a folder named after the chip within this `design/` directory.

## Directory Structure

```
design/<chip_name>/
├── spec/          — Chip specification documents
├── src/           — RTL source code (SystemVerilog)
├── tb/            — UVM testbench code
├── formal/        — Formal verification assertions and properties
├── scripts/       — Shell scripts to run tools
├── plans/         — Implementation plan, test plan, formal plan
└── report/        — Coverage reports and final design report
```

## Creating a New Chip Design

To create a new chip design, copy this template structure:

```bash
# Replace <chip_name> with your actual chip name
mkdir -p design/<chip_name>/{spec,src,tb,formal,scripts,plans,report}
```

Or use the provided script:
```bash
./scripts/new_design.sh <chip_name>
```

## Folder Contents

### spec/
- `spec.md` — Main chip specification
- `interfaces.md` — Port/interface definitions
- `registers.md` — Register map (if applicable)
- `timing.md` — Timing constraints and requirements

### src/
- RTL source files (`.sv`, `.v`)
- Package files (`*_pkg.sv`)
- Interface definitions (`*_if.sv`)

### tb/
- UVM testbench top (`tb_top.sv`)
- UVM environment (`*_env.sv`)
- UVM agents (`*_agent.sv`, `*_driver.sv`, `*_monitor.sv`)
- UVM sequences (`*_seq.sv`)
- UVM tests (`*_test.sv`)
- UVM scoreboards (`*_scoreboard.sv`)

### formal/
- SVA property files (`*_props.sv`)
- SymbiYosys configuration files (`*.sby`)
- Formal bind modules (`*_bind.sv`)

### scripts/
- `run_sim.sh` — Run simulation with xezim or Verilator
- `run_formal.sh` — Run formal verification with SymbiYosys
- `run_synth.sh` — Run synthesis with Yosys
- `run_coverage.sh` — Generate coverage reports
- `run_all.sh` — Run complete verification flow

### plans/
- `implementation_plan.md` — RTL implementation plan and schedule
- `testplan.md` — Verification test plan
- `formal_plan.md` — Formal verification plan

### report/
- `coverage_report.md` — Coverage metrics and analysis
- `final_report.md` — Final design summary and sign-off status
- `coverage/` — Raw coverage data files
