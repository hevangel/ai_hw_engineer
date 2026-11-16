#!/bin/sh
# Strict Verilator lint of the IBM VGA RTL (no blanket waivers): the card
# top and every sub-module on its own.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
S=$ROOT/src
MODS="vga_plane_ram vga_rom vga_io_decode vga_general_regs vga_sequencer vga_crtc \
vga_graphics_ctrl vga_display_fetch vga_attribute_ctrl vga_dac"
SRCS=""
for m in $MODS; do SRCS="$SRCS $S/$m.sv"; done
echo "== lint"
# shellcheck disable=SC2086
verilator --lint-only -Wall --top-module ibm_vga $SRCS "$S/ibm_vga.sv"
for m in $MODS; do
    verilator --lint-only -Wall --top-module "$m" "$S/$m.sv"
done
echo "PASS: lint (ibm_vga and each of the 10 sub-modules alone)"
