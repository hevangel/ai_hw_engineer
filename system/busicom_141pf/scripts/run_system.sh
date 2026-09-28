#!/bin/sh
# Run the BUSICOM 141-PF virtual platform: RTL simulation + panel bridge
# + web front panel in one process.
#
#   sh scripts/run_system.sh
#
# Then open http://localhost:8080/ (map the port when running docker:
#   docker run --rm -p 8080:8080 ... sh /workspace/system/busicom_141pf/scripts/run_system.sh
#
# Environment:
#   BUSICOM_PORT  web panel port (default 8080)
#   BUSICOM_BACKEND  xezim (default) or verilator
#   BUSICOM_SPIN  machine cycles per drum half-spin (default 1481)
#   BUSICOM_REALTIME  1 paces interactive drum ticks to the 4004 clock;
#                     default 0 keeps batch regressions unpaced
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
BACKEND="${BUSICOM_BACKEND:-xezim}"
PORT="${BUSICOM_PORT:-8080}"
WORK_DIR="$SYSTEM_DIR/work/system-$BACKEND-$PORT"
LOG_FILE="$WORK_DIR/busicom_141pf.log"
# The recovered emulator uses 1481 machine cycles per drum half-spin.
SPIN="${BUSICOM_SPIN:-1481}"
export BUSICOM_SPIN="$SPIN"

mkdir -p "$WORK_DIR"
# $readmemh paths in the board resolve against the simulator's working
# directory (src/rom/rom_4001_N.hex), so run from the system folder.
cd "$SYSTEM_DIR"

echo "=== Building panel bridge ==="
cc -O2 -shared -fPIC -pthread \
    -DBUSICOM_WEB_DIR_PATH="\"$SYSTEM_DIR/host/web\"" \
    -DBUSICOM_PORT="$PORT" \
    "$SYSTEM_DIR/host/dpi/panel_bridge.c" \
    -o "$WORK_DIR/panel_bridge.so"

echo "=== BUSICOM 141-PF virtual platform (web panel: http://0.0.0.0:$PORT/) ==="
if [ "$BACKEND" = verilator ]; then
    verilator --binary --timing -Wno-fatal --top-module tb_top \
        -DSYSTEM_DPI --Mdir "$WORK_DIR/obj_dir" -j 4 \
        -LDFLAGS "$WORK_DIR/panel_bridge.so -Wl,-rpath,$WORK_DIR -pthread" \
        "$DESIGN_DIR/intel_4004/src/intel_4004.sv" \
        "$DESIGN_DIR/intel_4001/src/intel_4001.sv" \
        "$DESIGN_DIR/intel_4002/src/intel_4002.sv" \
        "$DESIGN_DIR/intel_4003/src/intel_4003.sv" \
        "$SYSTEM_DIR/src/busicom_141pf.sv" "$SYSTEM_DIR/tb/tb_top.sv"
    exec "$WORK_DIR/obj_dir/Vtb_top" "+spin=$SPIN"
fi
if [ "$BACKEND" != xezim ]; then
    echo "Unknown BUSICOM_BACKEND: $BACKEND" >&2
    exit 2
fi
# XEZIM_JIT / XEZIM_AOT may be supplied by the caller. The old claimed
# miscompile was retracted (upstream #153); record the mode in test reports.
exec xezim --simulate --sv2017 --error-exit \
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
