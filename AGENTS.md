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
├── system/                 — Historical systems built from chip designs
│   ├── README.md           — System index and integration overview
│   ├── TEMPLATE.md         — System README and screenshot conventions
│   ├── _template/          — Starting point for new systems
│   └── <system_name>/      — One folder per system
├── scripts/                — Project-level utilities
├── worktree/               — Local Git worktrees (ignored)
├── AGENTS.md               — This file
└── CONTRIBUTING.md         — Contribution guidelines
```

## GitHub issue lifecycle

Follow the cross-repository [issue lifecycle guide](https://github.com/hevangel/ai_engineer/blob/codex/issue-lifecycle-audit/spec/github_issues.md). Before substantive work, transfer a misplaced issue to its owning repository, set project Path to `ai_hw_engineer/<relative-path>`, retain/set its first actual Start date, move Status to Researching or Building, and register the working coding Agent. Keep evidence and blockers current. Clear Agent whenever work finishes/stops or is handed to inactive review; preserve Path and the first Start date. Sprint is a Scrum planning commitment, not a default assignment. Read live field options/IDs before mutations. A passing version command does not qualify a complete tool workflow; record scoped, reproducible tests and limitations.

### Using the GitHub CLI for task updates

Use `gh` to update the existing task issue and its item in the `ai_engineer`
project owned by `hevangel`. Search existing issues before creating a
duplicate, and record the canonical issue URL in the task plan or handoff.

1. Read the issue, acceptance criteria, current Agent and recent activity.
   Coordinate an existing active claim before taking ownership. Inspect live
   project fields and item IDs:

   ```sh
   gh project list --owner hevangel --format json
   gh project field-list PROJECT_NUMBER --owner hevangel --format json
   gh project item-list PROJECT_NUMBER --owner hevangel --limit 1000 --format json
   ```

   Account for pagination; a missing item in a partial listing is not proof
   that it is absent. Resolve option IDs from live definitions rather than
   copying IDs from another issue or a previous chat.
2. Keep implementation issues in `hevangel/ai_hw_engineer`. If misplaced,
   capture their existing project fields and relationships, then transfer with
   `gh issue transfer ISSUE_URL hevangel/ai_hw_engineer`. Record the returned
   URL and re-read the issue and project item IDs. Transfers can remove project
   membership: restore it with `gh project item-add`, then restore captured
   fields and relationships, preserving intentional Sprint commitments.
3. Set fields with `gh project item-edit`, supplying the discovered item,
   project and field IDs. Use `--single-select-option-id` for Agent and Status,
   `--date YYYY-MM-DD` for Start date, and `--text` for Path. Path names the
   owning repository and relative implementation location, for example
   `ai_hw_engineer/design/intel_80286`, without a host drive or worktree path.
   Preserve an evidenced first Start date on resume or transfer; follow the
   lifecycle guide's historical procedure when reconciling older work.
4. Register the working Agent and use Researching for active investigation or
   Building for implementation. Add a concise ownership comment with scope,
   branch/worktree, plan and intended checks where useful. Check recent
   comments to avoid duplicate notices on every resume. Write comment text to
   a temporary file and use `gh issue comment ISSUE_URL --body-file FILE`.
5. Update evidence, blockers and PR links at meaningful checkpoints. Keep
   partial milestones distinct from the issue's full acceptance. Use
   `AI verified` only after inspecting the required scoped evidence;
   `Human verified` requires explicit human approval. Clear Agent with
   `gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id AGENT_FIELD_ID --clear`
   when active work stops, finishes or moves to inactive review. Preserve Path,
   the first Start date and other unrelated fields.
6. Read back the saved fields and comments to verify each update. An attempted
   command does not establish success. Record an access blocker and continue
   independent work when an issue update is unavailable.

Check CLI authentication with `gh auth status`. Project edits require the
`project` scope. If missing, ask the user to run
`gh auth refresh -h github.com -s project` and complete browser authorization.
Distinguish network or sandbox access failures from invalid credentials before
asking the user to log in again.

## Creating a New Chip Design

1. Run `./scripts/new_design.sh <chip_name>` or manually copy `design/_template/` to `design/<chip_name>/`.
2. Fill in `spec/spec.md` with the chip specification before writing RTL.
3. Write the implementation plan in `plans/implementation_plan.md`.
4. Implement RTL in `src/`, assertions in `formal/`, testbench in `tb/`.
5. Verify: run `scripts/run_formal.sh`, then `scripts/run_sim.sh`.
6. Document results in `report/`.

## Creating and Maintaining Systems

Systems live under `system/<system_name>/` and integrate chip designs from
`design/` with memory, peripherals, authentic firmware and host interfaces.
Read [the system index](system/README.md), [system conventions](system/TEMPLATE.md)
and any instructions local to the system before changing it.

1. Run `./scripts/new_system.sh <system_name>` to copy `system/_template/`.
   The scaffold provides documentation and empty implementation folders;
   it does not provide runnable hardware or verification scripts.
2. Complete `spec/spec.md` before writing RTL. Define the target machine,
   hardware scope, reused chips, clocks, reset, buses, memory map and
   peripheral connections. Record reference sources, firmware provenance,
   assumptions and unsupported behavior.
3. Write `plans/implementation_plan.md` and `plans/testplan.md`. Plan chip
   integration, host interfaces, independent checks and real-software
   regressions; add a formal plan where applicable.
4. Implement system RTL in `src/`, testbenches in `tb/`, applicable assertions
   in `formal/`, and the front panel, media/input bridges and waveform capture
   in `host/`. Reuse shared chip implementations from `design/`; make chip
   fixes in the owning design and run its relevant regressions as well.
5. Add verification entry points under the system's `scripts/`. Run simulation
   and authentic firmware/software regressions, formal checks where applicable,
   and synthesis. Record exact commands, inputs, results, evidence and known
   limits in `report/final_report.md`; do not treat scaffolding or a successful
   image build as proof that a system works.
6. Maintain the system README with sourced history and introduction year,
   important chips, implementation status, reproducible launch commands,
   firmware requirements, verification boundaries and links to existing docs.
   Update `system/README.md` when adding a system or changing its indexed details.

Every system README must include a **Web interface and waveform** section.
Follow `system/TEMPLATE.md` for real screenshot assets and reproduction details.
If the web interface or waveform capture is unavailable, state that explicitly;
do not use mockups or broken image links as evidence of implemented behavior.
Keep generated artifacts and copyrighted firmware downloads in ignored `work/`
directories where required by the system's provenance manifest; document how
to obtain required inputs legally.

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
- Maintain `design/README.md` as the chip index; every entry must list the chip, its function, its first-introduced year, and a link to the design folder.
- Every `design/<chip_name>/` folder must contain a `README.md` with historical context, why the chip is important, the first-introduced year, source links, and links to the folder's relevant Markdown documents.
- When adding or changing a chip design, update both the design index and the chip README. Historical dates must be sourced and any uncertainty, such as disagreement over the exact month, must be stated rather than guessed.

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
- `system/<system>` — System integration, host interfaces and verification
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
- Create a Git worktree for each task under the owning repository's ignored
  `worktree/` folder. Keep the primary checkout on `main`; make task changes
  and run verification in the task worktree.

  ```sh
  git fetch origin
  mkdir -p worktree
  git worktree add -b <type>/<description> worktree/<task-name> origin/main
  cd worktree/<task-name>
  ```

- Run these commands from the primary repository checkout. Reuse an existing
  task worktree when continuing its branch; do not create nested worktrees.
  Keep commits, pushes and pull requests scoped to the owning repository.
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

Use `./scripts/update_tool_docs.sh --tool <name> --dry-run` to preview fresh
upstream references, then omit `--dry-run` to write them under
`docs/<tool>/upstream/`. See [docs/README.md](docs/README.md) for setup and source
mappings. Preserve the maintained project guides; review upstream changes
against the pinned tool versions before updating project-specific commands.

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

## Learning From Escaped Defects

A bug found by anything other than the design's own verification suite
(real firmware, a third-party tool, an external reviewer) is an escaped
defect: write a post-mortem in `failure_notes/` (convention and template in
`failure_notes/README.md`). For CPU and processor-like designs, these rules
are mandatory because per-instruction agreement against a self-written
reference model cannot catch shared misreadings (see
`failure_notes/2026-09-02-intel4004-fin-pc-advance.md` for the FIN incident):

- **Real-software regression**: the design's `run_all.sh` must run actual
  historical software for the device, not only per-instruction tests.
- **Independent-oracle reference models**: the ISS / formal golden model
  must be derived from an external artifact (manufacturer disassembly,
  third-party emulator, recovered code traces) — never by re-reading the
  RTL. When a semantic fix changes RTL and model together, cite the
  external source that pins the new behavior.
- **Assumption ledger**: any behavior the primary documentation does not
  explicitly state gets an `ASSUMPTION:` comment in the RTL, an entry in
  the design spec, and validation against real code before sign-off.
- **No land-tolerant CPU tests**: instruction tests assert the exact
  post-instruction PC and next-executed instruction; padding placed to
  absorb unknown PC landings is a defect in the test.

## Context for LLM Agents

When working on this repo, you have access to:
- `docs/` — comprehensive tool documentation in markdown
- `libs/uvm/` — full UVM source code for reference
- `design/_template/` — starting point for any new chip
- `system/_template/` — starting point for any new system
- `system/TEMPLATE.md` — system README and screenshot conventions
- Shell scripts in each design's `scripts/` folder
- Shell scripts in each system's `scripts/` folder

Read the relevant `docs/<tool>/` before invoking that tool. The docs are written specifically for AI consumption.
