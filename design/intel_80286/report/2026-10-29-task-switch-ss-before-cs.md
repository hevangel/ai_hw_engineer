# Incoming task SS-before-CS validation order

**Audit started:** 2026-10-29 03:40 UTC  
**Primary source:** Intel 80286 Programmer's Reference Manual, order
210498-005, section 8.3 step 7, printed page 8-5 (PDF page 155). The page was
reviewed in Chrome with Playwright CLI; the capture is
`design/intel_80286/work/historical_software_current_20261029_23/manual-page155-scrolled.png`.

## Audit finding

Section 8.3 step 7 validates the incoming task's SS, CS, DS and ES in that
order. The RTL instead entered `TASK_CODE_START` immediately after validating
the incoming LDT, so it checked CS before SS. The existing combined-fault row
in the 52-case incoming-segment matrix was named “CS fault precedes SS” and
expected that same behavior.

I changed the row to make the architectural ordering observable: incoming
SS=`0188` exceeds the GDT limit and must raise `#SS(0188)` before incoming
CS=`0010` can raise `#TS(0010)`. The old RTL reproduced the failure in both
READY modes: vector 10/error `0010` was delivered instead of vector 12/error
`0188`. Baseline log SHA-256:
`9a33e0ea599450b2ab304818ae6e8bb2d945135dadd772bed2d9a773d47fa56d`.

## RTL and regression changes

Task entry now proceeds in this order:

1. Validate the incoming LDT.
2. Validate and cache incoming SS.
3. Validate and cache incoming CS at offset zero, without checking incoming IP
   yet.
4. Validate incoming DS and ES.
5. Check incoming IP against the cached CS limit, then push any task-gate error
   code or commit the task state.

`src/intel_80286.sv` now starts the segment sequence with SS. After SS succeeds,
it enters the CS code-load check; after CS succeeds, it resumes the segment
sequence at DS. The existing deferred IP check remains after ES. This makes the
shared task-gate, direct-TSS and task-return path follow section 8.3 steps 6–8.

`tb/bootstrap.cpp` now verifies the combined SS/CS first-fault priority in both
READY modes. The 460-case valid non-null-LDT matrix checks descriptor reads and
accessed-bit writes in SS/CS/DS/ES order. The incoming-LDT-limit cases also
check partial effects: valid SS is read and marked accessed before a later
out-of-limit CS fault, while invalid SS is rejected before any CS read.

The regression also verifies that incoming IP is checked after all four
selectors and that an invalid LDT wins over a null SS. These cases check the
fault packet at its valid pulse, descriptor-read order, accessed-bit writes,
and the absence of later descriptor accesses in both READY modes.

## Verification evidence

- Exact-source `scripts/run_sim.sh` exited 0 with 197 `PASS:` lines and no
  `FAIL:` or `ERROR:` markers. This includes the 52-case invalid incoming
  segment matrix, 460 valid LDT combinations, eight LDT-limit cases, the new
  incoming-IP and invalid-LDT priority cases, all component suites, native CPU
  integration, and the protected replay. The 79-case protected replay passed
  in both READY policies.
- Verilator 5.052, `-Wall`; compiler g++ 15.2.0.
- RTL SHA-256:
  `b487b109f9ad70838f360c6c15d5330c29b0cc8e787d53066712db8d9b79f0e5`.
- Bootstrap test SHA-256:
  `63641af8b3532d4fe032f296a60bf992f7efea2667f9d450c99b76aa8e12fd91`.
- Full simulation log SHA-256:
  `d10cf39693bd94902bfe55f5272eef24cc3af5f16656776e4f2ee227d9705548`.
- Build manifest fingerprint:
  `44f0f454e44546bb39abb6f34830338ba34c43444908a14c4c17f9f3be79639d`;
  simulation binary SHA-256:
  `b5c448a04988c6c37d2bc32887449ab23e97ce73b4a8794034de8a2c23001cd4`.
- Evidence directory:
  `design/intel_80286/work/task_switch_ss_cs_priority_20261029_36/`.

Exact-source `scripts/run_synth.sh` exited 0 under Yosys 0.69 (git
`9f75ca1f9`). All 13 targets produced JSON netlists, each target passed three
zero-problem structural checks, and there were no errors. Synthesis evidence
is in `design/intel_80286/work/task_switch_ss_cs_priority_20261029_30/`; the
run log SHA-256 is
`4c589f259e1325633250035895ac8d5889d29bc6c42433bc2029e027bc0e1f17`.

The separate current-source code-load component proof passes BMC at depth 24,
k-induction and cover (eight witnesses), with preflight passing. Its BMC,
prove and cover records are under
`design/intel_80286/work/task_switch_ss_cs_priority_20261029_38/formal_runs/code_load/`;
the proof input RTL and property hashes match current source. This does not
constitute connected-core proof.

The current-source historical software rerun passes the original IBM AT BIOS
through its ROM-checksum success checkpoint after 196,846 exact instruction
states, plus the BIOS hex helper, IRQ8 timer and system-register tests. See
the [software report](2026-10-29-historical-software-current-source.md) and
the `_37` evidence directory.

The preserved whole-core PDR remains active on a stale source snapshot, so no
competing connected-core run was started. Its result cannot establish
current-source proof. Remaining release gaps include current-source
connected-core proof, full POST/boot, OS/2 CPGREP execution on RTL, and
whole-CPU acceptance.
