#!/bin/sh
# Run the scanned manual's JSON examples without opening a browser.
# BUSICOM_BACKEND=xezim (default) or verilator; remaining args go to replay_manual.py.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
export BUSICOM_PORT="${BUSICOM_PORT:-18097}"
WORK_DIR="$SYSTEM_DIR/work/manual-${BUSICOM_BACKEND:-xezim}-$BUSICOM_PORT"
mkdir -p "$WORK_DIR"
# Refuse to send replay events to a pre-existing server on the test port.
python3 -c 'import os,socket; s=socket.socket(); s.bind(("127.0.0.1",int(os.environ["BUSICOM_PORT"]))); s.close()'
sh "$SCRIPT_DIR/run_system.sh" > "$WORK_DIR/simulator.log" 2>&1 &
SIM_PID=$!
trap 'kill "$SIM_PID" 2>/dev/null || true' EXIT INT TERM
python3 "$SCRIPT_DIR/replay_manual.py" --url "http://127.0.0.1:$BUSICOM_PORT" \
    --report "$WORK_DIR/results.json" "$@"
