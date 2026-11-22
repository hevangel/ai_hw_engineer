# IBM System/360 — M5: translate and EXECUTE

Date: 2026-11-20 (verification runs 2026-11-20 and 2026-11-21)
Scope: the shared S/360 engine, fifth increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), instruction-set
issue [#384](https://github.com/hevangel/ai_engineer/issues/384)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

| Operation | Opcode | Format | Behaviour |
|---|---|---|---|
| TR | 0xDC | SS | each byte of operand 1 indexes the 256-byte table at the operand-2 address and is replaced by the function byte |
| TRT | 0xDD | SS | as TR but the field is unchanged; a nonzero function byte stops the scan, puts the argument address in GR1 and the byte in the low byte of GR2 |
| EX | 0x44 | RX | executes the instruction at the operand address with `I1` ORed into its bits 8-15 |

The core now implements **54 operations**. This closes the instruction-stream
control group: the only remaining unimplemented instructions are the decimal
conversions/arithmetic and floating point.

## 2. Semantics taken from the manual

- **TR** (p. 57): the argument byte is added to the operand-2 address and the
  selected function byte replaces the argument. The list is not altered unless
  the fields overlap.
- **TRT** (p. 57): the same fetch; on a nonzero function byte the *argument
  address* goes to the low 24 bits of general register 1 (high 8 bits
  unchanged) and the function byte to the low 8 bits of general register 2
  (bits 0-23 unchanged). CC 0 = all function bytes zero, CC 1 = nonzero before
  the field ends, CC 2 = nonzero on the last byte.
- **TRT has no register fields.** The SS format carries only `L`, `B1/D1` and
  `B2/D2`, and the manual names "general register 1" and "general register 2"
  literally. The core therefore always uses GR1 and GR2; this is recorded as
  assumption A-7 because OCR damage to the format figure prevents a visual
  confirmation, and it is the first thing the oracle should check.
- **EX** (p. 67): the subject instruction is executed exactly as if it were in
  the normal stream, except that the PSW instruction address advances by
  EXECUTE's length (four) and the ILC recorded is 2. A successful branch of the
  subject still takes effect. An odd subject address is a specification
  exception, and a subject that is itself EXECUTE raises the execute exception
  (code 3). Exceptions inside the subject store an old PSW with EXECUTE's
  address-plus-four and ILC 2.

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M5 CORE TESTS PASSED (137 checks)`. The complete flow (`scripts/run_all.sh`: lint, simulation, structural synthesis and the four formal jobs) passes in 627 s of wall time on this machine.

| Test | Establishes |
|---|---|
| 16. TR | a 256-byte table `table[i] = i+1` turns `10 20 30 40` into `11 21 31 41` |
| 17. TRT | a match at the second byte gives GR1 = 0x201, GR2 = 0x0F and CC 1; an all-zero table leaves both registers untouched and gives CC 0 |
| 18. EX | `EX` with `I1 = 0x40` turns the subject `MVI 0(1),0x00` into `MVI 0(1),0x40`, stores 0x40, and resumes at EXECUTE+4 (the following instruction runs); a subject that is another EXECUTE raises code 3 with old PSW ILC 2 and IA 0x104 |

### 3.3 Formal

The core BMC keeps its M3/M4 shape (depth 12, `smtbmc yices`) and **passes** in
about 576 s on this machine. ALU, address and PSW jobs are unchanged and pass.

### 3.4 Defects found

1. **Two test programs branched into zeroed storage.** The TR/TRT loops named
   address 0x10C while the `BCR` sat at 0x10A, so the machine ran off into
   zeros and raised an operation exception. This was a test defect, and it was
   found because the test also asserts that *no* interruption occurred.
2. **A global literal edit broke a different test.** Fixing the loop address by
   replacing every `41F0010C` also changed the M2 `SSM` test, whose loop really
   is at 0x10C; the simulator caught it immediately as "SSM program is not in
   its self-loop". Restored that occurrence.

### 3.5 Synthesis

Structural synthesis (`synth -run begin:fine`, before ABC mapping): 583 generic
cells for the core including instances, 676 for the design hierarchy, no
latches, no structural problems. As in M3/M4 the flow stops before ABC.

## 4. Limits

- `ED`, `EDMK`, `PACK`, `UNPK`, `MVO`, `CVB`, `CVD` and decimal arithmetic, plus
  floating point, are still unimplemented and raise code 1.
- No protection, DAT or addressing exceptions; only program interruptions.
- `EXECUTE` is not interruptible by external events (none exist) and the
  subject's own timing is not modelled.
- Formal core BMC is bounded at 12 cycles; the cover task remains outside the
  default flow for solver-cost reasons.
- No independent oracle yet: `plans/oracle_plan.md` records the candidate and
  the integration steps.

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. Oracle driver against the 54 implemented operations (`plans/oracle_plan.md`).
2. Decimal conversions and arithmetic, then floating point.
3. External/I/O interruptions, protection and addressing exceptions (#385).
