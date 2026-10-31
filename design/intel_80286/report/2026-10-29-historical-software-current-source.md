# IBM AT software regression on current source

## Current-source refresh — 2026-10-29 06:43 UTC

Reran `scripts/run_software.sh` after the task-gate RTL change, using the
pinned IBM AT ROM and Unicorn 2.1.4 from the earlier evidence directory. The
script exited 0: the unchanged BIOS matched 196,846 instruction states through
ROM-checksum success, the hex helper matched 16 cases / 464 states, IRQ8
matched 8 cases / 236 states, and the system-register self-test matched four
patterns / 164 states. This remains a bounded CPU fixture, not full POST/boot.

All 38 entries of the build manifest match the current worktree. Runner
fingerprint: `81f4f370b54b64afe0a94ebaa375b881930b742bedbea7bf09a97c4a158a53c2`.
The ignored evidence directory is `work/current_software_20261029_01/`:

- `run_software.log` SHA-256: `81F12A04F12C36D7B3DFA20D5D9BE9DBEE0AC38FFF3A641E51512B612F92ED58`.
- `sim/build_manifest.json` SHA-256: `71A3494FA86A2975103FF31C2FF38F0893C7787842CFFD58FB81FA394A5425AA`.
- `sim/Vintel_80286` SHA-256: `82CD7B1E0B72A02F3D721432697A7225EE890B79BA453425D2D9C2242008BACC`.
- `software/oracle_trace.txt` SHA-256: `A24091CD9D499DA68232006D67A7DFADCAB2A5F1A7BF9404F56F999288CE5E3C`.
- `software/atbios.bin` SHA-256: `74E7B36B4EC0ADC5AC3277A887579996C1D2AA755B9892EF3AFE7485C10CE04F`.

### POST boundary probe

An exploratory Unicorn run removed only the `F000:0225` stop and continued
with the same static I/O fixture. It reached its 500,000-instruction bound;
the final 50,000 instructions repeat eight addresses `F000:0242`–`0251`.
The original ROM writes control port `43h` and repeatedly reads port `41h`
while testing the timer. The fixture returns its static stored port value,
so this run cannot establish a working timer or POST. The partial probe trace
and log are in `work/current_software_20261029_01/`; they were not replayed
on RTL and are not a passing regression. A source-backed timer model and its
machine integration are needed before extending the POST acceptance gate.
The repository already contains `design/intel_8253_8254`, with a reusable
digital timer and an existing IBM PC integration. The 5170 variant, clock,
gate wiring and fixture time relationship still need source-backed definition.
The checkpoint was posted and read back in
[issue comment 6489942100](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6489942100).

**Date:** 2026-10-29  
**Worktree:** `B:\\ai_hw_engineer\\worktree\\intel-80286`  
**Scope:** Original IBM AT REV1 BIOS execution on the current 80286 RTL with a
bounded CPU fixture. This does not claim full POST, timer-driven boot, or a
complete IBM AT motherboard model.

## Change

`scripts/run_software.sh` now provisions the pinned Unicorn 2.1.4 package into
the selected ignored work directory before generating the independent BIOS
trace. This matches the vector regression's dependency isolation and makes the
software entry point work in the repository Docker image without a preinstalled
Python package.

## Verification

The exact command `scripts/run_software.sh` completed in `ai-hw-engineer:latest`
with exit code 0. The runner was reused after its source-checked build:

- Verilator 5.052, strict `-Wall` runner; build fingerprint
  `58b3569f7a9d565b0192fcdfb421ed147c40ec88193ed29c8be1f4486e7833c2`.
- Runner binary SHA-256:
  `7b8e8c1677a9bd05f20d46bc74e15c8ee6bcb3a81b004c6c7f3c3b5624a7f47c`.
- Original pinned PCjs ROM archive SHA-256:
  `3b1a6c8cd59a5ac725809a90de0808f7965c34be229099339203fccba0b2bde6`.
- Decoded 64 KiB ROM SHA-256:
  `74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f`.
- Unicorn 2.1.4 generated 196,846 exact instruction states through the
  original ROM-checksum success checkpoint at `F000:0225`; trace SHA-256
  `d211031d9f1dcc68873ac9ad91486bca119f3a3881b3b820947d6d348fc7641a`.
- The unchanged BIOS hexadecimal helper passed 16 cases / 464 states; trace
  SHA-256 `bf2aaee5ca1430a73b85206a6c82fdca55b95351f06eb5fec3d611cec913c5a9`.
- Eight IRQ8 timer cases passed across 236 original handler states, including
  nested INT 1Ch/IRET, BDA rollover, and checked hardware outputs.
- The original BIOS system-register self-test passed four patterns / 164
  exact instruction states.

The complete verified log is
`design/intel_80286/work/historical_software_current_20261029_23/run_software_verified.log`
(SHA-256 `01962b63ba93f8b2de598327d5b17f90bb9d3055a4a660caee592bc589a2daf1`).
The independent trace manifests and all generated files are retained in the
same ignored evidence directory. No RTL source changed in this checkpoint.

## Rerun after task-entry ordering fix — 2026-10-29 04:22 UTC

After correcting incoming task descriptor order, reran
`scripts/run_software.sh` against the then-current source. It exited 0 in
`ai-hw-engineer:latest`; the log is
`design/intel_80286/work/task_switch_ss_cs_priority_20261029_37/run_software.log`
(SHA-256 `30349c4e8a134829f4bacfd82a6fb2c516982eedb795ef0ea640cf7b51f6e7b4`).
Its build manifest fingerprint is
`c77bc44dcf25e963193048656ca6c6fdaf9bfe41517ddeee2a83c732ea97de34`, using
Verilator 5.052 and g++ 15.2.0; the runner binary SHA-256 is
`b5c448a04988c6c37d2bc32887449ab23e97ce73b4a8794034de8a2c23001cd4`.

The independent Unicorn 2.1.4 trace again contains 196,846 exact instruction
states through the original checksum-success checkpoint at `F000:0225`; trace
SHA-256 is
`3ce98c70ef6b11bb1c8d75b9ac9b909ef4f0e1b0fa46f8b2f593888aeb1bdeb8`.
The unchanged BIOS hex helper passed 16 cases / 464 states (trace SHA-256
`bf2aaee5ca1430a73b85206a6c82fdca55b95351f06eb5fec3d611cec913c5a9`). Eight
IRQ8 cases passed across 236 exact handler states, and four system-register
patterns passed across 164 exact instruction states. The source and generated
manifests are retained under the same `_37` evidence directory. This rerun
still stops before full POST/boot and does not provide an OS/2 CPGREP RTL run.

## Remaining limit

This closes the bounded IBM AT BIOS run against the current source. It stops
after the ROM-checksum checkpoint and separately exercises a BIOS helper,
IRQ8 handler, and system-register self-test. It does not execute full POST or
establish a complete machine boot. The OS/2 SDK 1.00 CPGREP workload still has
no RTL trace. Current-source connected-core formal and the full CPU release
gate also remain open.
