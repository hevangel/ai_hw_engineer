# Am9513 Specification and Assumption Ledger

Source: 1980 AMD Am9500 Peripheral Products Interface Guide, pp. 4-47..4-71.

## Scope
Functional reconstruction of register/command/counter behavior. Analog timing,
crystal oscillator, MIL-STD testing, and exact microcycles are out of scope.

## Registers
- Master Mode Register (16-bit): FOUT source/divider/gate, bus width, data pointer control, scaler, TOD, comparator enables.
- Per counter: Mode (16-bit), Load (16-bit), Hold (16-bit). Counters 1/2: Alarm (16-bit).
- Status register (8-bit): OUT states and byte pointer.

## Commands (8-bit, control port)
- 0x00 Master Reset
- 0x01..0x3F Load Data Pointer (low 6 bits)
- 0x20..0x3F ARM (mask in low 5 bits) -- overlaps load pointer range; distinguished by 0x20 base? Actually command type by top 3 bits.
- Types by top 3 bits: 000 reset/pointer, 001 ARM, 010 DISARM, 011 LOAD, 100 SAVE, 101 STEP, 110 LOAD&ARM, 111 DISARM&SAVE.

## Assumptions
- ASSUMPTION: 16-bit external bus mode only for verification.
- ASSUMPTION: Counting occurs on system clk; source/gate routing simplified.
- ASSUMPTION: Modes A (no gate) and B (level gate) implemented; other modes treated as A.
- ASSUMPTION: BCD increment/decrement implemented per 4 decades.
- ASSUMPTION: FOUT source fixed to clk.