# AI Coding Agent Guidelines

This document defines how AI coding agents should interact with and update this repository.

## Role

You are the sole author of all code, documentation, and configuration in this repository. Human contributors review and approve changes but never edit files directly.

## Repository Structure

```
ai_hw_engineer/
├── Dockerfile              — Docker image (xezim, Verilator, Yosys, SBY, Surfer)
├── docs/                   — Tool documentation (one subfolder per tool)
│   ├── xezim/
│   ├── verilator/
│   ├── yosys-symbiyosys/
│   └── surfer/
├── libs/uvm/               — UVM reference library (git submodule)
├── design/                 — Chip designs
│   ├── _template/          — Design template (copy for new chips)
│   └── <chip_name>/        — One folder per chip
├── scripts/                — Project-level utilities
├── AGENTS.md               — This file
└── CONTRIBUTING.md         — Contribution guidelines
```

## Creating a New Chip Design

1. Run `./scripts/new_design.sh <chip_name>` or manually copy `design/_template/` to `design/<chip_name>/`.
2. Fill in `spec/spec.md` with the chip specification before writing RTL.
3. Write the implementation plan in `plans/implementation_plan.md`.
4. Implement RTL in `src/`, assertions in `formal/`, testbench in `tb/`.
5. Verify: run `scripts/run_formal.sh`, then `scripts/run_sim.sh`.
6. Document results in `report/`.

## Conventions

### File Naming
- RTL: `<module_name>.sv` in `src/`
- Packages: `<chip>_pkg.sv`
- Interfaces: `<name>_if.sv`
- Testbench top: `tb_top.sv`
- UVM components: `<chip>_<component>.sv` (e.g., `fifo_driver.sv`)
- Formal properties: `<module>_props.sv`
- SBY configs: `<module>_<mode>.sby` or `<module>.sby` with tasks

### RTL Style
- SystemVerilog (IEEE 1800-2017)
- `logic` over `reg`/`wire` for internal signals
- `always_ff`, `always_comb`, `always_latch` — never bare `always`
- Active-low reset: `rst_n`, synchronous unless spec says otherwise
- One module per file
- Use parameters for configurability
- Add inline `ifdef FORMAL` assertions where appropriate

### UVM Testbench Style
- UVM 1800.2-2017 conventions
- Factory registration via `uvm_component_utils` / `uvm_object_utils`
- Config DB for virtual interfaces
- Sequences drive stimulus; drivers are protocol-only
- Scoreboards compare expected vs actual
- Coverage groups in dedicated collector components

### Formal Verification Style
- Wrap properties in `` `ifdef FORMAL `` / `` `endif ``
- Assume reset for initial cycles
- Always run cover mode to check non-vacuity
- Use `anyconst` for memory address verification
- One `.sby` file can use `[tasks]` for bmc/prove/cover

### Documentation
- All docs in Markdown
- One tool per subfolder under `docs/`
- Keep docs current when tool versions change
- Each doc file should be self-contained and useful to an AI agent

### Scripts
- Bash (POSIX-compatible where possible)
- Use `set -e` for fail-fast
- Print clear status messages
- Accept arguments for configurability
- Return nonzero on failure

## Commit Messages

Format:
```
<area>: <short description>

<optional body explaining why>
```

Areas:
- `docker` — Dockerfile changes
- `docs/<tool>` — Documentation updates
- `design/<chip>` — Chip design changes
- `scripts` — Utility script changes
- `libs` — Library updates
- `infra` — CI, gitignore, project config

Examples:
```
design/uart: implement TX datapath and FSM
docs/xezim: update UVM guide for 0.10 release
docker: add boolector solver for SymbiYosys
scripts: add lint check to run_all.sh
```

## Branch Strategy

- `main` — stable, reviewed code only
- Feature branches: `<type>/<description>` (e.g., `design/add-spi-controller`, `docs/update-verilator`)
- All changes go through pull requests
- Never push directly to `main`

## Pull Request Workflow

1. Create a feature branch from `main`
2. Make changes (you are the author)
3. Self-verify: run lint, formal, simulation as applicable
4. Push branch and open PR with clear description
5. Human reviewer approves or requests changes
6. Address feedback (you make the edits)
7. Merge after approval

## Verification Before PR

Before submitting a PR, verify:
- [ ] RTL passes `verilator --lint-only -Wall`
- [ ] Formal proofs pass (if `formal/` has `.sby` files)
- [ ] Simulation passes (if `tb/` has testbench)
- [ ] Synthesis runs without error (Yosys)
- [ ] Documentation is updated if behavior changed
- [ ] No unresolved TODOs in new code

## Updating Tools

### Updating Documentation
When a tool version changes, update the corresponding `docs/<tool>/` files. Check the tool's official docs/changelog for new features and breaking changes.

### Updating UVM Library
```bash
cd libs/uvm
git pull origin main
cd ../..
git add libs/uvm
git commit -m "libs: update UVM submodule to latest"
```

### Updating Dockerfile
When changing tool versions or adding tools:
1. Update the relevant build stage
2. Update `docs/` if CLI options changed
3. Test the build: `docker build -t ai-hw-engineer .`

## Error Handling

- If a formal proof fails, examine the counter-example trace and fix the RTL (not the assertion, unless the spec is wrong)
- If simulation fails with UVM_ERROR, trace back through the scoreboard to the root cause
- If synthesis fails, check for unsynthesizable constructs (initial blocks in RTL, delays, etc.)
- Document known issues in `report/final_report.md`

## Context for LLM Agents

When working on this repo, you have access to:
- `docs/` — comprehensive tool documentation in markdown
- `libs/uvm/` — full UVM source code for reference
- `design/_template/` — starting point for any new chip
- Shell scripts in each design's `scripts/` folder

Read the relevant `docs/<tool>/` before invoking that tool. The docs are written specifically for AI consumption.
