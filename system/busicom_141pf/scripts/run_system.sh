#!/bin/sh
# Run the BUSICOM 141-PF virtual platform: xezim simulation + panel bridge
# + web front panel in one process.
#
#   sh scripts/run_system.sh
#
# Then open http://localhost:8080/ (map the port when running docker:
#   docker run --rm -p 8080:8080 ... sh /workspace/system/busicom_141pf/scripts/run_system.sh
#
# Environment:
#   BUSICOM_PORT  web panel port (default 8080)
#   BUSICOM_PACE  1 = real-time pacing of the simulated machine (default 1)
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
WORK_DIR="$SYSTEM_DIR/work/system"
LOG_FILE="$WORK_DIR/busicom_141pf.log"

PORT="${BUSICOM_PORT:-8080}"
# PACE=1 (sleeping ~16 ms inside a DPI call every tick) correlates with
# dropped/garbled key registration on the reference host and achieves
# nothing there - the interpreter simulates slower than real time with
# or without it. Keep it off until an xezim fix; see report known issues.
PACE="${BUSICOM_PACE:-0}"
# spin=740: the firmware's key-dispatch cadence is coupled to the drum
# rate, and at the authentic 1481 the host key presses register garbled
# (see report known issues). 740 is the E2E-verified configuration.
SPIN="${BUSICOM_SPIN:-740}"

mkdir -p "$WORK_DIR"
# $readmemh paths in the board resolve against the simulator's working
# directory (src/rom/rom_4001_N.hex), so run from the system folder.
cd "$SYSTEM_DIR"

echo "=== Building panel bridge ==="
cc -O2 -shared -fPIC -pthread \
    -DBUSICOM_WEB_DIR_PATH="\"$SYSTEM_DIR/host/web\"" \
    -DBUSICOM_PORT="$PORT" \
    -DBUSICOM_PACE="$PACE" \
    "$SYSTEM_DIR/host/dpi/panel_bridge.c" \
    -o "$WORK_DIR/panel_bridge.so"

echo "=== BUSICOM 141-PF virtual platform (web panel: http://0.0.0.0:$PORT/) ==="
# NOTE: deliberately NOT using XEZIM_JIT/AOT - those backends miscompile
# this board (E2E prints wrong results with them enabled; interpreter is
# correct). Revisit only after an upstream xezim fix.
xezim --simulate --sv2017 --error-exit \
    -s tb_top \
    -D SYSTEM_DPI \
    ${BUSICOM_DEBUG:+-D DEBUG_TRACE} \
    ${SPIN:++spin=$SPIN} \
    --dpi-lib "$WORK_DIR/panel_bridge.so" \
    "$DESIGN_DIR/intel_4004/src/intel_4004.sv" \
    "$DESIGN_DIR/intel_4001/src/intel_4001.sv" \
    "$DESIGN_DIR/intel_4002/src/intel_4002.sv" \
    "$DESIGN_DIR/intel_4003/src/intel_4003.sv" \
    "$SYSTEM_DIR/src/busicom_141pf.sv" \
    "$SYSTEM_DIR/tb/tb_top.sv" \
    --max-time 86400000000000ns \
    -l "$LOG_FILE"
