# Apple IIe MMU validation report

## Result

The complete flow (`scripts/run_all.sh` inside `ai-hw-engineer:latest`) passes:

- **Lint**: `verilator --lint-only -Wall` clean on the RTL with no waivers; the self-checking bench uses the localized BLKSEQ/PROCASSINIT/UNUSEDSIGNAL waivers only.
- **Formal** (`formal/apple_iie_mmu.sby`): BMC depth 32 (`abc bmc3`) **PASS**, unbounded prove (`abc pdr`) **PASS**, cover (`smtbmc z3`) **PASS** with 25 of 25 cover statements reached — no vacuity.
- **Simulation**: the self-checking bench with the independent reference model passes on **Verilator 5.052** (`--binary --timing`) and **xezim 0.10.5** (`--sv2017`), seeds 1 and 7, **57,043 checks, zero failures** per run.
- **Code coverage** (xezim, scope `tb_top.dut`): statement 109/109 (100%), branch 50/50 (100%), toggle 164/164 (100%). No uncovered items; none excluded.
- **Synthesis**: Yosys `synth -top apple_iie_mmu; check -assert` passes.

## What was verified

- Reset state through both `rst_n` and the MPON bus-sequence detector (three $01xx accesses then $FFFC), matching the TRM reset description: bank 2, read ROM, write enabled, auxiliary disabled, ALTZP off, slot ROMs in $C100-$C7FF, internal $C3.
- Every MMU soft switch ($C000-$C00B writes, $C054-$C057 PAGE2/HIRES, $C080-$C08F language-card register) with readback through $C011-$C018 bit 7, including aliasing behavior (latch address bits select the flag; data bit selects the state).
- The language-card prewrite state machine: even accesses protect; two consecutive odd reads enable; odd writes preserve state and never enable; write-enable survives odd-read bank switches; $C011/$C012 track bank 2 and read-RAM.
- Full mapping matrix over all address ranges crossed with switch states and read/write direction: main/aux selection per the spec priority (80STORE/PAGE2/HIRES video-page override, ALTZP for $0000-$01FF and $D000-$FFFF, RAMRD/RAMWRT otherwise), ROM enables per window, CXXXOUT, KBD', RW245, MD7 values, and the Table 7-9 row/column RA patterns including the $D000-$DFFF bank remap on RA4.
- The $C800-$CFFF expansion-window lifecycle (open via internal $C3 access, serve, close via $CFFF), DMA' and INH' behavior, and historical firmware switch sequences from the TRM Appendix I Monitor listing (reset initialization, AUXMOVE-style main/aux copy dance, RESETRET slot-3 ROM probe dance).
- Formal: mapping agreement for an anyconst address against an independently encoded spec restatement, array mutual exclusion, no-RAM-in-$Cxxx, MD7/KBD' enable and value equations, prewrite next-state equations, MPON effect, and window next-state.

## Defects found and fixed during verification

1. **$C100-$C7FF decode** used the wrong address bits (decoded $C800 instead); caught by directed simulation against the reference model.
2. **$C05x select bits**: the 74LS259 select is `a[2:1]`, not `a[2:0]` — PAGE2/HIRES writes were ignored; caught by directed checks.
3. **$C300 precedence**: internal-ROM service for $C300-$C3FF must preempt the $C100-$C7FF rule ($C300 lies inside that range); caught by directed checks.
4. **Hires page decode**: `$2000-$3FFF` was decoded as `a[15:12]==2`, covering only $2000-$2FFF; caught by **formal BMC** on an anyconst address ($3000) that directed simulation never probed.
5. **MPON shift register**: the reference model cleared the $01xx history on MPON while the RTL (like the real chip) keeps shifting; caught by the random soak.

Each fix is reflected in the spec where behavior, not tooling, was wrong.

## Assumptions and limits

Assumptions A1-A9 in `spec/spec.md` remain qualified. In particular: the $D000-$DFFF physical remap (A2) follows the schematic-derived CC0 reimplementation and has not been compared against original silicon; MPON phase qualification is approximated at bus-cycle granularity (A3); RW245 polarity is a stated convention (A4); the real chip's RA output-enable windows, latch transparency and R/W' sampling races (A1, A7, A9) are timing behavior outside the synchronous contract. No electrical, package or nanosecond timing equivalence is claimed. Physical-chip comparison and integration into a full `system/apple_iie` build remain future work.
