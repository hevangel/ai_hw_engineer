# IBM PC AT 5170 implementation plan

Status: M0 (this specification and plan). No system RTL yet.

Each milestone ends with a report in `report/` and an update to issue
https://github.com/hevangel/ai_hw_engineer/issues/254. A milestone is done
only when the unchanged BIOS or software reaches its stated point on the
RTL, matching an independent machine.

## M0: scaffold and sources

- Create the system folder, specification, plans and index entry.
- Remaining sourcing (needed before M1 or M2 RTL; see the spec): system I/O
  map, 8042 commands and output port, CMOS map and shutdown byte, NMI mask,
  type-1 CPU clock, port 80h checkpoints, exact announcement date.

## M1: board skeleton and early POST

- Promote the 286 AT fixture modules (timer, two DMA controllers, page
  registers, refresh path, port 61h, bank select, RAS trigger) from
  `design/intel_80286/tb/` into `src/` as system modules. Keep the 286
  design's own fixture tests running against the promoted modules, or
  have them instantiate the system copies, so there is one implementation.
- Add 640K base RAM, the ROM aliases, two cascaded 8259s, and the NMI
  mask and parity-check bits.
- Stub-free rule: every port the BIOS reads in M1 returns either a modeled
  device or the open-bus value IBM documents. A port with no source fails
  the run loudly instead of returning a guess.
- Goal: the BIOS passes the interrupt controller tests and reaches the
  first point that needs the 8042 or CMOS. Compare each instruction with
  Unicorn (CPU state) and the run with 86Box (checkpoints and I/O order).

## M2: 8042, CMOS, A20 and CPU reset

- Depends on ai_engineer#120 (8042) and ai_engineer#121 (MC146818).
- Wire the 8042 output port to gate A20 and CPU reset, with the CMOS
  shutdown byte. The BIOS uses this path for its protected-mode memory
  test; OS/2 uses it to return to real mode.
- Add expansion RAM above 1 MB.
- Goal: POST memory test passes, including the protected-mode portion.

## M3: video, keyboard and diskette; full POST

- Video adapter per decision D2. Extract the CGA from the PC system into a
  reusable module rather than copying it.
- Keyboard scan codes from the host through the 8042.
- AT diskette adapter (digital output register, data-rate register) with
  the 8272.
- Goal: POST completes and the BIOS attempts to boot. Web panel and
  waveform screenshot in the README.

## M4: PC DOS

- Boot PC DOS from diskette, run DIR, write and read back a file.
- AT fixed-disk controller at 1F0h (new design, issue to be created),
  then boot from the fixed disk.

## M5: OS/2 1.0 and CPGREP

- Settle decision D1 and memory size.
- Boot MS OS/2 1.0 and run `CPGREP -yn fast ..\README`. Compare with the
  PCjs baseline.
- Any 286 defect found here is an escaped defect: failure note, fix in
  `design/intel_80286`, and a new PCE oracle scenario or directed test.

## Risks

- The 8042 needs IBM's firmware; without a sourced dump the controller
  would be a behavioral model and needs an independent check (D3).
- The 286 has no oracle yet for interrupts, NMI and single-step in
  protected mode. OS/2 depends on all three; extend the PCE oracle loop
  before M5.
- Simulation speed: OS/2 boot is hundreds of millions of instructions.
  Measure the Verilator rate during M1 and plan checkpointing if needed.
