# Am9512 implementation report

## Status

Implementation and verification for the documented functional scope are
complete on branch `design/amd-am9512` in worktree
`worktree/amd-am9512`. The canonical issue is
[#120](https://github.com/hevangel/ai_hw_engineer/issues/120).

This is a synthesizable functional reconstruction, not recovered AMD microcode.
It does not claim original execution-cycle counts, propagation delays, analog
levels or physical silicon errata.

## Sources

- AMD, *Am9500 Peripheral Products Interface Guide* (1980), Am9512 chapter at
  printed pages 4-27 through 4-39 (PDF 74-86). This is the primary command,
  format, status and algorithm source.
- AMD, *Am9511A/Am9512 Floating Point Processor Manual*, Steven Cheng (May
  1981), section 5.3 and the Am9512 command descriptions. The scan is
  image-only; its readable text agrees with the 1980 chapter.
- *Electronics*, 5 July 1979, for the device description and 1979 introduction
  evidence.
- AMD Am9512 datasheet scan (same content as the 1980 chapter).

The 1980 guide is text-searchable. The 1981 manual is a scanned image; no OCR
text layer was available, so its command set and formats were cross-checked
against the 1980 chapter and the individual command bit diagrams.

## Implementation

- `src/amd_am9512.sv` — 128-bit byte stack, command decode, PAUSE/END/ERR/SVREQ,
  RESET, status register, EACK/SVACK, and data reads/writes during execution.
- `src/amd_am9512_fpu.sv` — parameterized 24-bit and 53-bit significand FPU:
  unpack/pack, exponent alignment, add/subtract, multiply, divide,
  normalization, round-to-nearest-even, overflow/underflow and divide-by-zero.
- `src/amd_am9512_divider.sv` — sequential restoring divider for the division
  quotient, including guard/round/sticky bits.
- `src/amd_am9512_commands.svh` — generated from `references/commands.csv`.
- `tb/tb_top.cpp` — replays independent vectors through the top-level bus and
  checks the full stack, status, END, ERR and SVREQ.
- `scripts/gen_vectors.py` — independent Python reference model and vector
  generator.
- `formal/` — transport proof with an abstract FPU and independent documented
  stack model.

All 16 documented commands are implemented: CLR, SADD, SSUB, SMUL, SDIV, CHSS,
PTOS, POPS, XCHS, DADD, DSUB, DMUL, DDIV, CHSD, PTOD and POPD, plus their
service-request variants.

## Verification results

All commands below were run in the repository toolchain container
(`ai-hw-engineer:latest`) from the worktree root:

```sh
sh design/amd_am9512/scripts/run_all.sh
```

The flow ran the command-table check, formal bmc/prove/cover, the independent
vector simulation and generic synthesis. Results:

- **Command table**: `generate_commands.py --check` reports the generated
  `src/amd_am9512_commands.svh` is current.
- **Lint**: `verilator --lint-only -Wall` on the top, single/double FPU and
  divider is clean (the full-flow build also passes with `-Wall`).
- **Formal bmc**: `sby -f -d work/formal/bmc amd_am9512.sby bmc` passes to
  depth 12 (z3).
- **Formal prove**: `sby -f -d work/formal/prove amd_am9512.sby prove` passes
  (ABC PDR; all outputs proved).
- **Formal cover**: `sby -f -d work/formal/cover amd_am9512.sby cover` passes;
  the cover set reaches WAIT, single-add completion, double-divide completion,
  divide/underflow/overflow status, SVREQ, END and reset during a command.
- **Simulation**: `work/sim/obj/Vamd_am9512 work/vectors.txt` passes 347
  vectors (16 directed single, 16 directed double, 15 data-manipulation/CLR,
  and 300 random arithmetic cases) with the full 16-byte stack, status, END,
  ERR and SVREQ checked.
- **Synthesis**: `yosys` generic four-LUT mapping passes `check -assert`. The
  post-synthesis hierarchy is about 90k cells (two floating-point units, two
  dividers and the stack/interface); this is a functional reconstruction, not
  an area or timing optimization.

The formal proof uses an abstract FPU model and checks the transport contract
(reset, command completion stack/status, state/status invariants, PAUSE). It
does not prove the arithmetic datapath; that is covered by the independent
Python model and the vector regression.

## Assumption ledger

The full ledger is in [spec/spec.md](../spec/spec.md). The main reconstruction
choices are:

- Clock-sampled interface with one-clock acceptance latency; physical
  asynchronous timing is outside the contract.
- RESET clears the stack; the 1980 chapter says the stack pointer is
  initialized and contents may be affected, without a required value.
- Zero is an all-zero exponent field; the mantissa is ignored for the zero
  test, and results are canonical all-zero.
- Round-to-nearest-even follows the manual's guard/round/sticky rule.
- Overflow wraps the biased exponent and sets V; underflow returns zero and
  sets U. The 1980 chapter specifies the flags but not the returned finite
  encoding. The Am9511's exponent-offset-by-128 behavior is explicitly not
  applied to the Am9512.
- Status bits not listed as affected hold; CLR clears all status and leaves the
  stack unchanged.
- ERR is latched at completion and cleared by a status read or RESET.
- No infinities, NaNs, signed zeros or subnormals are implemented.

## Limits and remaining work

- Original microcycle counts and the documented execution-time table are not
  implemented or verified.
- Analog timing, drive strength and electrical levels are outside the model.
- The overflow/underflow result encoding is a reconstruction assumption, not a
  documented Am9512 value.
- The random vectors are finite samples; they do not prove a numerical error
  bound for every representable input.
- Physical silicon errata and undocumented behavior are not modeled.
- A historical host-software regression (for example an Am9512 interface
  program from the 1981 manual) is not yet included. The current verification
  is the independent model plus directed/random vectors.

## Reproduction

The ignored `work/` directory holds the generated vectors, logs and synthesis
output. The committed sources and scripts reproduce the flow from a clean
checkout with the repository toolchain container:

```sh
docker run --rm -v "$PWD:/repo" -w /repo ai-hw-engineer:latest \
  sh design/amd_am9512/scripts/run_all.sh
```