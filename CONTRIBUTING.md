# Contributing to AI Hardware Engineer

## The One Rule

**All changes to this repository must be made by an AI coding agent.** Human contributors do not edit files directly — not code, not documentation, not configuration. If you want something changed, instruct your AI agent to make the change.

This is not a suggestion. PRs authored by humans will be rejected.

## Why?

This project explores AI-driven hardware engineering. The codebase is the artifact of AI agents working on chip design, verification, and tooling. Keeping humans out of the editing loop is the experiment.

Humans contribute by:
- Defining specifications and requirements
- Reviewing pull requests
- Approving or rejecting changes
- Filing issues with clear descriptions
- Providing feedback on AI-generated code

## How to Contribute

### 1. Fork and Clone

```bash
git clone --recurse-submodules https://github.com/<your-fork>/ai_hw_engineer.git
cd ai_hw_engineer
```

### 2. Create a Branch

```bash
git checkout -b <type>/<description>
```

Branch naming:
- `design/<chip-name>` — new chip design or changes to existing
- `docs/<topic>` — documentation updates
- `fix/<description>` — bug fixes
- `feat/<description>` — new features or tooling
- `infra/<description>` — Docker, CI, scripts

### 3. Instruct Your AI Agent

Tell your AI coding agent what you want. Examples:
- "Create a UART transmitter design with UVM testbench"
- "Add formal verification for the FIFO module"
- "Update the Verilator docs for version 5.050"
- "Fix the run_sim.sh script to support multiple seeds"

The agent reads `AGENTS.md` for coding conventions and repo structure.

### 4. Verify

Before opening a PR, the agent should verify:
- Lint passes: `verilator --lint-only -Wall`
- Formal proofs pass (if applicable)
- Simulation passes (if applicable)
- Documentation is current

### 5. Open a Pull Request

PR description must include:
- **What**: Clear description of the change
- **Why**: Motivation or issue reference
- **Verification**: What was tested and how
- **Agent**: Which AI agent authored the changes

Example:
```
## What
Added SPI controller design with full UVM testbench and formal properties.

## Why
Requested in issue #12. Needed for sensor interface on the SoC.

## Verification
- Formal: all BMC (depth 50) and prove (pdr) pass
- Simulation: 10 tests pass, 95% line coverage
- Lint: verilator --lint-only clean

## Agent
Kiro (Claude) via Kiro IDE
```

### 6. Review Process

1. Maintainers review the PR (humans review, not edit)
2. If changes are needed, the reviewer comments with feedback
3. The contributor's AI agent addresses the feedback
4. Repeat until approved
5. Maintainer merges

## What We Accept

### New Chip Designs
- Must follow `design/_template/` structure
- Must include spec, implementation plan, and test plan
- RTL must pass lint
- Formal properties encouraged (not optional for control logic)
- UVM testbench required for designs with interfaces

### Documentation Updates
- Keep in sync with tool versions
- Markdown format
- Factually accurate (cite sources for tool behavior)
- Useful to AI agents (clear, structured, with examples)

### Tool/Script Improvements
- Must work inside the Docker container
- Must handle errors gracefully
- Must print clear output

### Bug Fixes
- Include a description of the bug
- Include how to reproduce (or why it's obvious from the code)
- Include verification that the fix works

## What We Don't Accept

- Human-authored file edits (enforced by review)
- Changes without verification
- RTL that doesn't pass lint
- Testbenches that don't compile
- Documentation that contradicts tool behavior
- Breaking changes to the template without migration path

## Code of Conduct

- Be respectful in reviews and issues
- Provide constructive feedback
- Assume good intent
- Keep discussions technical

## Issue Reporting

File issues with:
- Clear title
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Environment (Docker version, host OS)
- Relevant log output

Good issue titles:
- "run_sim.sh fails when UVM_HOME has spaces in path"
- "Request: add AXI4 bus functional model to libs"
- "Formal proof timeout on arbiter_prove task"

## License

By contributing, you agree that your contributions are licensed under the same terms as the project (see [LICENSE](LICENSE) and the individual tool licenses in README.md). The repository’s project-owned structure, scripts, documentation, RTL, and verification material are licensed under the MIT License; third-party components retain their own licenses.

## Questions?

Open an issue with the `question` label.
