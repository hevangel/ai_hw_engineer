# Apple IIe IOU — Validation Report

## Result

The complete flow passes: lint, formal (bmc / unbounded prove / non-vacuous
cover), Verilator and xezim simulation against an independent reference
model, code coverage and Yosys synthesis.

| Stage | Result |
| --- | --- |
| `verilator --lint-only -Wall` (RTL, no waivers) | PASS |
| Formal bmc (abc bmc3, depth 32) | PASS |
| Formal prove (abc pdr, unbounded) | PASS |
| Formal cover (smtbmc z3, all covers reached) | PASS |
| Verilator simulation, seed 1 | PASS (30,831,366 checks) |
| xezim simulation, seed 1 | PASS (30,831,394 checks) |
| Code coverage (xezim, `tb_top.dut`) | statement 167/167 (100%), branch 94/94 (100%), toggle 378/380 (99.47%; the 2 counts are the structurally-constant A15 bit, see [coverage report](coverage_report.md)) |
| Yosys `synth` + `check -assert` | PASS |

## What was verified

### Display address generation (the core)

- **Scanner counters**: 65-state horizontal line (H0-H5 with the HPE' reload
  state), 262-line vertical frame with the TC reload to field 250 (NTSC);
  first post-reset frame is 512 lines (A6). The full frame is scanned in
  simulation from reset — every cycle's RA row/column bytes are compared to
  the reference model.
- **The Σ fold** (Sather p.5-9): `Σ = 1 + {H5',H5',H4,H3} + {V4,V3,V4,V3}`
  mod 16, carry discarded. Formal proves the alternative algebraic form
  `13 + H3 + 2·H4 + 4·H5 + 5·V3 + 10·V4` equivalence (a transcription error
  in either cannot hide; one was in fact caught during bring-up — the golden
  model initially used `−4·H5`, and BMC produced a counterexample).
- **Text/lo-res map**: rows 0-7 at `$400+$80k`, rows 8-15 at `$428+$80k`,
  rows 16-23 at `$450+$80k` — the "three rows per 128-byte block are not
  adjacent on the display" interleave — validated line-by-line against the
  frozen-signal ground-truth sequences (`$0400, $0480, …, $0780, $0428, …`).
- **Hi-res map**: `0x400·(L mod 8) + 0x80·((L div 8) mod 8) + 0x28·(L div 64)`
  (line 0 `$2000`, line 1 `$2400`, line 8 `$2080`, line 64 `$2028`),
  validated the same way.
- **Mode/page bits** (Table 7-13): text `A10 = 80STORE+PAGE2'`,
  `A11 = 80STORE'·PAGE2`; hires `A10-A12 = VA-C`, `A13/A14` aux-page select;
  PAGE2, 80STORE·PAGE2 and hires-page-2 combinations exercised.
- **Mixed mode**: the registered GR flag (with its real one-state skew at
  the L=160 boundary) and the graphics→text region switch of SEGA/SEGB and
  the page bits.
- **Timing pins**: WNDW' (blanking windows), SYNC' (horizontal H=8-11 pulse
  and the NTSC serrated vertical block), CLRGAT' (burst window H=12-15,
  suppressed in text), H0, SEGA/SEGB/VC character-line selects.

### Soft switches

Every switch write/read per spec §5: the C00x latch (80STORE/80COL/ALTCHAR),
the C05x video latch (TEXT, MIXED, PAGE2, HIRES, AN0-AN3) with reset
behavior (PG2/HIRES/AN cleared, ITEXT/MIX not — Sather), IOUDIS gating of
`$C058-$C05D` with select 111 always live (shared AN3/DHIRES bit), the
C07E/C07F IOUDIS latch polarity, and all MD7 readbacks of spec §9 including
the `$C008-$C00F`-returns-KEY quirk (A9) and the `$C011-$C018` OE exclusion
(MMU's flags). Q3 gating and LA7 (`$C080-$C0FF`) deadness asserted.

### Keyboard, speaker, cassette

Strobe flow: IKSTRB pulse → 2-stage retimed KSTRB pin → KEY flag set →
`$C000` read bit 7 → `$C010` write clear → `$C010` read AKD (2-stage
retimed). Auto-repeat: SET_DELAY/N9 shift over three CTC14S ticks while the
key is held, AUTOREPEAT_ACTIVE, then KEY re-sets at the PAKST rate without a
new strobe and clears on key-up. Speaker and cassette toggle once per access
in `$C030-$C03F` / `$C020-$C02F`, reads and writes alike.

### Random soak

20,000 randomized cycles (random C0xx accesses with random R/W, Q3, A6,
random video data bits, random keyboard strobe/any-key events) with every
output re-checked against the reference model each cycle.

## Formal methodology notes

A full frame is 262·65 = 17,030 cycles, so the scanner reset value is an
`(* anyconst *)` under `` `ifdef FORMAL ``: properties are proven around an
arbitrary scanner state, with the counter update rules (HPE' reload,
increment, TC reload pattern) proven as separate local transitions. This
exercises the address function across the whole counter space rather than
only the reset neighborhood. All covers are reached; the only property not
formally closed is the *deep* auto-repeat activation (three CTC14S ticks =
3·2^20 cycles), whose local transition rules are proven unbounded and whose
end-to-end behavior is simulation-verified.

## Escaped-defect notes

Per the repo policy this design is not a CPU, but the same independent-oracle
discipline was applied: the reference model and the formal golden functions
were written from the TRM tables and the frozen-signal ground-truth
sequences, never from the RTL. During bring-up the golden Σ formula carried
a wrong algebraic substitution (`−4·H5` instead of `+4·H5`, since
`12·¬H5 ≡ 12 + 4·H5 (mod 16)`); formal BMC caught it via a counterexample —
the RTL was right and the *spec restatement* was wrong, which is exactly the
failure mode the independent-encoding rule exists to catch.

## Known limitations

See the assumption ledger A1-A10 in [spec/spec.md](spec/spec.md): NTSC-only,
sub-14M timing abstracted to the cycle level, RESET' modeled as a plain
input, ITEXT/MIX power-on values forced to 0, IOUDIS/DHIRES implemented from
the TRM alone (Enhanced IIe; the CC0 reference predates them), board-level
I/O (paddles, NE558 trigger, keyboard data bits) out of scope, RA bus
modeled as split sense/drive ports.
