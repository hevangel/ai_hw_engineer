#!/bin/sh
# End-to-end test of the BUSICOM 141-PF virtual platform.
#
# Boots the full stack headless (no real-time pacing), drives the front
# panel over its HTTP API, and asserts the calculator prints the expected
# results on the paper tape.
#
#   sh scripts/run_system_test.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
WORK_DIR="$SYSTEM_DIR/work/test"
PORT=18099

mkdir -p "$WORK_DIR"
# $readmemh paths in the board resolve against the simulator's working
# directory (src/rom/rom_4001_N.hex), so run from the system folder.
cd "$SYSTEM_DIR"

echo "=== Building panel bridge (test config) ==="
cc -O2 -shared -fPIC -pthread -Werror \
    -DBUSICOM_WEB_DIR_PATH="\"$SYSTEM_DIR/host/web\"" \
    -DBUSICOM_PORT="$PORT" \
    "$SYSTEM_DIR/host/dpi/panel_bridge.c" \
    -o "$WORK_DIR/panel_bridge.so"

echo "=== Starting virtual platform on port $PORT ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_top \
    -D SYSTEM_DPI \
    +spin=${BUSICOM_TEST_SPIN:-740} \
    --dpi-lib "$WORK_DIR/panel_bridge.so" \
    "$DESIGN_DIR/intel_4004/src/intel_4004.sv" \
    "$DESIGN_DIR/intel_4001/src/intel_4001.sv" \
    "$DESIGN_DIR/intel_4002/src/intel_4002.sv" \
    "$DESIGN_DIR/intel_4003/src/intel_4003.sv" \
    "$SYSTEM_DIR/src/busicom_141pf.sv" \
    "$SYSTEM_DIR/tb/tb_top.sv" \
    --max-time 120000000000ns \
    -l "$WORK_DIR/busicom_141pf.log" &
SIM_PID=$!
trap 'kill "$SIM_PID" 2>/dev/null || true' EXIT INT TERM

python3 "$SCRIPT_DIR/check_panel.py" "http://localhost:$PORT"
