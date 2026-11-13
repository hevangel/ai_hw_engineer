# Intel 8042 verification report — 2026-11-13

## Result

The UPI-42 core matches the reference model on every retired instruction in
all tests. That covers 13 directed programs, 32 random 2K programs of 20,000
retires each, and two runs of the IBM PC AT keyboard-controller firmware
(120,000 and 400,000 retires).

On the CRC-balanced test image the firmware answers the BIOS POST command
order exactly: AAh→55h, ABh→00h, C0h→FFh, 20h→5Dh, D0h→CFh, and FFh→FEh
with no keyboard attached. On the partial IBM image the self-test stops at
its ROM checksum, as the missing bytes require.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_lint.sh` | Clean, `verilator --lint-only -Wall` |
| Formal proof | `scripts/run_formal.sh` | abc pdr: PASS, unbounded, any program |
| Formal cover | `scripts/run_formal.sh` | 5 of 5 reached; the deepest needs 6 steps |
| Decoder vs independent disassembler | `scripts/run_sim.sh` | 781 instructions, 0 differences (one data byte, 7FFh, listed as an explained exception) |
| Directed tests, model vs manual | `scripts/run_sim.sh` | 14 of 14 pass |
| Directed tests, RTL vs model | `scripts/run_sim.sh` | 14 of 14 identical |
| Random programs | `scripts/run_sim.sh` | 32 seeds x 20,000 retires identical; all 256 opcodes, both interrupt vectors |
| IBM 1503033 partial rebuild, AAh | `scripts/run_sim.sh` | 120,000 retires identical; stops at status 48h (ROM checksum), no reply |
| IBM 1503033 CRC test image, BIOS command order | `scripts/run_sim.sh` | 400,000 retires and 8 host reads identical; replies `55 00 FF 5D CF CF FE 55` |
| Synthesis | `scripts/run_synth.sh` | Yosys `synth` + `check -assert`: 5,689 generic cells (1,172 flip-flops, of which 1,024 are the RAM), no latches |

The whole flow (`scripts/run_all.sh`) takes about 46 seconds in the
`ai-hw-engineer` image (Verilator 5.052, Yosys/SBY with yices, Python 3.14).

## Independence of the reference model

`scripts/upi42_iss.py` was written from the Intel UPI-41A User's Manual and
8742 data sheet before the RTL. Its opcode table was then checked against a
second, unrelated source: A. Tarpai's own disassembler output for the IBM
firmware. That check covers every one of the 781 instructions it lists. The
directed tests check the model against the manual's worked examples and
stated corner cases with exact program-counter values. Rules the documents
leave open are listed as U1–U14 in the [specification](../spec/spec.md).

The test bench was itself checked by planting three faults in a copy of the
RTL. Each was caught by the random seeds:
- DA without its carry input: seed 3, PSW;
- JMPP using a wrong page: seed 1, next PC;
- prescaler of 31 instead of 32: seed 1, timer.

## Findings

- **The IBM firmware cannot be fully rebuilt from public sources.** The
  PCjs-archived listing gives 1,388 of 2,048 bytes. The AAh self-test
  computes a CRC over the whole ROM (listing 0754h–07A8h). It must be
  0000h, and the last two bytes, 7FEh–7FFh (`A0 38`), exist to balance it.
  Filling the gaps with 00h or FFh does not reproduce MAME's hash. With the
  real gap bytes unknown, the BIOS's first 8042 command cannot succeed on
  the rebuilt image.
- **Two manual errata.**
  - The DA example on p.3-10 adds 9AH + 06H as A1H.
  - The CALL diagram on p.3-8 shows the 1K encoding.
- **MOVP3 reads absolute page 3 from the upper 1K.** The firmware's
  checksum relies on this (ASSUMPTION U10).

## Limits

- The test image is not IBM's firmware. Its 660 gap bytes are 00h except
  the two solved CRC bytes.
- Keyboard protocol beyond "no keyboard attached" is not exercised yet; that
  needs a keyboard model at system level.
- Not modeled: DMA pins, the 8243 expander, single-step, EA and the status
  read lock-out. Port changes take effect at instruction end.
- Machine cycles are abstract (`ce_i`). The ratio to the crystal clock is
  the system's responsibility.

## Reproduce

```sh
sh design/intel_mcs48/intel_8042/scripts/run_all.sh
```

The first run downloads the pinned listing from GitHub into the ignored
`work/` folder and checks its SHA-256.
