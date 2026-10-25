# Implementation Plan — Motorola MC6800

## Scope

Full documented instruction set (72 instructions, 197 valid machine codes
per M68PRM(D) Table 3-1) on a functional transaction bus: one bus transfer
per `clk`, in the style of the project's `mos_6502` and `intel_8080`
functional-bus cores. Out of contract: the two-phase pin protocol, DBE/TSC
handshakes, per-opcode cycle counts and electrical timing.

## Primary sources

- Motorola M6800 Programming Reference Manual, M68PRM(D), November 1976
  (bitsavers scan; text extracted in scratchpad for this design). Every
  flag rule in the RTL is traceable to a page in Appendix A or Chapter 3:
  - Opcode map and 197-code count: Table 3-1 (p. 3-2).
  - Stack mechanics: store at SP then decrement (Ch. 3.2, Fig. 3-5).
  - Interrupt frame order and CC stacking (bits 7-6 set, pre-interrupt I):
    Ch. 3.2 and the SWI example (A-68).
  - IRQ sequence: save status, then set I, then load PC (Ch. 3.3.4).
  - CPX: N/V from the high-byte compare, Z from the full 16 bits, C not
    affected (A-33).
  - Shifts: V = N ⊕ C after the operation; LSR clears N (A-7, A-48,
    A-54, A-55).
  - DAA truth table (A-34).
  - INX/DEX affect only the 16-bit Z (A-38, A-42).
  - SUB carry is the borrow itself: "set if the absolute value of the
    contents of memory are larger than the absolute value of the
    accumulator" (A-66) — NOT the 6502's inverted convention.
  - JSR/BSR: no direct mode on the 6800 (9D is 6801+); RMW ops have no
    direct mode.

## Structure

Single module `motorola_6800.sv`:

- Microsequenced state machine (30 states): fetch → mode/ea states →
  operand read/write/RMW states → execute, mirroring `mos_6502`.
- Rows 0-7 of the opcode space decoded by an explicit case; rows 8-F
  decoded algorithmically on the column (matches the regular Table 3-1
  structure). Unassigned codes execute as mode-length no-ops (documented
  assumption).
- ALU flag helpers as pure functions (Yosys-compatible name-assignment
  style).

## Verification plan

1. **Independent oracle**: a Python ISS written from the PRM only (never
   from the RTL), in `scripts/make_isa_vectors.py`. It doubles as the
   directed-program assembler: generates a straight-line program covering
   every documented opcode in every mode, DAA corner values, all 15 branch
   conditions with taken/not-taken flows, and scripted IRQ/NMI/SWI/WAI
   scenarios (external triggers keyed to program counters, shared with the
   testbench). Emits `vectors.hex` (boundary register records),
   `mem.hex`/`gold_mem.hex`, `triggers.hex`.
2. **RTL replay** (`tb/tb_top.sv`): compares (pc, a, b, ix, sp, cc) at
   every opcode-fetch boundary and the full 64 KiB memory at the end.
3. **Third-party software gate** (`tb/tb_thirdparty.sv` +
   `scripts/check_thirdparty.py`): 50 self-checking programs vendored from
   github.com/hakanrw/mc6800 (see `references/hakanrw_mc6800/`), assembled
   by the small assembler in `scripts/assemble_thirdparty.py`, free-run on
   the RTL, and compared byte-for-byte against the oracle's result windows.
   This gate exists to catch shared misreadings between the RTL and the
   ISS (it did — see `failure_notes/2026-10-23-motorola6800-subtract-
   carry-and-acc-select.md`).
4. **Formal**: BMC/prove/cover for bus discipline, reset/vector behavior,
   interrupt-frame addressing, subroutine-linkage byte order, RMW address
   stability, WAI state and bounded sequencer progress.
5. Lint under `verilator --lint-only -Wall`; generic Yosys synthesis.

## Known deviations / open items

- Undocumented opcodes execute as 2-byte (or mode-length) no-ops.
- Cycle counts are not modeled; the original 2-phase pin protocol is
  replaced by the single-clock functional bus.
- Original MIKBUG-era ROM software regression (MIKBUG needs a modeled
  6850 ACIA) is a possible follow-on; the third-party suite is the
  software gate for this revision.
