#!/bin/sh
# Synthesize the IBM PC AT 5170 board top, the diskette adapter, and the
# machines with the EGA and the VGA
# card (each with the diskette adapter), with Yosys (generic cells) and
# require a clean `check -assert`.
# External memory stays outside the top;
# the 8042's program ROM is left unloaded (no KBC_ROM_FILE).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
. "$SCRIPT_DIR/sources.sh"
mkdir -p "$WORK_DIR/synth"
echo "== synth: ibm_pc_at_5170"
# shellcheck disable=SC2086
yosys -Q -l "$WORK_DIR/synth/ibm_pc_at_5170.log" -p "read_verilog -sv $(echo $BOARD_RTL); \
    hierarchy -check -top ibm_pc_at_5170; synth -top ibm_pc_at_5170; check -assert; stat; \
    write_json $WORK_DIR/synth/ibm_pc_at_5170.json" > /dev/null
# The one latch on the board is the refresh arbiter's hold latch, a latch on
# the schematic (see the M1 report). Any other inferred latch is an error.
if grep 'Latch inferred' "$WORK_DIR/synth/ibm_pc_at_5170.log" | grep -v 'refresh_arbiter.*hold_latched'; then
    echo "FAIL: unexpected latch inferred" >&2
    exit 1
fi
grep -E '^ +[0-9]+ cells$' "$WORK_DIR/synth/ibm_pc_at_5170.log" | tail -1
echo "PASS: ibm_pc_at_5170 synthesized; log $WORK_DIR/synth/ibm_pc_at_5170.log"

# The diskette adapter on its own (with the 8272), for its cell count; the
# machines below contain it.
echo "== synth: at_diskette_adapter"
yosys -Q -l "$WORK_DIR/synth/at_diskette_adapter.log" -p "read_verilog -sv \
    $REPO_DIR/design/intel_8272/src/intel_8272.sv $SYS_DIR/src/at_diskette_adapter.sv; \
    hierarchy -check -top at_diskette_adapter; synth -top at_diskette_adapter; check -assert; stat" > /dev/null
if grep 'Latch inferred' "$WORK_DIR/synth/at_diskette_adapter.log"; then
    echo "FAIL: unexpected latch inferred" >&2
    exit 1
fi
grep -E '^ +[0-9]+ cells$' "$WORK_DIR/synth/at_diskette_adapter.log" | tail -1
echo "PASS: at_diskette_adapter synthesized; log $WORK_DIR/synth/at_diskette_adapter.log"

# The machine with the EGA card: the card's four 64 KB plane RAMs and its
# ROM are black boxes, as in the card's own synthesis.
echo "== synth: ibm_pc_at_5170_ega"
# shellcheck disable=SC2086
yosys -Q -l "$WORK_DIR/synth/ibm_pc_at_5170_ega.log" -p "read_verilog -sv $(echo $BOARD_RTL $CHANNEL_RTL $EGA_RTL)     $SYS_DIR/src/ibm_pc_at_5170_ega.sv; blackbox ega_plane_ram ega_rom;     hierarchy -check -top ibm_pc_at_5170_ega; synth -top ibm_pc_at_5170_ega; check -assert; stat" > /dev/null
if grep 'Latch inferred' "$WORK_DIR/synth/ibm_pc_at_5170_ega.log" | grep -v 'refresh_arbiter.*hold_latched'; then
    echo "FAIL: unexpected latch inferred" >&2
    exit 1
fi
grep -E '^ +[0-9]+ cells$' "$WORK_DIR/synth/ibm_pc_at_5170_ega.log" | tail -1
echo "PASS: ibm_pc_at_5170_ega synthesized; log $WORK_DIR/synth/ibm_pc_at_5170_ega.log"

# The machine with the VGA card, its plane RAMs and ROM black boxes too.
echo "== synth: ibm_pc_at_5170_vga"
# shellcheck disable=SC2086
yosys -Q -l "$WORK_DIR/synth/ibm_pc_at_5170_vga.log" -p "read_verilog -sv $(echo $BOARD_RTL $CHANNEL_RTL $VGA_RTL)     $SYS_DIR/src/ibm_pc_at_5170_vga.sv; blackbox vga_plane_ram vga_rom;     hierarchy -check -top ibm_pc_at_5170_vga; synth -top ibm_pc_at_5170_vga; check -assert; stat" > /dev/null
if grep 'Latch inferred' "$WORK_DIR/synth/ibm_pc_at_5170_vga.log" | grep -v 'refresh_arbiter.*hold_latched'; then
    echo "FAIL: unexpected latch inferred" >&2
    exit 1
fi
grep -E '^ +[0-9]+ cells$' "$WORK_DIR/synth/ibm_pc_at_5170_vga.log" | tail -1
echo "PASS: ibm_pc_at_5170_vga synthesized; log $WORK_DIR/synth/ibm_pc_at_5170_vga.log"
