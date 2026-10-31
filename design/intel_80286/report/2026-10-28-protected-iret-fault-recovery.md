# Protected outer IRET descriptor-fault recovery — 2026-10-28

## Current-stack frame-boundary follow-up — 2026-10-28 17:42 UTC

Added restartable handling for current-SS access faults raised while protected
IRET reads its five-word outer-return frame. The `MEMORY_CHECK` path now routes
only a protected IRET's current-stack access fault through normal exception
delivery, preserving the fault vector and error code and clearing partial IRET
preflight state. A nested event-delivery or task-switch failure continues to
use the bounded escalation path.

Two new boundary cases run with READY stalls both disabled and enabled. An
initial SP `0090h` above the current SS limit `008Fh` raises #SS(0) without
reading any source-frame byte. With SP `0080h` and limit `0087h`, the first
three words (IP/CS/FLAGS) are read, then the full-frame check raises #SS(0)
before outer SP/SS or target-CS descriptor lookup. Both cases preserve all ten
source-frame bytes; the handler loads a wider current SS, retries the same
IRET and reaches the exact ring-3 successor. Intel 210498-005 Table 7-4 was
visually reviewed using Playwright CLI; it specifies #SS(0) for the current
stack SP and SP+N+7 checks.

Verification against the current source and testbench:

- `python3 scripts/preflight.py` — pass.
- Strict Verilator 5.052 `-Wall` runner build — pass; build fingerprint
  `b2815e38db5d01d6a3620c897379480711fc9a532fe80ae5110061847bfe59c3`.
- RTL SHA-256: `3a4eab169a9cf4d0459559801cb1e810b5b0db63b454c70b02b64abe5a591029`.
- Testbench SHA-256: `067a6503de704b37b6e874184147b5f7177fc9ddd9a90c6d3983d55c0e4722c2`.
- Build-manifest SHA-256: `dc485cd7749ddc75b5809a6dac11474235f4b8950e942b7cf3a5d6cb37854765`.
- Runner binary SHA-256: `75ac1cc3656e38809f57b0b807a2214fb4fa1e0e7f29f719d1a1ad88fe71d5da`.
- `Vintel_80286 --protected-iret-faults` — all 24 executions pass; log SHA-256
  `44a6c1c8b69f02b3578bf267dd05e201bb6046ff0c06db32cb8e3787039187ea`.
- Full default `Vintel_80286` bootstrap — pass; log SHA-256
  `bcb0cb86b1a7654b5c0e1a25a46d0a0c1adef2ce6040ab2a3660f362c2600a0e`.
- `git diff --check` — pass (Git reports existing line-ending normalization warnings).
- Current-source Yosys 0.69 synthesis matrix — pass, exit 0; all 12 targets
  produced netlists and each target log reports zero structural problems.
  Logs and netlists are under `work/iret_current_synth_20261028_14/synth/`.

The whole-core PDR remains tied to a different, older RTL snapshot and is not
evidence for this change. The current-source connected-core proof and broader
exception/fault-priority coverage remain open. GitHub issue #80 has the
completed synthesis checkpoint at
[comment 6476273413](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6476273413).

## Follow-up — 2026-10-28 16:59 UTC

Expanded the same-level-repair path to cover 20 executions over both READY
modes. The return-CS matrix includes null (#GP(0)), inward (#GP(selector),
before descriptor lookup), non-present (#NP) and system-descriptor (#GP)
cases. A fifth case uses saved IP `0400h` with a valid ring-3 code descriptor
limited to `03FFh`; it raises restartable #GP(0), preserves the five-word outer
frame, then succeeds when the handler substitutes a valid, larger-limit CS
descriptor and retries the same IRET. The five outer-SS cases (null,
non-present, code-in-SS-slot, RPL/DPL mismatch and selector beyond the GDT
limit) raise #SS with the documented selector code, preserve the outer frame,
and repair/retry to the exact successor. The inward case preserves its
same-level frame. Descriptor reads and denied accessed-byte writes are checked.

Intel [210498-005, Table 7-4](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=148)
was visually reviewed with Playwright CLI. It classifies the outer-return SS
selector, descriptor-table-limit, writable-data-type and presence checks as
Stack Fault checks, with the return-SS selector as the error code. Intel
[Table 9-1](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=168)
was also reviewed; it classifies an IP outside the code segment limit as #GP
with error code 0. The current source maps rejected outer-IRET SS descriptor
checks to #SS and preserves the segment checker's selector error code.

Verification against current RTL and testbench:

- `python3 scripts/preflight.py` — pass.
- Strict Verilator 5.052 `-Wall` runner build — pass; fingerprint
  `1e23dcf233aaae05eacb153eeaebacc5345823ab25188b266712e18c646da879`.
- RTL SHA-256: `d4b63d5c0f729950459dc56074fd79df3f6fb47331799be3ef33a118f1bea1cb`.
- Testbench SHA-256: `af94f2ecf5d4864d35249160d09dcbc001b73a2c18d758b3e032f45a9c4be036`.
- Build-manifest SHA-256: `12921bac4d9a66629875a1685aec65e6e9039042c4428caf2dfd3281da4c5748`.
- Runner binary SHA-256: `ecb5e9c93ac3143d9e30d92d5d67f643e228ee29163bb6b1c6c602b9a26b1b15`.
- `Vintel_80286 --protected-iret-faults` — all 20 CS, inward-return, SS and
  READY-mode executions pass; log SHA-256
  `5f2811478f3e47b4de210e53d7b533d59e953b0df6e98589a33eb506a6a00d74`.
- Full default `Vintel_80286` bootstrap — pass; log SHA-256
  `8bb503bb4190d2dd7551cfda032b2ded49c1b447652bc8f630f3da8e355c012f`.
- Current-source Yosys 0.69 synthesis matrix — in progress; the prior source
  snapshot's 12-target matrix passed, but does not close this rerun.
- A separate whole-core PDR remains active against an older 21-file snapshot
  (`intel_80286.sv` hash `71ebadce9b7ae4ebeff104274254b938424fa9fca8aa2f171dca34a18109c7c5`).
  At 16:57 UTC it was at frame 25, with 326/411 outputs proved and 24 timeout
  retries. It is not evidence for the current source.

The issue checkpoint is [comment 6475373524](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6475373524).
Post the current-source synthesis result when the matrix exits.
Current-stack frame-boundary ordering and the current-source connected-core
proof remain open.

## Change

Protected IRET now delivers a descriptor fault from its return-CS lookup at the
faulting IRET instruction. A code-load #NP or #GP preserves the original return
frame and error code for the handler. A system descriptor in the return-CS slot
raises #GP with the selector error code. The return state is cleared before
starting event delivery, so a handler can repair the original frame and use
same-level IRET to retry.

The original focused regression covered two descriptor cases, later expanded
to the 20-case matrix summarized above:

- A not-present ring-3 code descriptor raises restartable #NP(0048).
- A system descriptor in the ring-3 CS slot raises restartable #GP(0050).

Each runs with READY stalls both disabled and enabled. The fixture starts at
CPL 0, constructs a real five-word outer-IRET frame, checks the exact exception
packet and error frame, verifies the rejected descriptor is read without an
accessed-bit write, repairs only the original frame's CS slot, returns to the
original IRET, and executes the exact ring-3 successor. The prior valid
`--outer-iret` case also remains passing.

## Source basis

Intel's [80286 and 80287 Programmer's Reference Manual, 1987, §9.6 and Table
9-3](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=171)
lists Segment Not Present (vector 11) and General Protection (vector 13) as
restartable exceptions that push error codes. Section 9.6.7 (PDF page 175)
says a descriptor-type protection fault identifies the
selector, with its RPL bits cleared. The manual was visually reviewed through
Playwright CLI on 2026-10-28. The selector error values in the regression are
therefore 0048 and 0050 respectively.

## Verification

- `python3 scripts/preflight.py` — pass against the final source.
- Strict Verilator 5.052 runner build with `-Wall` — pass; build fingerprint
  `b4d78d68b6f29a1caf0a77d6f0f6348c11eb21c5a8a2406bb21586a3cda9ef50`.
- RTL SHA-256: `0eff3537e99e2a7ffb61189f016418209a3546917b2261e34ea5df261a7e6efc`.
- Testbench SHA-256: `9e775787f04c1b82ff0c37ef37731e9673122ad3c4c3a904d4dd46efb59fa0a2`.
- Runner-manifest SHA-256: `5abbc87a9b9e57f7b25e857bbbbe5827672dbabcaca463016a4c96be7bd56541`.
- Runner-binary SHA-256: `32f9dc00573b5143219f90b6b788bb57c52834ef3291159a1e295852e741505c`.
- `Vintel_80286 --protected-iret-faults` — 4/4 fault and READY-mode cases pass.
- `Vintel_80286 --outer-iret` — both READY modes pass.
- Full default `Vintel_80286` bootstrap — pass. Captured log:
  `work/iret_faults_20261028_02/bootstrap.log`.
- Focused log: `work/iret_faults_20261028_02/protected_iret_faults.log`.
- Focused-log SHA-256:
  `f0ce02e721b42b2b5495e9cd00553238b9cdfd565fec47aac90593671e11989a`.
- Full-bootstrap-log SHA-256:
  `068128e6e884a2208f2761cbfbe99218c76380e74ae544e0dccdede3e979b6da`.
- Valid outer-IRET log SHA-256:
  `f1394f52030ac65a0893f666df1e31f5da07f1b2c026834128178551f119fafd`.
- Source/build manifest and binary are under
  `work/iret_faults_20261028_02/sim/`.

The complete `sh scripts/run_synth.sh` matrix passes with Yosys 0.69
(`9f75ca1f9`): all twelve targets wrote JSON netlists, all twelve logs report
zero structural problems, and the script exited 0. Targets are the functional
and native-beat cores; event control; segment check/load; code check/load;
access check; cached reference; native bus; 82288; and native CPU. Logs and
netlists are under `work/iret_faults_20261028_01/synth/`.
The issue checkpoint is [comment 6474767733](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6474767733).

## Limits and next work

This closes only non-present and system-descriptor return-CS faults. Invalid
outer SS descriptors, return-IP limits, frame bounds, null/inward CS rejection
at the earlier IRET precheck, broader priority combinations, and faults during
event delivery remain open. The current-source connected-core formal gate has
not been rerun for this RTL change. An older whole-core PDR job still uses a
different 21-file snapshot and is not evidence for this source. The complete
80286 objective and release gate remain open.
