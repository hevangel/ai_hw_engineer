# Am9512 verification plan

## Independent functional vectors

`scripts/gen_vectors.py` implements the documented format and stack model in
Python and writes `work/vectors.txt`. `tb/tb_top.cpp` replays each vector
through the real bus and compares:

- the full 16-byte stack after the command,
- the status byte,
- END, ERR and SVREQ.

The default run contains 347 vectors: 16 directed single-precision cases,
16 directed double-precision cases, the data-manipulation and CLR cases, and
300 random arithmetic cases. The random seed is fixed for reproducibility.

Coverage includes:

- single and double add, subtract, multiply and divide,
- zero operands and the documented divide-by-zero result,
- negative operands and cancellation,
- carry out of the significand,
- exponent alignment across a wide exponent difference,
- round-to-nearest-even ties,
- the PTOS single-precision zero special case,
- POPS, POPD, XCHS, CHSS, CHSD, PTOD and CLR,
- status S/Z/U/V/D and the ERR output.

## Interface and handshake checks

The C++ testbench drives the documented active-low chip select, read, write,
C/D, EACK and SVACK signals. It checks:

- PAUSE is LOW while a selected transaction is waiting and HIGH after the
  acknowledge,
- the command write is accepted once,
- data reads return the current top byte and rotate it to the bottom,
- data writes push at the top,
- status reads return the status register,
- END is asserted at command completion and cleared by a status read,
- ERR is asserted for divide/overflow/underflow and cleared by a status read,
- SVREQ follows the command service-request bit and clears on SVACK.

## Directed command cases

The directed cases use exact values where the expected result is obvious:
1.0, 2.0, 0.5, 1.0 +/- 1.0, 1.0 * 2.0, 2.0 / 1.0, signed zero, negative
operands, the smallest positive single/double value, and the largest finite
value. The data-manipulation cases use a known four-slot stack and check the
full stack after the command.

## Formal transport proof

`formal/amd_am9512.sby` proves the transport contract with the FPU replaced by
`formal/model_fpu.sv` (free result/status, fixed two-cycle handshake):

- reset clears state, stack, status, END, ERR and SVREQ,
- after a completed arithmetic command, the stack and status match the
  documented stack model and the abstract FPU result/status,
- status bits 0 and 4 are always zero,
- state is IDLE or WAIT, and busy matches the state,
- END is not asserted while busy,
- PAUSE follows the documented CS/RD/WR/cycle-done expression.

The cover task reaches WAIT, single-add and double-divide completion, the
divide, underflow and overflow status bits, SVREQ, END and reset during a
command.

The formal proof intentionally does not check the arithmetic datapath or the
data-access stack movement in the same proof; those are covered by the
independent vector simulation. The abstract FPU is a transport model, not a
claim that the arithmetic is formally proved.

## Commands

```sh
sh design/amd_am9512/scripts/run_formal.sh
sh design/amd_am9512/scripts/run_sim.sh
sh design/amd_am9512/scripts/run_synth.sh
sh design/amd_am9512/scripts/run_all.sh
```

The scripts are intended to run in the repository toolchain container, where
`verilator`, `yosys`, `sby`, `z3` and `python3` are installed.

## Limits

- Original execution-cycle counts and analog timing are not verified.
- The overflow/underflow result encoding is a reconstruction assumption.
- The formal proof abstracts the FPU; arithmetic correctness rests on the
  independent Python oracle and the vector regression.
- The random vectors are finite samples; they do not prove an error bound for
  every representable input.