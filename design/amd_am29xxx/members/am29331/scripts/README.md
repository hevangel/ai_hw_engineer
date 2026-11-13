# Am29331 scripts

- `generate_oracle.py` — interprets `references/instructions.csv` (AMD
  Tables 1/2 transcription). With no arguments it writes deterministic
  transition vectors to `work/sim/vectors.txt`; `--write-table` regenerates
  `formal/table_oracle.svh`; `--check-table` asserts the committed formal
  oracle still matches the CSV.
- `run_sim.sh` — regenerates vectors, builds the C++ testbench with
  Verilator, runs the 81,960-vector transition matrix plus the historical
  Figure 3 microcode flows, interrupt/trap flows, stack envelope and
  master/slave checks, and requires `TEST PASSED:`.
- `run_formal.sh` — checks the formal oracle against the CSV, then runs
  SymbiYosys tasks bmc (smtbmc z3, depth 16), prove (abc pdr) and cover
  (smtbmc z3) into `work/formal/`.
- `run_synth.sh` — Yosys `synth; check -assert; stat` into
  `work/synth/synth.log`.
- `run_all.sh` — lint (`verilator --lint-only -Wall`), then formal,
  simulation and synthesis in that order.

Run inside the repository toolchain image; generated artifacts stay under
the member's ignored `work/` directory.
