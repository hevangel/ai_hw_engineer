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
#   BUSICOM_WAVEFORM  1 enables an FST capture of active calculations on
#                     Verilator (default); set 0 to skip tracing
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
BACKEND="${BUSICOM_BACKEND:-xezim}"
PORT="${BUSICOM_PORT:-8080}"
WORK_DIR="$SYSTEM_DIR/work/system-$BACKEND-$PORT"
LOG_FILE="$WORK_DIR/busicom_141pf.log"
WAVEFORM_FILE="$WORK_DIR/waveform.fst"
WAVEFORM="${BUSICOM_WAVEFORM:-1}"
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
    -DBUSICOM_FST_PATH="\"$WAVEFORM_FILE\"" \
    -DBUSICOM_PORT="$PORT" \
    "$SYSTEM_DIR/host/dpi/panel_bridge.c" \
    -o "$WORK_DIR/panel_bridge.so"

if [ -s /opt/surfer/webapp/index.html ]; then
    python3 -m http.server 18080 --bind 0.0.0.0 \
        --directory /opt/surfer/webapp >"$WORK_DIR/surfer-web.log" 2>&1 &
    echo "=== Surfer web viewer: port 18080 ==="
else
    echo "Surfer web assets are missing; rebuild the Docker image to view FST in the panel" >&2
fi

echo "=== BUSICOM 141-PF virtual platform (web panel: http://0.0.0.0:$PORT/) ==="
if [ "$BACKEND" = verilator ]; then
    BUILD_FLAGS="--binary"
    TRACE_MAIN=""
    if [ "$WAVEFORM" = 1 ]; then
        BUILD_FLAGS="--cc --exe --build --trace-fst --trace-depth 2"
        TRACE_MAIN="$SYSTEM_DIR/host/trace_main.cpp"
        export BUSICOM_FST_PATH="$WAVEFORM_FILE"
        echo "=== Recording active calculations to $WAVEFORM_FILE ==="
    fi
    verilator $BUILD_FLAGS --timing -Wno-fatal --top-module tb_top \
        -DSYSTEM_DPI --Mdir "$WORK_DIR/obj_dir" -j 4 \
        -LDFLAGS "$WORK_DIR/panel_bridge.so -Wl,-rpath,$WORK_DIR -pthread" \
        "$DESIGN_DIR/intel_4004/src/intel_4004.sv" \
        "$DESIGN_DIR/intel_4001/src/intel_4001.sv" \
        "$DESIGN_DIR/intel_4002/src/intel_4002.sv" \
        "$DESIGN_DIR/intel_4003/src/intel_4003.sv" \
        "$SYSTEM_DIR/src/busicom_141pf.sv" "$SYSTEM_DIR/tb/tb_top.sv" \
        ${TRACE_MAIN:+$TRACE_MAIN}
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
