# IBM EGA formal plan

Three SymbiYosys runs (`scripts/run_formal.sh`), each with an unbounded
proof (`abc pdr`) and covers (`smtbmc yices`). Every property is inside
`` `ifdef FORMAL ``; the first cycle is in `rst_n` reset and clocked
properties are guarded with `$past(rst_n) && rst_n`.

## `formal/ega_graphics_ctrl.sby` (one graphics controller)

All inputs free (register writes, position, processor data, plane read
data, latch loads). Proved:
- write-mode data equations (TR p.47-55) for planes 0 and 1 of the chip on
  one `anyconst` bit slice `b`: write mode 0 (data rotated right, written
  as index `(b + count) mod 8`, independent of the RTL's shift
  expression; set/reset per plane by position), write mode 1 (latch),
  write mode 2 (CPU data bit n), the AND/OR/XOR function with the latch
  and the bit mask; write mode 3 writes nothing;
- read path: read mode 1 colour compare with don't care (E15) on bit `b`;
  read mode 0 plane selection (read map select, odd/even with A0) and
  which chip drives (position);
- stored register widths (undocumented bits read 0).

Covers: each write mode with its feature in use (set/reset with rotate,
latch copy, write mode 2 with XOR, write mode 3) and a read-mode-1 result.

## `formal/ega_crtc.sby` (CRT controller)

The 25 registers are arbitrary constants: under FORMAL `rst_n` does not
clear them and data writes are assumed away, so every register value is
covered at once. RESET DRV is held low.

Proved with bounds (prove task, `FORMAL_PROVE`): Horizontal Total <= 48,
Vertical Total <= 30, the horizontal retrace starts at least 32 characters
before the end of the line and the vertical retrace at least 16 lines
before the end of the frame (so neither pulse wraps), HRTC/2 off:
- the horizontal counter stays below HT+2 and the vertical counter at or
  below VT+1;
- a horizontal retrace that ends has exactly the TR p.29 width
  ((End - Start) mod 32, 0 meaning 32) in characters; a vertical retrace
  that ends has the TR p.37 width ((End - Start) mod 16, 0 meaning 16) in
  lines (with inductive helper invariants relating the width counters to
  the character and line counters);
- vertical retrace starts only on the programmed line;
- the vertical interrupt latch rises only at the start of vertical retrace
  with VRE bit 5 = 0, and is 0 while VRE bit 4 = 0.

Covers (HT and VT <= 3): a complete frame (the line counter wraps after
VT+1), and a vertical retrace start with the interrupt latch set.

Not proved formally: retraces that wrap the line or frame (the counter
skips low-bit values at the wrap, so the 5-bit/4-bit end compare can miss;
simulation covers such programming in the random seeds), HRTC/2.

## `formal/ibm_ega.sby` (card top)

The four plane RAMs and the ROM are abstracted under FORMAL: their read
data are unconstrained every clock. All slot, oscillator, switch, jumper,
feature and light-pen inputs are free. Proved:
- register access rules: an I/O read drives the data bus only at Input
  Status 0 (3C2), Input Status 1 (3xA) and the CRTC data port (3x5), with
  the U16 conditions (AEN low, A9, A8 per P3); every write-only register
  never drives;
- a memory read drives only for the ROM (C0000h-C3FFFh) or the enabled RAM
  window, never during DACK0; nothing drives without a read strobe;
- decode exclusivity: at most one I/O select; ROM and RAM selects disjoint;
- map-mask gating: a plane is written only on a memory write in the RAM
  window with its Map Mask bit set and, in odd/even mode, matching address
  parity;
- attribute address/data flip-flop: reset by an Input Status 1 read,
  toggled by each 3C0 write, otherwise held;
- IRQ 2 driver enable follows VRE bit 5.

Covers: write modes 0, 1 and 2 writing a plane, write mode 3 reaching the
write event, and a flip-flop reset from the data state.

Pixel data paths, the text attribute decode and the BIOS behaviour are
verified by lockstep simulation, not formally.
