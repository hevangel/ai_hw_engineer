# AI Hardware Engineer

> An open-source experiment in asking frontier models to design and verify hardware—one historically significant chip at a time.

## What this repository is

This is not merely a workspace containing files for an AI hardware engineer. **This repository is the AI hardware engineer.** Its specifications, plans, tool documentation, templates, scripts, RTL, verification environments, and reports are the working context that the engineer is expected to use.

The central hypothesis is intentionally ambitious:

> Give a capable frontier model enough clear engineering information, open-source tools, and public documentation, and it may be able to take a chip from specification to verified RTL with surprisingly little hand-holding.

This project is a way to test that hypothesis in public, with waveforms and failed builds doing the arguing.

## The experiment

The repository will gradually recreate and study well-known chips and architectures from computing history. The pace is deliberately slow and methodical: one design, one specification, one verification flow, and one report at a time. The goal is not to produce a collection of impressive-looking RTL files. The goal is to find out how far a frontier model can carry the complete engineering process by itself.

For each design, the intended flow is:

1. Read the specification and available public reference material.
2. Write an implementation, test, and formal-verification plan.
3. Implement the RTL in SystemVerilog.
4. Build simulation and formal verification environments.
5. Run simulation, formal checks, coverage, and synthesis.
6. Investigate failures instead of politely stepping around them.
7. Document the result, limitations, and lessons learned.

A passing testbench is useful evidence. It is not a passport to a fabrication plant.

## No prompt-engineering obstacle course

The model will be instructed much as an engineering intern or student would be instructed:

> Read the specification, make a plan, implement the design, verify it, fix what fails, and explain the result.

There will be no proprietary knowledge, secret methodology, or elaborate prompt ritual hidden behind the curtain. The project will rely on:

- Open-source EDA tools and verification infrastructure.
- The documentation for those tools, kept in this repository where practical.
- Public datasheets, reference manuals, and other legally available technical material.
- Engineering textbooks and other educational references as the project grows.

The intention is to measure engineering capability, not prompt-writing capability. If the model needs a 37-step incantation before it can write an adder, that is an interesting result—but it is not the experiment being run here.

## What counts as success

Success is more than generating syntactically plausible Verilog. A useful result should show that the model can:

- Understand an imperfect or historically styled specification.
- Make design decisions and record them clearly.
- Produce synthesizable RTL with sensible structure.
- Create meaningful simulation and formal checks.
- Use failures and counterexamples to improve the implementation.
- Run the open-source toolchain reproducibly.
- Explain what was verified, what was not, and where uncertainty remains.

The model may occasionally be brilliant, occasionally be baffling, and occasionally produce a circuit that is technically legal but spiritually concerning. All three outcomes are data.

## Open-source by design

The project deliberately avoids dependence on proprietary EDA software or private engineering folklore. The repository itself is meant to provide enough orientation for an AI system—and a human contributor—to understand the workflow.

The current foundation includes:

- Tool documentation under `docs/`.
- Reusable chip-design conventions and templates under `design/`.
- Project-level utility scripts under `scripts/`.
- Open-source RTL simulation, synthesis, formal-verification, waveform, and UVM resources.
- Plans and reports that preserve the reasoning and evidence for each design.

The project is an engineering experiment, not a claim that open-source tools or model-generated RTL are automatically production-ready. Reproducibility, review, and honest reports matter more than heroic demos.

## Quick start

Build the container with the open-source toolchain after initializing the pinned UVM submodule:

```bash
git submodule update --init --recursive
docker build -t ai-hw-engineer .
```

Run an interactive project environment:

```bash
docker run -it -v $(pwd):/workspace ai-hw-engineer
```

Create a new chip design from the project template:

```bash
./scripts/new_design.sh my_chip
```

Create a new system scaffold from the shared system template:

```bash
./scripts/new_system.sh my_system
```

## Repository structure

```text
ai_hw_engineer/
├── Dockerfile              — Reproducible image with the EDA toolchain
├── README.md               — Project purpose, method, and usage
├── AGENTS.md               — Repository instructions for AI coding agents
├── CONTRIBUTING.md         — Contribution and review guidelines
├── LICENSE                 — Project license
├── docs/                   — Documentation for the tools used by the engineer
│   ├── eqy/                — Formal equivalence checking with Yosys
│   ├── surfer/             — Surfer waveform viewer and self-hosted web setup
│   ├── uvm/                — UVM reference-library usage
│   ├── verible/            — SystemVerilog lint and formatting utilities
│   ├── verilator/          — Verilator compiler and simulator
│   ├── xezim/              — Xezim SystemVerilog simulator
│   ├── yosys-symbiyosys/   — Synthesis and formal-verification documentation
│   └── toolchain-releases.md — Pinned versions and upstream sources
├── libs/                   — Reference libraries
│   └── uvm/                — Pinned UVM reference-library submodule
├── design/                 — Chip designs, one project per chip
│   ├── README.md           — Chip index, introduction years, and source notes
│   ├── TEMPLATE.md         — Design-folder conventions
│   ├── _template/          — Starting point for new designs
│   └── <chip_name>/        — Historical CPUs, peripherals, and logic chips
├── system/                 — Historical systems built from chip designs
│   ├── README.md           — System index and integration overview
│   ├── TEMPLATE.md         — System README and screenshot conventions
│   ├── _template/          — Starting point for new systems
│   └── <system>/           — One folder per historical system
├── references/             — Shared manufacturer manuals and datasheets
├── plans/                  — Repository-wide design-series plans
├── failure_notes/          — Escaped-defect post-mortems and prevention rules
├── semantic-review/        — Recorded semantic code reviews
├── session_history/        — Engineering session records
└── scripts/                — Project-level utility scripts
```

The tree shows maintained source and documentation; local scratch folders,
caches, and generated build outputs are omitted. Browse the
[chip index](design/README.md) and [system index](system/README.md) for project
details, historical sources, and verification boundaries.

Each chip project lives under `design/<chip_name>/`, following the shared
template and adding references or other support folders as needed:

```text
design/<chip_name>/
├── README.md   — Historical context, sources, and design documentation links
├── spec/       — Chip specification and reference material
├── src/        — SystemVerilog RTL
├── tb/         — Simulation and UVM testbench
├── formal/     — SVA assertions and .sby files
├── scripts/    — Simulation, formal, synthesis, and coverage scripts
├── plans/      — Implementation, test, and formal plans
└── report/     — Verification results and final sign-off report
```

System projects live under `system/<system_name>/`. They use the same
specification, planning, RTL, testbench, scripts, and report conventions, with
`formal/` where applicable and `host/` for web front panels and DPI bridges.
System reference material is typically stored under `spec/reference/`.
Available folders and verification flows vary by project; start with its
`README.md`.

## Standard design workflow

```text
1. Spec          — Define the chip in design/<chip>/spec/
2. Plan          — Write implementation, test, and formal plans
3. RTL           — Implement the design in design/<chip>/src/
4. Formal first  — Add properties and find bugs early with SymbiYosys
5. UVM TB        — Build the testbench in design/<chip>/tb/
6. Simulate      — Run with Xezim, or use Verilator for speed
7. Coverage      — Analyze and close meaningful coverage gaps
8. Synthesize    — Confirm synthesis with Yosys
9. Report        — Record evidence, limitations, and final results
```

## Standard system workflow

```text
1. Scaffold      — Run ./scripts/new_system.sh <system_name>
2. Spec          — Define hardware, buses, memory map, and scope in spec/
3. References    — Record historical sources and firmware provenance
4. Plan          — Plan chip reuse, integration, host interfaces, and verification
5. Integrate     — Connect chip RTL, clocks, reset, memory, and peripherals in src/
6. Host          — Build the front panel, media/input bridge, and waveform capture
7. Verify        — Run simulation, real-software regressions, formal where applicable, and synthesis
8. Document      — Record results and limits; add a real screenshot when available
9. Index         — Update the system README and system/README.md with sourced details
```

Work within `system/<system_name>/` after creating the scaffold. Follow
[the system README conventions](system/TEMPLATE.md) when documenting the web
interface, waveform capture, launch commands, and verification boundaries.

## Open-source toolchain

| Tool | Purpose | Documentation |
|------|---------|---------------|
| **Xezim** | 4-state event-driven SystemVerilog simulator written in Rust | `docs/xezim/` |
| **Verilator** | Fast cycle-accurate SystemVerilog-to-C++ compiler | `docs/verilator/` |
| **Yosys** | Open-source RTL synthesis framework | `docs/yosys-symbiyosys/` |
| **SymbiYosys** | Formal-verification front end for BMC, proving, and cover | `docs/yosys-symbiyosys/` |
| **Surfer** | Waveform viewer for VCD and FST files | `docs/surfer/` |
| **Verible** | SystemVerilog lint, formatting, and syntax utilities | `docs/verible/` |
| **UVM** | IEEE verification methodology reference libraries | `docs/uvm/USAGE.md` |

## UVM reference library

The UVM reference library is available under `libs/uvm/`. The recommended version for new work is **IEEE 1800.2-2017**.

```bash
export UVM_HOME=$(pwd)/libs/uvm/1800.2-2017

xezim --simulate -s tb_top \
  -I $UVM_HOME/src -D UVM_NO_DPI \
  $UVM_HOME/src/uvm_pkg.sv \
  design/<chip>/src/*.sv design/<chip>/tb/*.sv \
  +UVM_TESTNAME=my_test
```

## Running a chip project

From a design directory:

### Simulation

```bash
cd design/<chip>
./scripts/run_sim.sh [all|exhaustive|uvm]
```

### Formal verification

```bash
cd design/<chip>
./scripts/run_formal.sh
```

### Synthesis

```bash
cd design/<chip>
./scripts/run_synth.sh
```

### Full flow

```bash
cd design/<chip>
./scripts/run_all.sh
```

## Docker image contents

Refresh tool release pins, this version list, and the release manifest, then
build the local image from a feature branch (Python 3.11+, Git, and Docker required):

```bash
./scripts/update_docker.sh --dry-run  # Preview changes without writing or building
./scripts/update_docker.sh            # Update files and build ai-hw-engineer:latest
./scripts/update_docker.sh --no-build # Update files only
```

Use `--image <tag>` to choose the local image tag. Optional `GITHUB_TOKEN`
authentication raises GitHub API rate limits. Ubuntu, APT snapshot, and UVM
pins stay unchanged. If SBY or EQY has no standalone release, its existing
snapshot stays pinned. Review release notes and tool documentation when
upgrading; changed build recipes or archive names may require manual updates
by the coding agent. A failed build returns nonzero and leaves the updated
files available for review; it does not establish toolchain compatibility.

The Dockerfile builds a multi-stage image containing:

- **Verilator 5.052** — built from the pinned published release.
- **Yosys 0.69** — built from the pinned published release.
- **SymbiYosys** — pinned source revision with the Z3 and ABC engines.
- **Xezim 0.11.3** — pinned source revision with JIT support.
- **Surfer 0.7.0** — pinned source revision.
- **Verible** — pinned static release binaries.
- **UVM** — the repository's pinned submodule copied to `/opt/uvm`.

The [release manifest](docs/toolchain-releases.md) records all versions, upstream
sources, snapshot exceptions, and the Ubuntu package snapshot used by this build.

Exact tool behavior and invocation details belong in `docs/`, because asking an AI to use a tool without giving it the manual is a little like hiring an intern and hiding the keyboard.

Refresh upstream Markdown references alongside the maintained tool guides with
`./scripts/update_tool_docs.sh`; use `--tool <name>` to select a tool or
`--dry-run` to preview changes. See [the documentation updater guide](docs/README.md)
for prerequisites and source mappings.

## Scope and limitations

This project evaluates autonomous hardware engineering in an open, reproducible setting. It does not claim that:

- Simulation covers every possible hardware failure.
- A formal proof is stronger than the property or assumptions supplied to it.
- Historical reimplementations are drop-in replacements for original silicon.
- Passing synthesis is equivalent to timing closure, physical design, or tapeout.
- A frontier model will succeed on every design—or even on the next one.

Those limitations are part of the experiment. They should be documented, not edited out of the final report because they make the chart look untidy.

## License

Project-owned material in this repository is licensed under the [MIT License](LICENSE). The repository also includes third-party open-source tools and references; see the applicable files and upstream projects for their complete license terms.

- Project-owned material: MIT (see [LICENSE](LICENSE))
- Xezim: Apache-2.0
- Verilator: LGPL-3.0 or Artistic-2.0
- Yosys: ISC
- SymbiYosys: ISC
- Surfer: EUPL-1.2
- UVM: Apache-2.0

The EDA Docker image also includes a [headless Java JDK](docs/java/README.md) (`java` and `javac`) for independent hardware reference oracles such as Am2901.
