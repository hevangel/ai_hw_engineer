#!/bin/sh
# Decimal-point E2E test for BUSICOM 141-PF.
# Sets precision=2, computes 1+2, expects a decimal point on the paper.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
WORK_DIR="$SYSTEM_DIR/work/test-decimal"
PORT=18098

mkdir -p "$WORK_DIR"
cd "$SYSTEM_DIR"

echo "=== Building panel bridge (decimal test) ==="
cc -O2 -shared -fPIC -pthread -Werror \
    -DBUSICOM_WEB_DIR_PATH="\"$SYSTEM_DIR/host/web\"" \
    -DBUSICOM_PORT="$PORT" \
    "$SYSTEM_DIR/host/dpi/panel_bridge.c" \
    -o "$WORK_DIR/panel_bridge.so"

echo "=== Starting virtual platform on port $PORT ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_top \
    -D SYSTEM_DPI \
    +spin=740 \
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

python3 "$SCRIPT_DIR/check_panel.py" "http://localhost:$PORT" --decimal
