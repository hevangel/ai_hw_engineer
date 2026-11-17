#!/bin/sh
# Strict Verilator lint of the IBM EGA RTL (no blanket waivers).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
S=$ROOT/src
SRCS="$S/ega_plane_ram.sv $S/ega_rom.sv $S/ega_io_decode.sv $S/ega_ext_regs.sv \
$S/ega_sequencer.sv $S/ega_crtc.sv $S/ega_graphics_ctrl.sv $S/ega_display_fetch.sv \
$S/ega_attribute_ctrl.sv $S/ibm_ega.sv"
echo "== lint"
# shellcheck disable=SC2086
verilator --lint-only -Wall --top-module ibm_ega $SRCS
for m in ega_io_decode ega_ext_regs ega_sequencer ega_crtc ega_graphics_ctrl \
         ega_display_fetch ega_attribute_ctrl ega_plane_ram ega_rom; do
    verilator --lint-only -Wall --top-module "$m" "$S/$m.sv"
done
echo "PASS: lint (ibm_ega and each sub-module alone)"
