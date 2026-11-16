#!/bin/sh
# Yosys generic synthesis of the IBM EGA card. The four 64 KB plane RAMs
# and the 16 KB ROM are black boxes (an FPGA build maps them to block RAM;
# as flip-flops they would be 2.1 million cells). Everything else is
# synthesized: check -assert must be clean and no latch may be inferred.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${EGA_WORK_DIR:-$ROOT/work}
S=$ROOT/src
mkdir -p "$WORK"
echo "== synthesis: ibm_ega (plane RAM and ROM black-boxed)"
yosys -q -l "$WORK/synth.log" -p "
read_verilog -sv $S/ega_plane_ram.sv $S/ega_rom.sv $S/ega_io_decode.sv $S/ega_ext_regs.sv
read_verilog -sv $S/ega_sequencer.sv $S/ega_crtc.sv $S/ega_graphics_ctrl.sv
read_verilog -sv $S/ega_display_fetch.sv $S/ega_attribute_ctrl.sv $S/ibm_ega.sv
blackbox ega_plane_ram ega_rom
synth -flatten -top ibm_ega
check -assert
tee -o $WORK/synth_stat.txt stat
" >/dev/null
grep -E 'Number of cells|cells$|DFF|dff|ega_plane_ram|ega_rom' "$WORK/synth_stat.txt" | head -20
if grep -q 'Latch inferred' "$WORK/synth.log"; then echo "FAIL: latch inferred"; exit 1; fi
echo "PASS: synthesis (check -assert clean, no latches)"
