# 80286 protected-mode interrupts during WAIT

Date: 2026-10-28 15:54 UTC  
Status: directed functional coverage now confirms asynchronous interrupt delivery
from a BUSY-stalled WAIT at CPL1 and CPL2. No RTL changed. ASSUMPTION A25,
which selects the already-advanced successor IP for the saved return frame,
remains open for independent 286 validation.

## Source basis

Intel's 1983 *Microprocessor and Peripheral Handbook*, iAPX 286/10 Chapter 4,
Table 1 (printed page 4-3), says the processor may be interrupted while WAIT
is suspended waiting for BUSY to become inactive. The source and its BUSY
polarity conflict are recorded in the [WAIT interruptibility
report](2026-10-28-wait-interruptibility.md); later Intel hardware-manual and
data-sheet evidence establishes the active-high BUSY polarity used here.

Protected gate delivery, privilege checks and TSS stack switching follow the
Intel 210498-005 protected-event contract reviewed in the
[CPL1/CPL2 event report](2026-10-28-protected-event-ring12.md). The cited WAIT
passage does not specify the saved IP when WAIT is interrupted. A25 therefore
remains an assumption rather than an independently sourced return-address
rule.

## Regression scope

`tb/bootstrap.cpp` now includes a 16-execution protected WAIT matrix:

- CPL1 and CPL2, each entered through a real outer IRET
- NMI and IF-enabled external INTR; INTR completes the acknowledge transaction
- Interrupt and trap gates
- Both READY wait modes

Each case asserts active-high BUSY, executes WAIT, and confirms the CPU remains
stalled without retiring it. Event delivery must read the TSS stack pair and
validate SS0 before writing the new stack. The test checks the protected event
packet, exact five-word outer frame, interrupt-stack isolation, gate IF/TF
behavior and NMI/INTR acknowledge semantics. It also confirms there is no
instruction fetch beyond WAIT while BUSY remains high. BUSY stays asserted
through the handler and outer IRET; the instruction after WAIT must then
execute at the exact successor. This intentionally makes the A25 return-IP
choice observable.

## Verification

Built from the task worktree with Verilator 5.052 and `-Wall` using the
repository runner. The build fingerprint is
`0115cb1f51dae031fa91fe2331bcf0340418c9ff309b23c8ab1c892d166a1850`;
the manifest SHA-256 is
`036dc1dedd2d3a5febf113ec87cd631583e89afff84b3b4ba6c2ef3c99926e78`.
The manifest pins `src/intel_80286.sv` at
`251de2323706b0372c112c8ba26f8d4de4eb41a0d0bc493ad7a8a7867d1f2189` and
`tb/bootstrap.cpp` at
`204a8f366fb37b78f84ccb9f893bbc5708a1bd66852911024284d3df67311c28`.
The runner binary SHA-256 is
`6305e67be25248e30eb02f6003bbf516e7b1537176b71a63a8f0b9e716f4b764`.

Commands run inside the mounted project container:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/protected_wait_20261028_01 \
  sh scripts/build_runner.sh
/work/design/intel_80286/work/protected_wait_20261028_01/sim/Vintel_80286 --protected-wait
/work/design/intel_80286/work/protected_wait_20261028_01/sim/Vintel_80286
```

- Strict runner build: PASS.
- `--protected-wait`: PASS, all 16 protected CPL1/CPL2 NMI/INTR cases.
- Full default bootstrap: PASS, 59 output lines.

Evidence is under the ignored
`work/protected_wait_20261028_01/` directory:

| Artifact | SHA-256 |
|---|---|
| Focused protected WAIT log | `67a523dc5b92b21468db890462220487bca53b3031db240f0edd36fac1da9c3e` |
| Full default bootstrap log | `af79250355dcec26f4c5fe745e22da4699997b5ade09aeadf1c443e30638a150` |
| Build manifest | `036dc1dedd2d3a5febf113ec87cd631583e89afff84b3b4ba6c2ef3c99926e78` |

## Limits

The test demonstrates functional protected-mode delivery through the
connected core. It does not establish native bus-pin timing or independent
hardware confirmation of A25. Simultaneous BUSY deassertion and interrupt
selection, TF behavior while WAIT is stalled, ESC interruption and successful
80287 ESC transfers remain open. The active whole-core PDR process uses an
older 21-file snapshot and is not evidence for this source. Whole-core formal
closure and the full CPU release gate remain open.

Issue checkpoint: [comment 6473853937](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473853937).
