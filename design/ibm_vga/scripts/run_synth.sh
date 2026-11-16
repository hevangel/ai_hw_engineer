#!/bin/sh
# Yosys generic synthesis of the IBM VGA card. The four 64 KB plane RAMs
# and the 32 KB ROM are black boxes (an FPGA build maps them to block RAM);
# everything else, including the 256 x 18 DAC palette, is synthesized:
# check -assert must be clean and no latch may be inferred.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${VGA_WORK_DIR:-$ROOT/work}
S=$ROOT/src
mkdir -p "$WORK"
echo "== synthesis: ibm_vga (plane RAM and ROM black-boxed)"
yosys -q -l "$WORK/synth.log" -p "
read_verilog -sv $S/vga_plane_ram.sv $S/vga_rom.sv $S/vga_io_decode.sv $S/vga_general_regs.sv
read_verilog -sv $S/vga_sequencer.sv $S/vga_crtc.sv $S/vga_graphics_ctrl.sv
read_verilog -sv $S/vga_display_fetch.sv $S/vga_attribute_ctrl.sv $S/vga_dac.sv $S/ibm_vga.sv
blackbox vga_plane_ram vga_rom
synth -flatten -top ibm_vga
check -assert
tee -o $WORK/synth_stat.txt stat
" >/dev/null
grep -E 'Number of cells|cells$|DFF|dff|vga_plane_ram|vga_rom' "$WORK/synth_stat.txt" | head -20
if grep -q 'Latch inferred' "$WORK/synth.log"; then echo "FAIL: latch inferred"; exit 1; fi
echo "PASS: synthesis (check -assert clean, no latches)"
