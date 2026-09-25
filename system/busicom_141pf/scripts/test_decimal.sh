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
    -DBUSICOM_PACE=0 \
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

i=0
while [ "$i" -lt 100 ]; do
    if curl -sf "http://localhost:$PORT/state.json" > /dev/null 2>&1; then
        break
    fi
    i=$((i + 1))
    sleep 0.2
done
if [ "$i" -ge 100 ]; then
    echo "FAIL: panel bridge did not come up"
    exit 1
fi

press() {
    curl -sf -X POST -d "{\"code\":$1}" "http://localhost:$PORT/press" > /dev/null
    sleep 1
}

paper_text() {
    curl -sf "http://localhost:$PORT/state.json" | python3 -c '
import json, sys
s = json.load(sys.stdin)
for r in s["paper"]:
    print("".join(r[:18]).rstrip())
'
}

echo "=== Setting precision=2 ==="
curl -sf -X POST -d '{"precision":2}' "http://localhost:$PORT/switches" > /dev/null

echo "=== Test: 1 + 2 = (expect decimal point) ==="
press 160        # C
press 155        # 1
press 142        # +
press 151        # 2
press 140        # =
sleep 60
paper_text > "$WORK_DIR/paper.txt"
cat "$WORK_DIR/paper.txt"
grep -F "." "$WORK_DIR/paper.txt" || { echo "FAIL: decimal point not printed"; exit 1; }

echo "=== Decimal test passed ==="
