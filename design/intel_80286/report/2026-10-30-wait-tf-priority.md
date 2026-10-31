# WAIT completion and single-step priority — 2026-10-30

## Counterexample and fix

The connected-core BMC `codex-286-wait-mf-nmi-bmc-20261029-01` ended FAIL
at step 20, property `intel_80286_props.sv:536`. The retained witness is
`work/wait_mf_nmi_formal_20261029_01/bmc/engine_0/trace.vcd`. It loads TF and
IF, fetches WAIT, and presents INTR as BUSY goes inactive and ERROR# is
inactive. The old core retires WAIT while the event controller already
starts INTA; on the following retirement boundary, the sampled TF request
cannot select vector 1 because the controller is occupied. Intel's
[80286 Programmer's Reference Manual](https://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
tables 5-1 and 9-4, places the single-step exception ahead of NMI and INTR.

The directed CPU test reproduces the defect on the old core in
`codex-286-wait-tf-race-before-20261030-01`, failing with `WAIT completion
claimed an interrupt before the sampled TF trap`. The fix admits a new
asynchronous event while WAIT is actually held by BUSY; when BUSY falls,
WAIT first reports a pending processor-extension exception or retires to its
ordinary boundary, where sampled TF has priority. An INTR already selected
while BUSY was high remains held until its acknowledgement completes.

The old directed WAIT race test assumed acknowledgement started on the exact
BUSY-release edge. The first corrected-core run exposed that timing-specific
assumption; the test now checks retirement on that edge, acknowledgement at
the following boundary, and no intervening fetch, while retaining the exact
saved PC, frame, return and successor checks. The new race tests cover both
NMI and INTR in both READY modes and check the vector-1 frame and lower-priority
event retention. The corrected-core bootstrap regression exited 0 with 110
PASS lines in `codex-286-wait-tf-race-after-20261030-03`, including both
new NMI/INTR race modes, nested NMI's exact frame and both READY policies.
Verilator `--lint-only -Wall` passed in `codex-286-wait-tf-lint-20261030-01`.
The validated CPU source SHA-256 is
`bed591ae2b99f1189947da66c17e054f6cfdcec9ca63ff998eabc3b56c4e65c8`.
A historical-software regression exited 0 in
`codex-286-wait-tf-software-20261030-01`: both functional-bus BIOS runs
reached `F000:038A`, and both native-bus runs reached `F000:03A2` with
instruction-state and data-transaction Unicorn comparisons using captured I/O.
The native runner verified its recorded inputs, and all 18 CPU RTL hashes
matched the dispatch snapshot. The full simulation suite exited 0 with 210
PASS lines in `codex-286-wait-tf-fullsim-20261030-01`. Its script preceded
the later RAS additions, which passed separately. Synthesis and the new
source-snapshot BMC are running; the prior PDR job is still
running on the old source and is not evidence for this change. The A10 TF behavior remains subject to the existing
native-286 validation gate in the interrupt specification.

The failure and investigation are recorded in [issue comment 6516441683](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516441683).
The directed-test and lint results are recorded in [issue comment 6516498840](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516498840).
The software verification is recorded in [issue comment 6516587893](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6516587893).
