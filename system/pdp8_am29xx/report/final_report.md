# Verification report — PDP-8 Am29xx reconstruction

Date: 2026-11-04. Toolchain: Verilator 5.052, Yosys 0.69, Python 3.13, inside
the repository's `ai-hw-engineer` image.

## 1. What exists

| File | Role |
| --- | --- |
| `src/pdp8_microcode.asm` | Microprogram source (87 microinstructions) |
| `scripts/gen_microcode.py` | Microassembler, field definitions, listing |
| `src/pdp8_ucode.sv` | Generated control store (do not edit) |
| `src/pdp8_sequencer.sv` | Am2910 adapter, CI convention and micro-PC mirror |
| `src/pdp8_cpu.sv` | Three Am2901 slices, external registers, gating, console path |
| `src/pdp8_core.sv` | 4096 x 12 core memory |
| `src/pdp8_console.sv` | Devices 01-04, flags, interrupt request |
| `src/pdp8_panel.sv` | Front-panel keys, lamps, examine/deposit walk |
| `src/pdp8_top.sv` | Board-level wiring |
| `tb/tb_seq.sv` | Sequencer unit test |
| `tb/tb_top.sv` | Program runner with per-instruction trace |
| `tb/tb_panel.sv` | Panel and interrupt sequence |
| `scripts/pdp8_ref.py` | Independent instruction-set model (oracle) |
| `scripts/run_isa_tests.py` | Test generator and trace comparator |
| `host/simulator.cpp`, `host/server.py`, `host/web/` | Web front panel |

## 2. Commands and results

```
$ sh scripts/run_all.sh
== Microcode
assembled 87 microinstructions, 43 labels
== Build
PASS: models built
== Instruction-set agreement (RTL vs independent ISS)
opr_group1       PASS  (1537 instructions)
opr_group2       PASS  (865 instructions)
addressing       PASS  (35 instructions)
control          PASS  (20 instructions)
random_000..039  PASS  (45-50 instructions each)
console_print    PASS  tty=b'HI'
console_echo     PASS  tty=b'Z'
reader_fetch     PASS
47 passed, 0 failed
== Front panel and interrupt
PASS: panel store/examine/start/step and interrupt
== Synthesis
Synthesis OK
PASS: PDP-8 reconstruction verification complete
```

Synthesis (generic gate mapping with `abc`, core memory as an external
interface): **4,829 LUT4 cells, 216 latches (the slice register file) and 319
flip-flops, 5,365 cells in total**, plus the black-boxed 4K memory.

Sequencer unit test, executed while bringing the design up:

```
$ ./work/seq/Vtb_seq
PASS: sequencer jump/call/return order
```

## 3. Evidence interpretation

- The instruction-set tests compare **PC, AC and LINK at every instruction
  boundary** against a model written from DEC/SIMH documentation. A mismatch in
  a single micro-operation, carry, skip or addressing mode fails the test.
  The exhaustive operate runs cover 256 group-1 encodings from two states and
  64 group-2 encodings from three states.
- The panel test drives the real key/switch path, including the DEPOSIT walk,
  EXAMINE read-back, single-step boundaries and interrupt entry. It confirms
  the saved return address in location 0 and the handler's punch output.
- Everything above is RTL behaviour; no result in this report comes from a
  behavioural substitute for the CPU.

## 4. Known limitations and unverified behaviour

These are recorded rather than hidden:

1. **No historical software has been booted.** Milestone 4 of the tracking
   issue (binary paper-tape loader, FOCAL-69, the *Lunar Lander* listing and
   its transcript) is **not done**. The console and reader are exercised only
   by the short directed programs above.
2. **No DEC MAINDEC diagnostic has been run.** Agreement with SIMH is not the
   same as agreement with the hardware. The assumption ledger in the
   specification lists every behaviour where only one external source pins the
   answer.
3. **No EAE.** Group 3 is a no-op, which is correct for a machine without the
   option, but it means this reconstruction cannot run software that requires
   the EAE.
4. **Not cycle accurate.** A memory-reference instruction takes roughly 12-18
   clock cycles in this microcode; the original takes two or three memory
   cycles. Character timing is instantaneous.
5. **The interrupt test is directed, not exhaustive.** Nested interrupts,
   interrupts during the defer state and device-flag races are not covered.
6. **The 2901/2910 models are reused from `design/amd_am29xx`.** Their
   correctness is established by their own specifications, formal proofs and
   tests, not by this system's tests. This system adds the observation that
   three cascaded slices reproduce the PDP-8 arithmetic across 47 tests.
7. **The front panel is functional, not physical.** One switch register instead
   of separate address/data rows; no switch bounce, no lamp driver delays.
8. **No formal properties for the system.** `formal/` is empty; the reused
   chip models carry their own proofs.

## 5. Reproduction

```
docker run --rm -v "$PWD:/repo" -w /repo ai-hw-engineer:latest \
  sh system/pdp8_am29xx/scripts/run_all.sh
```

or, for the web panel:

```
sh system/pdp8_am29xx/scripts/build.sh
PDP8_PORT=8099 python3 system/pdp8_am29xx/host/server.py
# open http://localhost:8099/?run=1
```
