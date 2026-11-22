# Independent oracle: first differential suite

Date: 2026-11-22
Scope: verification evidence for issue
[#383](https://github.com/hevangel/ai_engineer/issues/383), part of the S/360
program ([#379](https://github.com/hevangel/ai_engineer/issues/379)).
Author: coding agent working under `AGENTS.md`.

## 1. Result

Thirteen directed programs now run on **both** the RTL and an independent
System/360 emulator, and their architectural state is compared field by field.
**13/13 cases agree** after the fixes described in §3.

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

### 3.3 A harness difference, not a defect

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

`LA`/`LR`, `AR` (CC 2), `SR` (CC 1), `LTR` (CC 0), `A` overflow (CC 3), `CR`
across the 32-bit boundary, `MVI`+`TM`, `TR` through a table, `MVN`, `MR`
across a pair, `DR` quotient/remainder, `EX` with the R1 mask, `SLA`.

They cover the arithmetic, compare, logical, storage-to-storage, translate,
multiply/divide and execute paths that M1-M5 implement; they are all directed,
so they do not yet explore arbitrary operand combinations.

## 6. Limits

- Thirteen directed cases, not a corpus: a shared misreading that none of them
  exercises would still pass.
- Interruption entry not yet compared (harness alignment, §3.3).
- The emulator itself is unverified software with no stated licence; it is
  treated as one witness, not as ground truth. Disagreements are resolved
  against the manual, and the manual wins.
- Timing is not compared.

## 7. Next

1. Extend the case set to every implemented operation and add pseudo-random
   operand/state generation.
2. Event-aligned interruption comparison.
3. Reuse the emulator's DOS/360 images for the real-software regression (#429)
   once IPL and channels exist.
