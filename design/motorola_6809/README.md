# Motorola MC6809

The MC6809 (1978) is Motorola's most advanced 8-bit processor: the 6800
architecture extended with a second index register (Y), a second stack
pointer (user U vs system S), a direct-page register, 16-bit arithmetic
(ADDD/SUBD/CMPD), unsigned MUL, position-independent long branches, the
full indexed-postbyte addressing set with indirection, TFR/EXG register
swaps, and a revised interrupt structure (FIRQ with a minimal 2-word
frame, SWI2/SWI3, CWAI, SYNC, E-bit-driven frame restore). It ran OS-9,
served as the CPU of the TRS-80 Color Computer and the Vectrex, and its
architecture directly shapes the Hitachi 6309 and Motorola 68HC11.

Motorola announced the MC6809 in **1978**; secondary sources agree on the
year but differ on the month, so no month-level claim is made here.
Behavior follows the Motorola MC6809 data sheet and M6809 Programming
Manual as cross-checked against [MAME's m6809
core](https://github.com/mamedev/mame/blob/master/src/devices/cpu/m6809/m6809.h)
(vector map) and the hardware-validated reyco2000 test programs.

## This design

- `spec/spec.md` — architectural contract, assumption ledger.
- `src/motorola_6809.sv` — full documented ISA (pages 1/2/3) on a
  functional transaction bus.
- `references/reyco2000_6809/` — vendored S-records and listings from
  [reyco2000/6809_6309_code_tester](https://github.com/reyco2000/6809_6309_code_tester)
  (hardware-validated self-checking programs); `scripts/s19_to_hex.py`
  loads them.
- `tb/tb_top.sv` — the suite's DEV device model (interrupt lines with
  deferred changes, cycle counter, exit port) + pass/fail on DEV_EXIT.
- `formal/motorola_6809.sby` — BMC/prove/cover properties.
- `report/final_report.md` — verification results and the 15 defects the
  third-party suite and formal verification caught during bring-up.
