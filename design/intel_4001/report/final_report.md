# Final Design Report: intel_4001

## 1. Executive Summary

The Intel 4001 reconstruction — 256 x 8 mask-programmable ROM plus 4-bit
I/O port, the program-memory and peripheral-I/O chip of the MCS-4 family —
is implemented, verified, and sign-off ready. All verification gates pass:
Verilator lint is clean, SymbiYosys proves all safety properties (BMC depth
24 and an unbounded PDR proof) with all 38 reachability covers reached, the
direct self-checking testbench passes with 482,958 checks over 2,839
instruction cycles and zero failures, and Yosys synthesizes cleanly to 67
generic cells. The bus protocol is timed to interoperate directly with the
verified `intel_4004` reconstruction on branch `design/add-intel-4004`.

## 2. Design Overview

- Module: `intel_4001` (`src/intel_4001.sv`), single-clock synchronous RTL
- Version: 1.0
- Designer: AI Hardware Engineer
- Date: 2026-08-27
- Behavioral contract: `spec/spec.md`
- State: 3-bit phase counter (SYNC-locked), 8-bit ROM address latch,
  A3-qualified chip-select flip-flop, CM-ROM tracking flip-flop, snooped
  OPR/OPA registers, 4-bit SRC select register, 4-bit I/O output latch
  (cleared by CL only, never by RESET)
- Mask options as parameters: `CHIP_NO`, `IO_DIR`, `ROM_INIT` (under
  formal, the contents become an `anyconst` free constant so proofs cover
  every possible mask)

## 3. Verification Status

### 3.1 Simulation Results (xezim, `scripts/run_sim.sh`)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Directed + random checks | 482,958 | 0 failures | PASS |
| Instruction cycles simulated | 2,839 (incl. 1,500 randomized ops) | — | PASS |
| Failures | 0 | 0 | PASS |
| ROM reads, chip 0 (mask A) | 256/256 addresses (incl. 0x00, 0xFF) | exhaustive | PASS |
| ROM reads, chip 1 (mask B) | 256/256 addresses | exhaustive | PASS |
| Two-chip shared bus | chip-select/deselect, collision watch | no collisions | PASS |
| Directed scenarios | D1-D15 (reset mid-fetch/mid-WRR, CL vs WRR, SRC X3-ignored, absent-chip ops, mixed-direction port, WPM) | all | PASS |

xezim's exit status alone is not treated as pass/fail; `run_sim.sh` greps
the log for `TEST PASSED` and the absence of `FAIL` lines and exits nonzero
otherwise.

### 3.2 Formal Verification Results (SymbiYosys, `formal/intel_4001.sby`)

| Property set | Mode / engine | Depth | Result |
|--------------|---------------|-------|--------|
| All safety properties (S1-S12, protocol, data integrity, reset/CL dominance) | bmc / `abc bmc3` | 24 | PASS (12 s) |
| Same set, unbounded | prove / `abc pdr` | — | PASS, converged (14 s) |
| Reachability covers (38 goals) | cover / `smtbmc --unroll z3` | 240 (all reached by step 23) | PASS: 38 reached, 0 unreached |

Proved properties (details in `formal/intel_4001_props.sv`):

- ROM read-data integrity for an arbitrary `anyconst` address and fully
  free `anyconst` mask contents (M1 high nibble, M2 low nibble, drive
  enables);
- drive-enable gating: the chip never drives the bus outside M1/M2 with
  CM-ROM-qualified chip match, or X2/X3 of a snooped, selected RDR;
- address-latch assembly (A1/A2 nibbles under CM-ROM) and A3 chip-select /
  CM-ROM tracking;
- SRC select semantics: X2 capture, X3 ignored, no other writer;
- WRR port-latch semantics: selected WRR at the X3 edge writes, CL low at
  the same edge dominates (clear wins), unselected WRR holds, nothing else
  writes;
- RDR drives `(IO_DIR & latch) | (~IO_DIR & port_i)` during X2/X3 when
  selected; unselected RDR stays off the bus;
- reset dominance (all static flip-flops, bus inhibited, I/O latch kept)
  and CL clearing only the I/O latch;
- phase counter follows the `{sync, X3}` rule.

Non-vacuity: the environment assumptions constrain the bus master only to
well-formed 4004 timing, and the 38-goal cover set — phases, corner
addresses 0x00/0x01/0x7F/0x80/0xFE/0xFF, nibble values, selected/unselected
fetch and port ops, SRC switching, WRR latch/overwrite/suppress, RDR both
data sources both periods, WPM non-participation, CL clear, mid-cycle
reset, SYNC re-lock, absent CM-ROM — is fully reached.

Formal runs use the default parameters (`CHIP_NO` = 0, `IO_DIR` = 4'b1111);
the parameterized second instance in simulation (chip 1,
`IO_DIR` = 4'b0011, second mask) exercises the mixed-direction and
different-chip-number configurations behaviorally.

### 3.3 Lint/Synthesis

| Check | Tool | Result |
|-------|------|--------|
| Lint (RTL) | Verilator 5.050 `--lint-only -Wall` | PASS, zero warnings |
| Lint (testbench) | Verilator 5.050 `--lint-only -Wall` | PASS, zero warnings |
| Synthesis | Yosys 0.46 (`read_verilog -sv; hierarchy; proc; opt`) | PASS, zero errors |
| Cell count | Yosys `stat` | 67 cells |

Yosys cell breakdown: 1 `$add`, 10 `$eq`, 4 `$ne`, 2 `$not`, 11
`$logic_and`, 1 `$logic_or`, 3 `$logic_not`, 4 `$reduce_and`, 1
`$reduce_bool`, 1 `$reduce_or`, 18 `$mux`, 1 `$shiftx`, 10 flip-flops
(7 `$sdffe`, 2 `$sdff`, 1 `$sdffce`); 0 memories, 0 processes.

## 4. Issues Found and Resolved

| Issue | Severity | Resolution |
|-------|----------|------------|
| Formal property `s7_capture` (WRR latch) fired without excluding CL low at the same edge; the environment leaves `clr_n` free, so BMC found the counterexample at frame 10 where CL clears the latch during a selected WRR's X3 | major (property bug; RTL behavior is correct per the manual's CL pin function) | Antecedent now requires `clr_n` high; the exhaustive triple (CL clears / WRR writes / hold) is split across `s10_clear` / `s7_capture` / `s7_only_wrr`. Directed test D15 added to the testbench for the same scenario |
| Cover goal `c29_reset_midcycle` was unsatisfiable as written: it required the reset state one edge after `rst_n` deassertion, but synchronous reset takes effect one edge after the `rst_n`-low period (the chip first completes the period in progress) | minor (cover bug) | Goal rewritten to the reachable semantics: `rst_n` low for one period with the chip mid-cycle, then phase A1 with outputs inhibited |
| `run_synth.sh` derived the Yosys top module from the design directory name, which breaks inside the verification container where the design folder is mounted as `/workspace` (error: "Module `workspace' not found") | minor (script bug; RTL synthesizes cleanly) | Top module now defaults to `intel_4001` (overridable as the second script argument) instead of the mount-dependent directory name |

## 5. Known Issues / Interpretations

No open defects. Documented interpretations (full list in
`spec/spec.md` section 10.2):

- The chip-number nibble arrives on **A3** (word address low nibble on A1,
  high on A2), matching both the verified `intel_4004` reconstruction and
  MAME's MCS-40 core; design briefs that place the chip number on A1 are
  inconsistent with the CPU's `addr[3:0]`/`addr[7:4]`/`addr[11:8]`
  transmission order.
- CM-ROM is modeled as the verified 4004 drives it (active through A1-A3 of
  every cycle, and at X2/X3 of WRR/WPM/RDR); MAME toggles the line at finer
  grain, but the sampled-phase contract exercised by the 4001 is identical.
- The SRC select capture is qualified by the snooped SRC opcode rather than
  by CM-ROM at X2 (the companion CPU asserts CM-RAM, not CM-ROM, there);
  the captured value and X3-ignored rule match the manual either way.
- WRR latches at the end of X3 and RDR drives through X2 and X3 — the
  compatible superset of the manual's end-of-X2 events and the companion
  CPU's drive/sample windows, since the CPU holds WRR data across both
  periods and samples RDR at the end of X3.
- WPM is decoded but produces no response, as on the real part.

## 6. Open Items

None.

## 7. Sign-off

| Criterion | Status |
|-----------|--------|
| RTL frozen | PASS |
| Formal clean (bmc + prove + cover) | PASS |
| Simulation coverage met | PASS |
| Lint clean | PASS |
| Synthesis clean | PASS |

## 8. Appendix

### Resource Utilization (Yosys 0.46)

RTL-level elaboration (`read_verilog -sv; hierarchy -top intel_4001; proc;
opt; stat`):

```
   Number of wires:                 77
   Number of wire bits:           2185
   Number of ports:                 11
   Number of port bits:             26
   Number of memories:               0
   Number of cells:                 67
     $add                            1
     $eq                            10
     $logic_and                     11
     $logic_not                      3
     $logic_or                       1
     $mux                           18
     $ne                             4
     $not                            2
     $reduce_and                     4
     $reduce_bool                    1
     $reduce_or                      1
     $sdff                           2
     $sdffce                         1
     $sdffe                          7
     $shiftx                         1
```

Gate-level generic synthesis (`scripts/run_synth.sh`, after `techmap;
opt_clean`; the 256:1 ROM read mux dominates the count):

```
   Number of cells:               2217
     $_AND_                         21
     $_DFF_P_                        2
     $_MUX_                       2066
     $_NOT_                         18
     $_OR_                          41
     $_SDFFCE_PN0P_                  4
     $_SDFFE_PN0P_                  20
     $_SDFF_PN0_                     1
     $_SDFF_PP0_                     2
     $_XOR_                         42
```

(29 flip-flop bits in both views: phase 3, address 8, CM-ROM-seen 1,
fetch-select 1, snooped OPR/OPA 8, select register 4, port latch 4.)

### Test List (tb/tb_intel_4001.sv)

| ID | Scenario |
|----|----------|
| D1 | Power-on reset; CL cycle defines both port latches |
| D10 | RDR before any SRC (reset select value 0 selects chip 0) |
| D2 | Exhaustive ROM read, chip 0, addresses 0x00-0xFF |
| D3 | Exhaustive ROM read, chip 1, addresses 0x00-0xFF |
| D4 | Real and absent chips interleaved (only the addressed chip drives) |
| D5/D6 | WRR latch, RDR read-back, overwrite |
| D7 | Per-chip port isolation |
| D8 | Mixed-direction port (output pins from latch, input pins from pins) |
| D9 | Port ops aimed at an absent chip leave latches untouched |
| D11 | SRC X3 nibble carrying a different chip number is ignored |
| D12 | Ignored opcodes incl. WPM with active X2/X3 drive and CM-ROM |
| D13 | Reset mid-fetch (M2) and mid-WRR (X2); port latch survives |
| D14 | CL cycle clears the latch mid-run; the rest keeps running |
| D15 | CL through a complete WRR cycle: clear dominates the same-edge write |
| R | 1,500 fixed-seed randomized ops (fetch/SRC+WRR/SRC+RDR/CL/WPM/NOP, chips 0-3, random addresses and data) |

Formal cover goal list (38): see `formal/intel_4001_cover.sv`.
