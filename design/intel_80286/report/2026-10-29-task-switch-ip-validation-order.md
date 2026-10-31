# Incoming task IP validation order

**Audit started:** 2026-10-29 03:09 UTC  
**Verification completed:** 2026-10-29 03:30 UTC  
**Primary source:** Intel 80286 Programmer's Reference Manual, order
210498-005, section 8.3, step 8, printed page 8-5 (PDF page 155). Table 8-1
is on printed page 8-6 (PDF page 156). Both pages were reviewed in Chrome with
Playwright CLI. Captures are in
`design/intel_80286/work/historical_software_current_20261029_23/`.

## Audit finding

Intel's task-switch procedure validates the incoming TSS, switches task state,
checks the incoming LDT and SS/CS/DS/ES selectors, then checks the incoming IP
against the CS limit before beginning execution. The existing RTL passed the
incoming IP to `intel_80286_code_load` at `TASK_CODE_START`, so its IP-limit
check happened before the later SS/CS/DS/ES selector checks. A directed case with
both a null incoming SS and an out-of-limit IP reproduced the mismatch: the RTL
reported `#GP(0)` before the architecturally earlier `#SS(0)`.

## RTL and test change

`src/intel_80286.sv` now gives the incoming code-load checker offset zero while
it validates the code descriptor and caches its limit. After incoming ES has
also validated, the task-entry path compares the saved incoming IP with the
cached CS limit. An out-of-range value raises `#GP(0)` before the task error
push or entry commit. This places the IP check after the incoming SS, CS, DS and ES
checks, in the order shown in section 8.3.

`tb/bootstrap.cpp` adds four exact-context cases: null SS plus out-of-limit IP
must report `#SS(0)`, and valid SS plus out-of-limit IP must report `#GP(0)`;
both variants run with READY stalls disabled and enabled. Each case checks the
event packet and transferred CS:IP, flags and SP, task backlink and busy bits,
null error push, handler successor, and absence of a fetch from the invalid
incoming IP.

The new regression failed against the old RTL because it selected vector 13
instead of vector 12 for null SS plus invalid IP. After the RTL change, all
four cases pass.

## Verification evidence

- Exact-source `scripts/run_sim.sh` in `ai-hw-engineer:latest`: exit 0, 196
  `PASS:` lines, no `FAIL:` or `ERROR:` markers. This includes the new cases,
  all prior bootstrap and component suites, and the 79-case protected-mode
  replay in both READY policies.
- Verilator 5.052, `-Wall`; compiler g++ 15.2.0.
- RTL SHA-256: `3e68c9080a7279822983642f0b9729b70269479f5f89db8021e77873104bec3e`.
- Bootstrap test SHA-256:
  `5f56cae56b82d8b378ab1c20e754275eac8bb53c5f24232655679289472e8866`.
- Full simulation log SHA-256:
  `4b4e445f658c66f097daed93c088a760df34429cc01bdb085354d389704890bb`.
- Build manifest fingerprint:
  `055ba1c14219dd1e65f7bcc1b6254307fe494b4f0e1ec15490a944c3c558daf5`;
  main simulation binary SHA-256:
  `a4eb571b3e6a5e34f4c91761fa36a0400b23212964ac472320c1615a33c4a2ab`.
- Exact-source `scripts/run_synth.sh` completed with exit 0 at 03:30 UTC:
  all 13 targets produced JSON netlists, and all 13 Yosys 0.69 logs completed
  with three `Found and reported 0 problems.` checks apiece. Full synthesis log
  SHA-256:
  `463442f6419934901529efeae4a64f9e1fdd251c4810413f9f20101d050d1cf6`;
  native CPU target log SHA-256:
  `24cde9d6581e03852b0d549b65c2b2e3ec36e526d9914e2e5c9ecea381873881`.
- Evidence directory: `design/intel_80286/work/task_switch_ip_priority_20261029_24/`.

No current-source connected-core formal proof was run. The preserved PDR is
still active on its separately captured stale source; its latest log is frame
166 with 344/411 outputs proved and 67 timeout retries. This test does not
close all task-switch priority cases, full POST/boot, OS/2 CPGREP execution on
RTL, or whole-CPU acceptance.

The checkpoint was posted and read back on issue #80 in
[comment 6487134519](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6487134519).
