#!/bin/sh
# Build the web/batch simulator of the AT with the VGA card
# (host/simulator.cpp on host/ibm_pc_at_5170_vga_host.sv).
#
# Usage: scripts/build_host.sh /path/to/atbios.bin
# Checks the BIOS hash, rebuilds and hash-checks the 8042 firmware and
# fetches and hash-checks the VGA ROM exactly as scripts/run_post_card.sh
# does, then builds into $IBM_PC_AT_WORK_DIR (default work)/host.
# Prints the paths the simulator needs on its last line:
#   HOST <simulator> <bios> <vga-rom-bin>
# Environment: AT_HOST_THREADS=N builds a multithreaded model (--threads N).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
. "$SCRIPT_DIR/sources.sh"
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
ROM=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f "$ROM" | sha256sum -c - >&2
OUT_DIR=$WORK_DIR/host
mkdir -p "$OUT_DIR"

echo "== 8042 firmware: rebuild IBM 1503033 and verify its hash" >&2
KBC_ROM=$(python3 "$KBC_DIR/scripts/rebuild_1503033.py" --work "$WORK_DIR/kbc")
od -An -v -tx1 -w1 "$KBC_ROM" | tr -d ' ' > "$OUT_DIR/kbc_1503033.hex"
[ "$(wc -l < "$OUT_DIR/kbc_1503033.hex")" -eq 2048 ]

echo "== VGA ROM: fetch the IBM PS/2 Display Adapter BIOS and verify its hashes" >&2
python3 "$VGA_DIR/scripts/get_rom.py" "$WORK_DIR/vga" > "$OUT_DIR/card_rom.log"
VGA_BIN=$WORK_DIR/vga/firmware/vga_rom.bin
VGA_HEX=$WORK_DIR/vga/firmware/vga_rom.hex
[ -f "$VGA_BIN" ] && [ -f "$VGA_HEX" ]

THREADS=${AT_HOST_THREADS:-1}
OBJ_DIR=${AT_HOST_OBJ:-$OUT_DIR/obj}
# C++ optimization of the generated model; Verilator's default is -Os.
OPT=${AT_HOST_OPT:--O2}
echo "== build host simulator (threads $THREADS)" >&2
# shellcheck disable=SC2086
if ! verilator --cc --exe --build -j 8 -O3 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    --threads "$THREADS" --trace-fst --trace-depth 1 \
    -CFLAGS "-std=c++17 -DAT_DISKETTE -I$SYS_DIR/tb" -LDFLAGS "-lz" \
    -MAKEFLAGS "OPT_FAST=$OPT OPT_GLOBAL=$OPT" \
    "-GKBC_ROM_FILE=\"$OUT_DIR/kbc_1503033.hex\"" \
    "-GRTC_NVRAM_FILE=\"$SYS_DIR/tb/cmos_ega.hex\"" \
    "-GVGA_ROM_FILE=\"$VGA_HEX\"" \
    --top-module ibm_pc_at_5170_vga_host --Mdir "$OBJ_DIR" $BOARD_RTL $CHANNEL_RTL $VGA_RTL \
    "$SYS_DIR/src/ibm_pc_at_5170_vga.sv" "$SYS_DIR/host/ibm_pc_at_5170_vga_host.sv" \
    "$SYS_DIR/host/simulator.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi
echo "HOST $OBJ_DIR/Vibm_pc_at_5170_vga_host $ROM $VGA_BIN"
