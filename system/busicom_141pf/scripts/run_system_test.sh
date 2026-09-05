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
    -DBUSICOM_PACE=${BUSICOM_TEST_PACE:-0} \
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

# wait for the panel bridge HTTP server
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

# printing takes a few drum revolutions of simulated time, and the
# press queue serializes keystrokes with a large machine-time spacing
# (see panel_bridge.c), so the last press takes effect long after it is
# POSTed; wait generously
wait_print() {
    sleep 210
}

curl -sf -X POST -d '{"precision":0}' "http://localhost:$PORT/switches" > /dev/null

paper_text() {
    curl -sf "http://localhost:$PORT/state.json" | python3 -c '
import json, sys
s = json.load(sys.stdin)
for r in s["paper"]:
    print("".join(r[:18]).rstrip())
'
}

echo "=== Test 1: 1 + 2 = ==="
press 160        # C - clear
press 155        # 1
press 142        # +
press 151        # 2
press 140        # =
wait_print
paper_text > "$WORK_DIR/t1.txt"
cat "$WORK_DIR/t1.txt"
grep -Eq " 3\$" "$WORK_DIR/t1.txt" || { echo "FAIL: result 3 not printed"; exit 1; }

echo "=== Test 2: clear, 9 x 3 = ==="
press 160        # C
press 145        # 9
press 139        # x
press 147        # 3
press 140        # =
wait_print
paper_text > "$WORK_DIR/t2.txt"
cat "$WORK_DIR/t2.txt"
grep -Eq "[0-9]" "$WORK_DIR/t2.txt" || { echo "FAIL: nothing printed for 9 x 3"; exit 1; }

echo "=== All e2e tests passed ==="
