# Independent oracle: first differential suite

Date: 2026-11-22
Scope: verification evidence for issue
[#383](https://github.com/hevangel/ai_engineer/issues/383), part of the S/360
program ([#379](https://github.com/hevangel/ai_engineer/issues/379)).
Author: coding agent working under `AGENTS.md`.

## 1. Result

**37 programs** now run on **both** the RTL and an independent System/360
emulator, and their architectural state is compared field by field: 13 directed
cases plus 24 deterministic randomised ones (a preamble that loads registers
0-7 from random data, then exactly one random instruction, so a divergence names
the instruction that caused it). **37/37 agree** after the fixes in §3.

This is the first evidence in the project that the RTL matches something other
than its author's reading of the manual. It immediately paid for itself: the
suite found two real architectural defects in the M5 code.

## 2. The oracle

| Field | Value |
|---|---|
| Artifact | `luiscunhacsc/s360-model30-v01`, IBM System/360 Model 30 instruction-level emulator (JavaScript, headless Node mode) |
| URL | https://github.com/luiscunhacsc/s360-model30-v01 |
| Commit | `4c379fceda39250fad7385eac15630d99281debf` |
| `src/core.js` | 42,903 bytes, SHA-256 `5034225E…C903BDB` |
| Licence | none stated in the repository; treated as all rights reserved, used locally for verification, never redistributed or committed |

It is kept in the ignored `work/` tree and located through `ORACLE_ROOT`; see
[../plans/oracle_plan.md](../plans/oracle_plan.md) for the candidate survey.

## 3. Defects the oracle found

### 3.1 `DR`/`D` register placement

The RTL placed the quotient in the even register and the remainder in the odd
one. A22-6821-7 p. 31: *"A 32-bit signed remainder and a 32-bit signed quotient
replace the dividend in the even-numbered and odd-numbered registers,
respectively"* — remainder in the even (R1), quotient in the odd (R1+1). The
emulator agreed with the manual and the RTL did not.

Fixed in the M5 branch; the testbench expectations now check remainder in the
even register and quotient in the odd one.

### 3.2 `EX` mask source

The RTL OR'ed the EX instruction's own second byte into the subject. p. 67:
*"Bits 8-15 of the instruction designated by the branch address are OR'ed with
bits 24-31 of the register specified by R1, except when register 0 is
specified, which indicates that no modification takes place."* The mask is a
**register** value, and R1 = 0 means no modification at all.

Fixed in the M5 branch: the mask is `gpr[R1][7:0]`, forced to zero when R1 = 0,
and the test program loads the mask register first.

### 3.3 `CLI` operand order

The randomised cases showed CC 1/2 flips on `CLI`. The RTL compared the
immediate byte as the *first* operand, so "first operand low" was reported
against the wrong side. The storage byte is the first operand and the immediate
the second (p. 54). Fixed; the randomised `CLI` cases now agree.

### 3.4 A reference-implementation bug

The emulator sets the condition code for `NC`, `OC` and `XC`
(`P.cc = nz ? 1 : 0`), while A22-6821-7 pp. 55-56 says the code is **unchanged**
for those three. The RTL follows the manual. The comparison therefore ignores
CC for those cases and each such case is labelled in the run output; the
disagreement is recorded here rather than hidden by dropping the cases.

### 3.5 A harness difference, not a defect

The interruption case (`0x00` opcode, handler at 0x300) agreed on the old PSW
(code 1, ILC 1, IA 0x102) and on the handler's effect, but disagreed on the
final ILC because the emulator performs the interruption inside `step()` while
the RTL retires only real instructions — so "N retired instructions" is a
different stopping point. Interruption cases are excluded from the suite until
an event-aligned driver exists.

## 4. How the comparison works

```
python design/ibm_system360/tools/oracle/run_diff.py
```

| Piece | Role |
|---|---|
| `tools/oracle/cases.py` | the program images, data words and retire counts |
| `tools/oracle/rtl_dump.py` | runs inside the project image: builds `tb/tb_oracle.sv` once and dumps state for every case |
| `tools/oracle/js_run.js` | runs the emulator on the host with Node, stepping to a fixed retired-instruction count |
| `tools/oracle/run_diff.py` | host orchestrator: writes images, calls docker for the RTL side, calls node for the emulator, compares |

Compared: PSW IA, CC, ILC, program mask, system mask, P and W; all 16 general
registers; the program old PSW at `0x28`/`0x2C`; storage words `0x200`-`0x23F`.

## 5. Cases

Directed: `LA`/`LR`, `AR` (CC 2), `SR` (CC 1), `LTR` (CC 0), `A` overflow
(CC 3), `CR` across the 32-bit boundary, `MVI`+`TM`, `TR` through a table,
`MN`, `MR` across a pair, `DR` quotient/remainder, `EX` with the R1 mask, `SLA`.

Randomised (24, fixed seed 36054): a preamble of eight `L` loads, then one
instruction drawn from the RR, RX, SI, SS, shift and `MR` groups with random
register fields, displacements inside the data area and random lengths. Branches,
`DR`/`D`, the status-switching instructions and `EXECUTE` are excluded, each for
a stated reason in `tools/oracle/random_cases.py`.

They cover the arithmetic, compare, logical, storage-to-storage, translate,
multiply/divide and execute paths that M1-M5 implement; they are all directed,
so they do not yet explore arbitrary operand combinations.

## 6. Limits

- 37 cases, not a corpus: a shared misreading that none of them exercises would
  still pass. The randomised set is one instruction deep after a fixed preamble.
- Interruption entry not yet compared (harness alignment, §3.3).
- The emulator itself is unverified software with no stated licence; it is
  treated as one witness, not as ground truth. Disagreements are resolved
  against the manual, and the manual wins.
- Timing is not compared.

## 7. Next

1. Deepen the random set: instruction sequences, random initial PSW fields and
   branch targets restricted to a controlled region.
2. Event-aligned interruption comparison.
3. Reuse the emulator's DOS/360 images for the real-software regression (#429)
   once IPL and channels exist.
