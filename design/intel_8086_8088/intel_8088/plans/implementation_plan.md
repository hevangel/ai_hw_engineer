# Intel 8088 implementation plan

## Goal

One canonical member folder `design/intel_8086_8088/intel_8088` for the Intel 8088 (introduced June 1, 1979): the shared 8086 execution unit behind a native four-byte byte-fetch BIU with the 8088's pin profile, per [ai_engineer#271](https://github.com/hevangel/ai_engineer/issues/271). The existing `system/ibm_pc` byte-wide adapter is inventory, not a verification claim; this member provides the standalone chip.

## Non-goals

- No copy of the execution-unit RTL: the EU lives in `../../intel_8086/src/` and is referenced by path. Fixing the EU happens in the owning member.
- No electrical timing, analog or package model; no per-instruction cycle-count claims.
- No system integration change: `system/ibm_pc` and `system/ibm_pc_xt_5160` keep their adapters until the systems' own issues re-point them at this chip.

## Steps

1. Scaffold the member with `scripts/new_design.sh intel_8086_8088/intel_8088`; template directories only, all content authored fresh.
2. Implement `src/intel_8088_biu.sv`: four-byte byte queue, one-byte prefetch whenever a byte is free, byte-only bus phases (IDLE/T1–T4/Tw), whole-word EU transactions split into two ascending byte cycles completing as one transfer, INTA kept as a single cycle per acknowledge, IO/M reversed polarity, SS0 as the minimum-mode S0 mirror with pin 34 driven high in maximum mode, non-multiplexed A8–A15, READY waits, HOLD/HLDA and RQ/GT arbitration mirroring the 8086 member with the word-atomicity guard. Inline `ifdef FORMAL` assertions and covers.
3. Implement `src/intel_8088_chip.sv`: chip top instantiating the shared `intel_8086` EU plus `intel_8088_biu`, with explicit output enables and the 8088 pin set.
4. Port the verification environment from the 8086 member:
   - `tb/tb_native.cpp` byte-accurate native bench (pin invariants per cycle, directed min/max scenarios, DEBUG.COM fixture, physical-vector runner with exact-IP/next-instruction checks, queue seeding capped at four bytes).
   - `tb/tb_dos.hpp`, `tb/tb_vectors_common.hpp` reused from the 8086 member with the 8088 vector-header magic.
   - `tb/intel_8088_if.sv`, `tb/intel_8088_uvm_pkg.sv`, `tb/tb_top.sv`: chip-pin-level UVM environment with a byte-bus memory responder, per-cycle scoreboard and 11 scenarios.
5. Scripts mirroring the 8086 member set: lint, formal (`formal/intel_8088_biu.sby` bmc/prove/cover), UVM simulation, software regression (startup figure 2-63 + DEBUG.COM through the chip in both modes), native directed tests plus the SingleStepTests/8088 physical vectors in both modes with oracle negative controls, and Yosys synthesis. Explicit cross-folder source lists; no globs that would pick up 8086-specific files.
6. `scripts/prepare_vectors.py` fetches the pinned SingleStepTests/8088 corpus (tree-SHA locked, host-allowlisted, integrity-checked), bounds the run to a deterministic first-20-accepted-per-file selection and decodes the captured byte-bus traces (address latched on T1, transfer kind from T1, data on T3) into ordered byte effects.
7. Update the family README, the design index, `scripts/design_families.json` and this member's report; record every result honestly in `report/final_report.md`.

## Verification gates

See [verification_plan.md](verification_plan.md). The member is done when lint, formal (with non-vacuity covers), UVM simulation, both original-software regressions, directed native bus tests, the physical-vector regression in both bus modes with oracle negative controls and synthesis have run green in the tool image, and the report distinguishes documented behavior, finite evidence and explicit limits.
