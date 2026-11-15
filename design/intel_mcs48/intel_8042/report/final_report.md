# Intel 8042 verification report — 2026-11-13

## Result

The UPI-42 core matches the reference model on every retired instruction in
all tests. That covers 14 directed programs, 32 random 2K programs of 20,000
retires each, and two runs of the IBM PC AT keyboard-controller firmware
(120,000 and 400,000 retires).

The firmware is IBM's real 1503033 ROM, rebuilt and verified against
MAME's SHA-1. On it the controller passes its own self-test and answers
the BIOS POST command order exactly: AAh→55h, ABh→00h, C0h→FFh, 20h→5Dh,
D0h→CFh, and FFh→FEh with no keyboard attached.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_lint.sh` | Clean, `verilator --lint-only -Wall` |
| Formal proof | `scripts/run_formal.sh` | abc pdr: PASS, unbounded, any program |
| Formal cover | `scripts/run_formal.sh` | 5 of 5 reached; the deepest needs 6 steps |
| Decoder vs independent disassembler | `scripts/run_sim.sh` | 781 instructions, 0 differences (one data byte, 7FFh, listed as an explained exception) |
| Directed tests, model vs manual | `scripts/run_sim.sh` | 14 of 14 pass |
| Directed tests, RTL vs model | `scripts/run_sim.sh` | 14 of 14 identical |
| Random programs | `scripts/run_sim.sh` | 32 seeds x 20,000 retires identical; all 256 opcodes, both interrupt vectors |
| IBM 1503033 image rebuild | `scripts/run_sim.sh` | 2,048 bytes; SHA-1 `0100f8789fb4de74706ae7f9473a12ec2b9bd729` and CRC32 `5a81c0d2` match MAME |
| IBM 1503033, AAh self-test | `scripts/run_sim.sh` | 120,000 retires and 1 host read identical; RAM test, ROM checksum and timer-interrupt test pass; reply `55` |
| IBM 1503033, BIOS command order | `scripts/run_sim.sh` | 400,000 retires and 8 host reads identical; replies `55 00 FF 5D CF CF FE 55` |
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

- **The IBM firmware is fully rebuilt and hash-verified.** The Tarpai
  listing (`external/halicery/8042`) gives 1,388 of 2,048 bytes. The dump
  published by minuszerodegrees.net, whose SHA-1 equals MAME's, showed the
  other 660: a 24-character identification string at 009h–020h and 00h
  everywhere else. The rebuild script uses the listing, that string and
  00h fill, and requires MAME's SHA-1 and CRC32, so it needs no binary
  download. The AAh self-test computes a CRC over the whole ROM (listing
  0754h–07A8h) that must be 0000h; it passes.
- **Two manual errata.**
  - The DA example on p.3-10 adds 9AH + 06H as A1H.
  - The CALL diagram on p.3-8 shows the 1K encoding.
- **MOVP3 reads absolute page 3 from the upper 1K.** The firmware's
  checksum relies on this (ASSUMPTION U10).

## Limits

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

The listing is read from the `external/halicery/8042` submodule; fetch it
with `git submodule update --init --checkout --depth 1 external/halicery/8042`.
If it is not checked out, the first run downloads the same file at the
pinned commit into the ignored `work/` folder. Either way its SHA-256 is
checked.
