# Failure Notes

Post-mortems for bugs that **escaped verification** — defects that shipped
past lint, simulation, and formal because the checks themselves shared the
buggy assumption, or because no check exercised the failing path.

## When to write one

Write a note whenever a bug is found by anything *other* than the design's
own verification suite: real firmware/software, a third-party tool, an
external reviewer, or production use. Bugs caught by the design's own
testbench before commit do not need a note.

## What belongs in a note

1. What broke, where, and how it was observed (the external oracle).
2. Root cause — including *why the verification suite did not catch it*.
   If the reference model shared the wrong assumption, say so plainly.
3. The fix and what re-verification was run.
4. The prevention plan: which concrete rule, test, or checklist item (in
   this folder and in AGENTS.md) exists now that would have caught it.

Blame-free by design: these notes exist to fix the *process*, and the repo's
author is the same agent in every session — the useful question is never
"who" but "which step let a shared assumption pass as verified".

## Index

- [2026-10-21 — 4059 asynchronous latch release](2026-10-21-ttl4059-asynchronous-latch-release.md)
  Stopped-clock source review exposed LE release incorrectly sampled only on CP edges.

- [2026-10-20 — extended TTL reference assumptions](2026-10-20-ttl-extended-reference-assumptions.md)
  Manufacturer review exposed shared counter-edge, ROM and collector-release assumptions above 74299.

- [2026-10-20 — inherited TTL oracle assumptions](2026-10-20-ttl-inherited-oracles.md)
  Manufacturer tables exposed shared strobe/edge assumptions and writable ROM models during library integration.

- [2026-10-18 — Model 30 MCGA mode 6](2026-10-18-model30-mcga-mode6.md)
  Original BASICA exposed high-resolution-only graphics decoded as text.

- [2026-10-18 — 8259A withdrawn request](2026-10-18-intel8259-withdrawn-request.md)
  Original FDISK warm restart exposed an edge/request-latch interpretation
  shared by RTL and reference model.
- [2026-10-18 — Model 30 floppy identification](2026-10-18-model30-floppy-identification.md)
  Original FORMAT exposed a 720K drive reported as high density.

- [2026-10-16 — XT fixed-disk sector-buffer diagnostic](2026-10-16-xt-fixed-disk-sector-buffer.md)
  Original IBM adapter ROM exposed missing SRAM commands through POST error
  1701; initial direct DMA tests had covered only disk media.

- [2026-10-15 — Model 30 planar integration](2026-10-15-model30-planar-integration.md)
  Original POST exposed CPU/DMA clock crossing and omitted floppy/serial
  gate-array behavior that standalone chip tests could not cover.

- [2026-10-15 — PIT Mode 0 count rewrite](2026-10-15-pit-mode0-rearm.md)
  Original Model 30 POST exposed terminal OUT remaining high across a count
  rewrite, preventing the second timer interrupt.
- [2026-10-14 — intel_8237 programming while waiting for bus grant](2026-10-14-intel8237-pending-grant-programming.md)
  Original IBM BIOS format exposed mode writes lost when refresh raised HRQ
  before the CPU completed its current I/O cycle.

- [2026-10-14 — intel_8272 format final-ID terminal count](2026-10-14-intel8272-format-terminal-count.md)
  A real CPU/DMA board test found a normal format result with the final sector
  omitted when TC accompanied its last ID byte.

- [2026-10-14 — intel_8272 READY events and original IBM PC BIOS](2026-10-14-intel8272-ibmpc-ready-events.md)
  BIOS reset exposed overly broad command rejection and separate startup
  polling IRQs hidden by the standalone startup helper.

- [2026-10-11 — intel_8086 native bus and prefetch cancellation](2026-10-11-intel8086-native-bus-audit.md)
  Datasheet audit exposed arbitration and INTA/wait/T4 pin gaps after instruction
  checks passed; a new formal monitor exposed repeated-redirect tag wrap.

- [2026-10-13 — mos_6502 D1 opcode remap](2026-10-13-mos6502-d1-cmp-zpy.md)
  The oracle and the RTL were "corrected" together to run opcode D1 as SBC
  (zp),Y; the directed replay passed on shared wrong semantics until Klaus's
  functional test executed a genuine CMP (zp),Y.

- [2026-09-27 - Busicom manual, decimal carry and board integration](2026-09-27-busicom-manual-regression.md)
  Manual replay and independent MAME semantics exposed TCS/DAA errors shared by
  the CPU models, plus incomplete keyboard polarity and printer index integration.

- [2026-09-02 — intel_4004 FIN program-counter advance](2026-09-02-intel4004-fin-pc-advance.md)
  Escaped per-instruction sim + formal because the ISS and the formal
  golden model shared the RTL's wrong FIN PC rule. Caught by running the
  original BUSICOM 141-PF firmware.
- [2026-09-27 — busicom_141pf keyboard 4003 data polarity](2026-09-27-busicom-kbd-4003-polarity.md)
  Escaped board bring-up because the tests drove keys_mask directly and
  never exercised the serial shift path. Caught by Kintli's annotated
  firmware source (user-supplied): the `~` on the keyboard 4003 data
  input inverted the firmware's active-low column scan.

- [2026-10-03 — Apple II copper topology and floating data bus](2026-10-03-apple-ii-copper-floating-bus.md)
  An independent copper layout exposed a shorted soft-5 branch and missing
  unused-output ground; a historical circuit/software description exposed
  missing passive data-bus charge retention.

- [2026-10-18 — Apple II reference startup initialization](2026-10-18-apple-ii-reference-initialization.md)
  AddressSanitizer exposed an uninitialized group count in the pinned external solver; the build derives an allocation-only fix while retaining original source hashes.

- [2026-10-19 — Apple IIe ROM extension and read-side video switches](2026-10-19-apple-iie-rom-switches.md)
  Original firmware exposed shared MMU/IOU reference assumptions about C800 ROM and R/W video switches.

- [2026-10-19 — Apple IIe coverage-sensitive simulation](2026-10-19-apple-iie-xezim-coverage.md)
  Board RAM readback changes under xezim coverage instrumentation; strict functional tests remain and Verilator supplies coverage.
