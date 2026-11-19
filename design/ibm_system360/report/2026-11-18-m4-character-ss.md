# IBM System/360 — M4: character and SS-format group

Date: 2026-11-18
Scope: the shared S/360 engine, fourth increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), instruction-set
issue [#384](https://github.com/hevangel/ai_engineer/issues/384)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

| Group | Instructions | Source |
|---|---|---|
| Storage-to-storage move | `MVC` (0xD2), `MVN` (0xD1), `MVZ` (0xD3) | pp. 53-54 |
| Storage-to-storage logical | `NC` (0xD4), `OC` (0xD6), `XC` (0xD7) | pp. 55-56 |
| Storage-to-storage compare | `CLC` (0xD5) | p. 54 |
| Character | `TM` (0x91), `IC` (0x43), `STC` (0x42) | p. 56 |

The core now implements **51 operations**, and the SS format is supported for
the first time: length field `L+1` (1 to 256 bytes), two independent base/
displacement addresses, and a byte loop that reads operand 1, reads operand 2,
then merges and stores.

## 2. Semantics taken from the manual

- `MVC`/`MVN`/`MVZ`/`NC`/`OC`/`XC` move or combine left to right, one byte at a
  time, and the fields may overlap in any way (p. 53). Overlap therefore
  propagates exactly as the byte loop dictates, which is what the manual
  describes rather than a memmove-style semantic.
- `MVN` takes the low four bits of each source byte into the low four bits of
  the destination byte; `MVZ` takes the high four bits into the high four bits
  (p. 54). The other half of the destination byte is preserved.
- `CLC` compares left to right and ends at the first inequality or the end of
  the fields (p. 54).
- `TM` tests the storage byte against the immediate mask: all selected bits
  zero (or an all-zero mask) → CC 0, all selected bits one → CC 3, otherwise
  CC 1 (p. 56).
- `IC` inserts into bits 24-31 of `R1` and leaves the other bits unchanged;
  `STC` stores bits 24-31 of `R1` (p. 56).

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M4 CORE TESTS PASSED (117 checks)`. The complete flow (`scripts/run_all.sh`: lint, simulation, structural synthesis and the four formal jobs) passes in 453 s of wall time on this machine.

Test 15 drives a four-byte field through the whole group:

| Step | Result at `0x208` |
|---|---|
| `MVC 0x208(4),0x200` | `C1 C2 C3 C4` |
| `XC 0x208(4),0x204` | `8A 8E 8E 8A` |
| `NC 0x208(4),0x200` | `80 82 82 80` |
| `OC 0x208(1),0x200` | `C1 82 82 80` |
| `MVN 0x208(1),0x204` | `CB 82 82 80` |
| `MVZ 0x208(1),0x205` | `4B 82 82 80` |

Then `CLI`-style checks: `CLC` against a higher byte sets CC 1, `IC 1,0x208`
loads `0x4B` into `R1` (low byte), `STC 1,0x20C` stores it, and three `TM`
cases produce CC 0, CC 1 and CC 3 respectively.

### 3.3 Formal

The core BMC keeps its M3 shape (depth 12, `smtbmc yices`) with the state
register widened to five bits for the three new SS states. It **passes** in
about 383 s on this machine. Its structural assertion for storage writes had to
learn about the new `S_SS_C` state — see §3.4.

The ALU, address and PSW jobs are unchanged from M3 and pass: two exhaustive
combinational proofs, the PSW field-isolation induction proof and their covers.

### 3.4 Defects found

1. **The structural write assertion did not allow the SS write state.** The
   inline formal assertion said storage may only be written in `S_WRITE` or the
   two old-PSW states; the SS loop writes in `S_SS_C`, so the BMC failed in the
   first second at step 0. The assertion and its copy in the properties module
   now include `S_SS_C`. This is the assertion doing its job: it caught a new
   write path that had not been declared.
2. **Adjacent string literals in the testbench program.** The new test was
   written as several adjacent literals (`"D203…" "D703…"`), which
   SystemVerilog does not concatenate; the program bytes were silently wrong.
   Rebuilt as one literal, and the testbench now has a check that no adjacent
   literals remain.

### 3.5 Synthesis

Structural synthesis (`synth -run begin:fine`, before ABC mapping): **530**
generic cells for the core including instances, 57 for the arithmetic unit, 5
for the address adder and 21 for the PSW register; 623 for the design
hierarchy. Yosys reported no problems and inferred no latches. The divider from
M3 still dominates mapped area, so the flow continues to stop before ABC and no
area or timing figure is claimed.

## 4. Limits

- `TR`, `TRT`, `ED`, `EDMK`, `PACK`, `UNPK`, `MVO`, `CVB`, `CVD` and `EXECUTE`
  are still unimplemented and raise code 1.
- No protection, DAT or addressing exceptions; only program interruptions.
- The SS loop takes three cycles per byte (about 770 cycles for a 256-byte
  field). This is a functional model; no timing claim is made.
- Core formal BMC is bounded at 12 cycles; the cover task remains out of the
  default flow for solver-cost reasons.
- No independent oracle yet (#383).

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. `TR`/`TRT` (table walk with the translate-table address and the `R1`/`R2`
   results of `TRT`).
2. `EXECUTE` (nested instruction execution with the `I2` byte ORed in).
3. Decimal conversions and arithmetic (`PACK`, `UNPK`, `CVB`, `CVD`, `AP`…),
   then floating point.
4. External/I/O interruptions, protection and addressing exceptions (#385).
