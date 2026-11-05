# Implementation plan — PDP-8 Am29xx reconstruction

## 1. Scope

Build a 1965 PDP-8 from three Am2901 4-bit slices and an Am2910 sequencer,
with microcoded fetch/defer/execute, a 4K core, a front panel, an ASR-33
console and paper-tape devices, verified against an independent instruction-set
model. The machine profile and its assumption ledger are in
[../spec/spec.md](../spec/spec.md).

Out of scope for this milestone: EAE, memory extension, user mode/time sharing,
disk or DECtape controllers, cycle-accurate timing, FPGA deployment.

## 2. Build order

1. **Pin the profile.** Read the DEC handbook material, Jones's FAQ and
   microcode notes, and the SIMH CPU/device sources. Record the straight-8
   decisions (no EAE, no byte swap, 4K single field) in the specification.
2. **Reference model first.** Write `scripts/pdp8_ref.py` from those external
   sources so every later RTL decision can be compared against something that
   was not derived from the RTL.
3. **Sequencer adapter.** Wrap the Am2910 model so its Y/CI convention is
   explicit, and prove the jump/call/return order with `tb/tb_seq.sv` before any
   CPU code exists.
4. **Control store.** Define the 72-bit microinstruction, write the assembler
   (`scripts/gen_microcode.py`) and the microprogram (`src/pdp8_microcode.asm`).
5. **Datapath.** Three slices, external PC/MA/MB/IR/LINK, the link hold
   register, condition-code selection and the console strobe path.
6. **Memory and console.** 4K core with a one-cycle registered read, the four
   device numbers, and the front-panel keys/lamps.
7. **Trace port.** Sample the accumulator on the instruction-boundary
   microinstruction so the testbench can compare exact architectural state.
8. **Verification.** Exhaustive operate encodings, directed addressing and
   control programs, random programs, panel and interrupt tests, synthesis.
9. **Host integration.** A persistent simulator with a line protocol, a Python
   HTTP front panel and a waveform view.

## 3. Key design decisions

| Decision | Alternative | Why |
| --- | --- | --- |
| External PC/MA/MB/IR, accumulator in the slice file | Put everything in the slice register file | The 2901 has one write port per cycle and its Y bus is the natural data bus; the original machine also keeps PC/MA/MB as separate registers. This keeps the microcode one write per cycle. |
| One microinstruction per clock, two-phase commit on the falling edge | Extra phase generator | Matches the slice model's documented latch behaviour and keeps the sequencer's address stable. |
| Conditional-jump dispatch tree | Am2910 JMAP with a map ROM | The map ROM must be addressed by the machine opcode, not by the 2910 instruction field; a conditional tree stays inside the documented sequencer behaviour. Costs three cycles per instruction. |
| Exhaustive operate-encoding tests | Random sampling | The two operate groups are small enough to enumerate, and they contain the carry/link combinations most likely to be wrong. |
| Reference model from SIMH sources | Derive expectations from the RTL | The RTL would then be its own oracle. |

## 4. Defects found during implementation

These were caught by the cross-check and fixed; they are recorded because they
show which parts of the design are fragile.

1. **Page-zero addressing used the current page.** The effective-address mux
   always concatenated the instruction page with the offset; `TAD 020` from
   page 1 read `220`. Caught by the first directed addressing test.
2. **TAD treated the link as a carry input.** `L'AC + M` puts the link at bit
   12, not at the adder's carry-in, so a set link produced `AC + M + 1`. Caught
   by the group-2 test that starts with LINK = 1.
3. **CLA mask used bit 8 instead of bit 7.** `0200` is bit 7; bit 8 is the
   indirect bit of memory-reference instructions.
4. **Link changed under the slice write phase.** The link updates on the same
   edge on which the slice latches its shift and carry inputs, so the written
   word could change after the edge. Fixed with `l_hold`, captured on the rising
   edge. This was the cause of every remaining rotate/compare mismatch.
5. **Accumulator observability used the Y bus indiscriminately.** The slice
   drives Y from the A latch for destination code 2 and from the shifted word
   for codes 4-7, so a mirror register diverged. Replaced by sampling the
   accumulator on the dedicated boundary microinstruction.
6. **Single-step executed one instruction too many.** The stop was applied at
   the boundary microinstruction but the fetch continued; a post-retire `go`
   check now stops before the next instruction is fetched.
7. **Console strobe zeroed the printed byte.** The I/O strobe override forced
   the ALU to zero for the KCC case and for every device; it now only forces
   zero when the device clears the accumulator.

## 5. Follow-up work

- Paper-tape binary loader and a historically sourced program (FOCAL-69 and the
  *Lunar Lander* listing) on the qualified profile.
- DEC MAINDEC diagnostics as an additional independent oracle.
- EAE as a separate, explicitly qualified profile.
- Optional `formal/` properties on the microsequencer and the operate group-1
  merge network.
