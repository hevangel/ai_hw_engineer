#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -I/usr/include/iverilog \
    host/front_panel.c -o work/front_panel.vpi
iverilog -g2012 -s tb_front_panel -o work/front_panel.vvp \
 ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
 ../../design/mos_6502/src/mos_6502.sv ../../design/mos_6502/src/a2_mos6502.sv \
 src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
 src/apple_ii_rev0_authored.sv tb/tb_front_panel.sv >work/front_panel_build.log 2>&1 || {
 cat work/front_panel_build.log; exit 1;
}
python3 host/server.py "$@"
