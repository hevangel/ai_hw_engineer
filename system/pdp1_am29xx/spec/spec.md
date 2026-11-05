# PDP-1 Am29xx bit-slice reconstruction — specification

Status: implementation in progress. This document is the contract for
`system/pdp1_am29xx/`. It follows the owning issue
[#184](https://github.com/hevangel/ai_engineer/issues/184) and the Am29xx
family tracker [#7](https://github.com/hevangel/ai_engineer/issues/7).

## 1. What this machine is

A functional reconstruction of a **DEC PDP-1** built from five AMD Am2901
four-bit processor slices, one Am2910 microsequencer and qualified glue
logic, with a synthesizable SystemVerilog datapath. It executes the 1961
PDP-1 instruction set from a microcode control store, drives an 18-bit
architectural register file, 4096 words of core memory, the standard
console and the standard I/O devices, and exposes a web front panel with
register, paper-tape, typewriter, display and waveform views.

The physical machine is **not** a copy of a PDP-1. The original 1959–1961
PDP-1 was built from DEC 5000-series discrete modules; the Am2900 family was
introduced in 1975, more than a decade later. This system answers the
owner-requested question "could the PDP-1 architecture be built from Am29xx
bit-slice parts, and would it then run its own software?" It makes no claim
of transistor-level, electrical or package-level fidelity to either machine.

## 2. Sourced machine profile

Selected profile: **PDP-1 as documented by the 1961 handbook and the
September 1961 instruction list, with the standard one-channel sequence
break system, standard paper-tape reader and punch, standard typewriter and
the Type 30 point-plot display.**

| Item | Selected value | Source |
| --- | --- | --- |
| Word length | 18 bits, one's complement, bit 0 (MSB) is sign | F-15B §II "Number System" |
| Memory | 4096 18-bit core words, 5 µs cycle | F-15B §II "Operating Speeds" |
| Opcode | bits 0–4, indirect bit 5, address 6–17 | F-15B §II "Instruction Format" |
| Instruction times | 5 µs augmented; 10 µs two-cycle memory reference; +5 µs per indirect step | F-15B §II "Operating Speeds" |
| Instruction set | 27 legal opcodes of Table "Instruction List" | F-16 (Sept 1961) |
| Arithmetic | one's complement with end-around carry; overflow flip-flop | F-15B "Add"/"Subtract" |
| Extended arithmetic | `mus` (multiply step), `dis` (divide step) | F-15B pp. 12 |
| Console | test word (18), sense switches (6), program flags (6), start/stop/continue, single step | F-15B §II "Manual Controls" |
| Sequence break | one channel; AC→M[0], PC→M[1], PC←2 | F-15B §III; SIMH `pdp1_cpu.c` sbs path |
| I/O devices | reader 01/02/030, typewriter 03/04, punch 05/06, display 07, status 033, ESM 055 / LSM 054 | F-16 "In-Out Transfer Group" |
| Display | Type 30 point plot: X from AC[17:8], Y from IO[17:8], intensity from IOT pulse bits | F-16 `dpy 730007`; SIMH `pdp1_dpy.c` |

Deliberately **not** in this profile: PDP-1D extensions (`lch`, `dch`,
`tad`, field relocation, ring/restrict mode), the 16-channel sequence-break
option, 64K extended memory, Type 550/555 multiply-divide hardware, the
Type 30 display-list processor revision, DECtape, line printer, card
equipment, and the clock option. Opcodes 00, 05, 06 and 17 are illegal in
this profile and halt the machine with an illegal-instruction indication.

### Primary references

- DEC, *F-15B PDP-1 Handbook* (1961), scans:
  <https://bitsavers.org/pdf/dec/pdp1/F15B_PDP1_Handbook_1961.pdf>.
- DEC, *F-16 PDP-1 Instruction List* (September 1961),
  <https://bitsavers.org/pdf/dec/pdp1/F-16_PDP-1_Instruction_List_196109.pdf>.
- DEC, *F-25 PDP-1 Input-Output Manual* (device codes and I/O timing),
  <https://bitsavers.org/pdf/dec/pdp1/F25_PDP1_IO.pdf>.
- SIMH PDP-1 simulator source (`PDP1/pdp1_cpu.c`, `pdp1_dpy.c`), pinned by
  commit in `spec/reference/simh_commit.txt`; used as the **independent
  external oracle** for instruction-level state and I/O encodings.
- Spacewar! 4.1 source and RIM image, `sw41f.mac` / `sw41f.rim`,
  <https://bitsavers.org/bits/DEC/pdp1/from_peter_samson/>, modified for the
  CHM restoration (header: "spacewar 4.1 mod for CHM, 2005-06-01 … 2005-11-28";
  original revision "spacewar 4.1 2/20/63 dfw ; pt1").
- Computer History Museum PDP-1 restoration exhibition,
  <https://www.computerhistory.org/pdp-1/introduction>: PDP-1 launch in 1959,
  DEC's first computer, about 50 built, Spacewar! created on it.

The first PDP-1 deliveries are usually dated December 1959; the CHM
exhibition states the 1959 launch but not a month, so this document does not
assert a month.

## 3. Physical implementation

### 3.1 Slice chain and the 18-bit architectural boundary

Five Am2901 slices provide a 20-bit ALU chain.

```
 slice 4        slice 3        slice 2        slice 1        slice 0
 [19:16]        [15:12]        [11:8]         [7:4]          [3:0]
  ^ RAM3 in                                                   RAM0 out
```

- Architectural word: bits **[17:0]**. Bits **[19:18]** are *guard bits*.
- Every write to an architectural register forces the guard bits to zero.
  The guard bits exist only so that a carry out of bit 17 is visible as
  bit 18 of the ALU result.
- `cn_i` of slice 0 is a glue-selected constant (0 or 1) or the
  *end-around-carry* input for two's-complement-corrected operations.

### 3.2 One's complement arithmetic

The PDP-1 adds with end-around carry (EAC): `A + B + carry_out(bit 17)`.
The slices expose only slice-group carries, not bit 17's carry. With both
operand guard bits zero, the 20-bit sum's bit 18 *is* the carry out of bit
17, so the microcode implements:

1. `F ← A + B` with `cn = 0`, guard bits zero.
2. If `F[18] = 1`, `F ← F + 1` in a fix-up micro-op that itself loops if a
   new carry appears (at most two iterations: only `0777777 + 1` re-carries).

Subtraction is `A + ~B` with the same rule, so that the EAC term is exact
for one's complement. The explicit deviation from a hypothetical 18-bit
EAC adder is: one extra micro-op per addition that carries, and a
documented fix-up loop. Microcode performs this in `ADD_EAC` / `SUB_EAC`
subroutines, and the datapath never relies on the slice's `cn4` output.

**Overflow** is computed in glue, from the A-operand (`Y[17]`), the
effective D-operand (`D[17] ^ d_inv`) and the result: `ov ← (Y17 ^ F17) &
(D17eff ^ Y17)` for arithmetic destinations. It is *not* taken from the
slice `OVR` pin, because that pin observes bit 19, which is always zero in
this boundary.

**Zero** for `sza` is the architectural register comparison
`AC[17:0] == 0`, registered whenever AC is written; the slice open-collector
`ZERO` pins are wired together as an independent ALU-level check and are
asserted equal to the same condition in formal properties.

### 3.3 Registers

| Register | Bits | Location | Notes |
| --- | --- | --- | --- |
| AC | 18 | slice RAM word 0 | architectural accumulator |
| IO | 18 | slice RAM word 1 | in-out register |
| TMP0, TMP1 | 18 | slice RAM words 2, 3 | microcode scratch |
| ZERO | 18 | slice RAM word 4 | constant, never written |
| PC | 12 | glue | incrementer, load |
| MA | 12 | glue | memory address |
| IR | 18 | glue | instruction register (fetched word) |
| MB | 18 | glue | memory buffer / operand |
| OV, PF1–6, HALT, SBS, IOS | 1/6 | glue | status flip-flops |
| TW | 18 | console input | test-word switches |
| SS | 6 | console input | sense switches |
| EXT_A, EXT_B | 1 | glue | shift edge capture |

### 3.4 Shift and rotate network

The Am2901 shift destinations are not used for the architectural shift,
because the 18-bit field is offset by two guard bits in one direction and by
none in the other; a 20-bit shift would misplace the fill bit by two
positions. The machine therefore uses an external 18-bit shift network, as
the original PDP-1 used discrete shift gates, while arithmetic still flows
through the slices:

- The A port presents the source register on `Y` with destination field
  code 2 ("F into B, Y ← A").
- Glue shifts `Y` one place left or right with a selected fill (zero, sign,
  or the captured edge bit) and drives it onto the slice D bus.
- The same microcycle writes `B ← F = D`, so one shift step is one
  microcycle for a single register.
- Combined AC/IO operations pipeline the two registers: the AC phase
  captures AC's shifted-out edge, the IO phase consumes it and captures
  IO's edge for the next iteration. Count `N = popcount(IR[8:0])` is
  computed in glue; a microcode loop with a 4-bit counter repeats `N`
  times. Invalid shift subcodes (0, 4, 8, 10, 14) halt as illegal.

### 3.5 Microsequencer and control store

- Microsequencer: the repository's verified `amd_am2910` (12-bit addresses,
  five-entry stack).
- Control store: 4096 × 88-bit words, generated from
  `src/microcode/pdp1_uc.uc` by `scripts/ucasm.py`; the generated
  `src/microcode/pdp1_uc.sv` is committed and the assembler is reproducible.
- Address map:

| Range | Use |
| --- | --- |
| `0x000–0x02F` | reset, fetch, indirect loop, PC/skip helpers |
| `0x030–0x0FF` | subroutines: EAC add/sub, memory read/write, shifts, I/O |
| `0x100–0x1FF` | 32 opcode slots, 8 microinstructions each (`0x100 + 8*op`) |
| `0x200–0x2FF` | I/O device handlers (dispatch through `IOTDISP`) |
| `0x300–0x3FF` | dispatch/condition tables and reserved |

- Dispatch: after fetch, a 32-entry dispatch ROM maps the 5-bit opcode to
  the slot base; the microcode executes Am2910 `JMAP` with that address on
  `D`. I/O devices are dispatched the same way from the 6-bit device field
  through a second ROM.
- Reset: `JZ` clears the stack and jumps to microaddress 0; the machine
  starts at `PC ← 0` (front-panel start uses the address switches instead).
- Wait states: memory and I/O handshakes are explicit. Each memory access
  is two microinstructions (address setup, then data use). `iot` with the
  wait bit set stalls the sequencer in a `WAIT_IO` microinstruction until
  the device asserts completion.
- Sequencing primitives used: `JMAP` (dispatch), `CJP` (conditional jump),
  `CJS`/`CRTN` (microcode subroutines), `LDCT`/`RFCT` (shift loops),
  `CONT`. `LOOP` is not used because its return address must already be on
  the stack; the shift loops decrement a glue counter with `RFCT`.

### 3.6 Timing model

Wall-clock microcycles are a reconstruction, not the original machine's
internal clocking. The panel and the trace expose **two** numbers:

- `microcycles`: microinstructions executed (implementation detail).
- `core_cycles` and `machine_us`: the documented visible timing:
  fetch = 1 core cycle; each memory access = 1; each indirect step = 1;
  augmented instructions = 1; 5 µs per core cycle.

This separates the visible memory/instruction timing from the internal
microcycle count, as the issue requires. No claim is made that the original
machine's internal state sequence is reproduced.

## 4. Instruction contract used by the microcode

Bit numbering in this table is the hardware's numeric one (`IR[11:0]` is
the address field, `IR[12]` the indirect bit, `IR[17:13]` the opcode).
DEC documentation numbers bit 0 as the most significant bit, so DEC bit
`i` is hardware bit `17 - i`.

| Opcode (octal) | Mnemonic | Action |
| --- | --- | --- |
| 01 | and | AC ← AC & M[Y] |
| 02 | ior | AC ← AC \| M[Y] |
| 03 | xor | AC ← AC ^ M[Y] |
| 04 | xct | execute M[Y] |
| 07 (I=0) | cal | M[0100] ← AC; AC ← PC; PC ← 0101 |
| 07 (I=1) | jda | M[Y] ← AC; AC ← PC; PC ← Y+1 |
| 10 | lac | AC ← M[Y] |
| 11 | lio | IO ← M[Y] |
| 12 | dac | M[Y] ← AC |
| 13 | dap | M[Y][11:0] ← AC[11:0] |
| 14 | dip | M[Y][17:12] ← AC[17:12] |
| 15 | dio | M[Y] ← IO |
| 16 | dzm | M[Y] ← 0 |
| 20 | add | AC ← AC + M[Y] (EAC) |
| 21 | sub | AC ← AC − M[Y] (EAC) |
| 22 | idx | AC ← M[Y] ← M[Y] + 1 |
| 23 | isp | AC ← M[Y] ← M[Y] + 1; skip if AC > 0 (AC[17]=0 and AC ≠ 0) |
| 24 | sad | skip if AC ≠ M[Y] |
| 25 | sas | skip if AC = M[Y] |
| 26 | mus | if IO[0]: AC ← AC + M[Y]; {AC,IO} ← {AC,IO} >> 1, AC[17] ← 0 |
| 27 | dis | {AC,IO} ← rotate left 1; IO[0] ← ~AC[17]; if IO[0]: AC ← AC − M[Y] else AC ← AC + M[Y] + 1 |
| 30 | jmp | PC ← Y |
| 31 | jsp | AC ← PC; PC ← Y |
| 32 | skp | skip group, address field selects conditions, IR[12] inverts |
| 33 | shift/rotate | subcode IR[12:9]; count = popcount(IR[8:0]) |
| 34 | law | AC ← IR[11:0] (IR[12]=0) or AC ← ~IR[11:0] (IR[12]=1) |
| 35 | iot | device = IR[5:0], pulse = IR[10:6], C = IR[11], W = IR[12] |
| 36 | opr | operate group, address field selects |

Skip-group bits (address field):

| Field bit | Condition |
| --- | --- |
| 0o0001–0o0007 | program flag 1–7 (7 = all) is zero |
| 0o0010–0o0070 | sense switch 1–6 (7 = all six) is zero |
| 0o0100 | AC = +0 |
| 0o0200 | AC ≥ 0 |
| 0o0400 | AC < 0 |
| 0o1000 | OV = 0, then clear OV |
| 0o2000 | IO ≥ 0 |

Operate-group bits: 0o0200 CLA, 0o0400 HLT, 0o1000 CMA, 0o2000 LAT,
0o4000 CLI, 0o0001–0o0007 CLF n (7 = all), 0o0011–0o0017 STF n
(7 = all). Combinations perform the union; HLT stops after the
microinstruction retires.

Shift subcodes (`IR[12:9]`): 1 RAL, 2 RIL, 3 RCL, 5 SAL, 6 SIL, 7 SCL,
9 RAR, 10 RIR, 11 RCR, 13 SAR, 14 SIR, 15 SCR.

## 5. I/O and peripherals

| Device (octal) | Function | Implementation |
| --- | --- | --- |
| 01, 02, 030 | paper-tape reader, alphanumeric/binary, reader buffer | host-loaded tape image, 18-bit RIM-decoded words, status flip-flop |
| 03 | typewriter output | character output queue to the panel |
| 04 | typewriter keyboard input | panel key queue, `tyi` returns the character |
| 05, 06 | paper-tape punch | punched output queue (binary/alphanumeric) |
| 07 | Type 30 display point plot | X = AC[17:8], Y = IO[17:8], intensity = pulse bits |
| 033 | check status | I/O status word incl. sequence-break bit |
| 054 / 055 | leave / enter sequence break mode | SBS enable flip-flop |
| 011 | control word (Spacewar!) | test word switches, per the CHM revision comment |

Sequence break: when enabled and a device raises a break request, the
machine finishes the current instruction and executes the documented
four-cycle sequence: `M[0] ← AC`, `M[1] ← PC`, `PC ← 2`. The device model
raises break requests on display frame completion and on typewriter input.
This is the one-channel system; the 16-channel option is out of profile.

Paper-tape format: the RIM loader format used by the DEC "read-in mode" is
decoded by the host loader (word count/checksum per block); the RTL sees
only 18-bit words and a "buffer ready" status, as the original reader did
after the read-in mode had been started.

## 6. Verification contract

1. **External oracle**: SIMH `pdp1` (pinned commit) runs the same memory
   image and emits per-instruction history (PC, IR, AC, IO, OV). The RTL
   testbench emits the same fields at instruction retirement. The comparison
   is exact and is run over directed instruction tests plus authentic
   programs; this is an independent implementation, not a transcription of
   this RTL.
2. **Directed arithmetic**: one's complement edges — positive zero,
   negative zero (`777777`), EAC chains (`777777 + 1`), overflow pairs,
   `sub` with borrow, `idx`/`isp` wrap at `777777`.
3. **Shift/rotate**: all 12 subcodes, counts 0–9, direction, arithmetic
   fill, combined AC/IO linkage; each expected value derived from the
   handbook rule and cross-checked against SIMH.
4. **Authentic software**: Spacewar! 4.1 (`sw41f.rim`) and at least one DEC
   diagnostic or historical program run on the RTL; exact PC/state checked
   for the first N instructions against SIMH, then the program's own
   behavior (display list, typewriter output) is checked.
5. **Formal**: glue properties for the EAC/overflow/zero contract, the
   shift network and the Am2910 wait-state stalling; cover properties for
   non-vacuity.
6. **Synthesis**: Yosys elaboration and cell count for the full machine,
   excluding the memory array, with latch-free check.
7. **Lint**: `verilator --lint-only -Wall` clean.

## 7. Assumption ledger

Every item below is behavior the primary documentation does not explicitly
settle; each has an `ASSUMPTION:` comment in the RTL where it is applied,
and is validated by the oracle comparison where observable.

| # | Assumption | Why it is needed | Validation |
| --- | --- | --- | --- |
| A1 | The 18-bit field occupies bits [17:0] of the 20-bit chain and guard bits are always written zero. | Five 4-bit slices give 20 bits; the PDP-1 has 18. | `pdp1_glue_props`: all register writes force guard = 0. |
| A2 | EAC is applied by a conditional `+1` micro-op, looping at most twice. | Slice carry pins do not expose bit 17's carry. | Directed vectors `777777+1`, `777777+777777`, `-0 + -0`; SIMH agreement. |
| A3 | Overflow is derived from operand/result signs, not the slice OVR pin. | OVR observes bit 19 (always zero). | Formal property vs. one's-complement add model; SIMH agreement on overflow cases. |
| A4 | Shift/rotate uses an external 18-bit network rather than the slice shift pins. | Two guard bits would displace the fill bit. | All 12 subcodes × counts 0–9 vs. handbook rule and SIMH. |
| A5 | `isp` skips when AC > 0 (sign clear and non-zero). | The handbook says "positive"; SIMH tests `AC >= 0` on a 18-bit value. | Directed `+0`, `+1`, `-0` cases; oracle diff. |
| A6 | `mus`/`dis` implement the 1961 multiply/divide *step* instructions, not the SIMH AC×M / AC÷M extension. | SIMH implements a later multiply/divide option for these opcodes. | Handbook text is the contract; the difference is recorded in the report and the oracle diff excludes post-`mus`/`dis` state. |
| A7 | Display `dpy` is the point-plot IOT of the 1961 list, with X/Y from the high 10 bits of AC/IO. | The display-list revision and the point-plot revision differ; the authentic Spacewar! CHM build is written for the point-plot interface. | Display word stream vs. the program's expectations; panel rendering. |
| A8 | Sequence break occurs between instructions only, and the machine completes the current instruction first. | Documentation describes the trap sequence, not exact arbitration. | Directed SBS test, `M[0]`/`M[1]`/`PC` check. |
| A9 | Illegal opcodes (00, 05, 06, 17) halt with an illegal-instruction indication. | The 1961 list marks them unused. | Directed test; no authentic program uses them. |
| A10 | Memory is modeled with one-microcycle read latency and unlimited endurance. | Core memory's destructive read and 5 µs cycle are not reproduced electrically. | Documented limit; visible timing is modeled in `core_cycles`. |
| A11 | The typewriter and reader are functional models with no mechanical timing. | The originals are electromechanical. | Documented limit; program-visible status bits only. |

## 8. Fidelity limits (stated, not implied)

- Not transistor-level: the Am2901/Am2910 models are the repository's
  digital contracts, not bipolar electrical models.
- Not cycle-exact against a real PDP-1: microcycles are a reconstruction;
  only the documented instruction times (5/10 µs + indirect) are modeled.
- No 64K memory, no PDP-1D modes, no 16-channel SBS, no DECtape, printer or
  clock, no display-list processor revision, no analog CRT persistence.
- The Am2901's internal RAM is 16 words; the architectural registers are
  mapped into four of them plus glue registers, which is a design choice,
  not a claim about how DEC or AMD would have wired such a machine.
- FPGA acceptance is a separate issue.

## 9. Acceptance mapping (issue #184)

| Issue requirement | This system |
| --- | --- |
| Pin original DEC references, machine/options profile, assumption ledger | §2, §7 |
| Review five-slice wiring, 18-bit masks, EAC, signed zeros, overflow, shift linkage | §3.1–3.4, §7 A1–A4, formal + directed tests |
| Am2910 control-store format, map, dispatch, reset, wait states, I/O sequencing | §3.5 |
| Sliced/sequencer RTL plus memory/peripheral adapters, not a behavioral CPU | §3, `src/` |
| Independent external oracle and authentic diagnostics; exact PC/state incl. ±0 | §6.1–6.3 |
| Authentic loader/diagnostic and Spacewar! on the RTL backend with provenance | §6.4, README |
| Web front panel: registers, tape load, console/typewriter, display, waveforms | README "Web interface and waveform" |
| Formal, simulation, synthesis and real-software evidence plus limits | `report/final_report.md` |
