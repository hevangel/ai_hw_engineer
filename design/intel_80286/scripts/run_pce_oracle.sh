#!/bin/sh
# Compare the 80286 RTL with the PCE-286 emulator on generated protected-mode
# scenarios. Usage: run_pce_oracle.sh [-k 'name.pattern*'] [--wait] [--jobs N]
# Needs the opt-in submodule:
#   git submodule update --init --checkout --depth 1 external/pce-286
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$DESIGN_DIR/../.." && pwd)
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}/pce_oracle
PCE=$REPO_DIR/external/pce-286/src
PATTERN='*'
[ -f "$PCE/cpu/e8086/e80286r.c" ] || {
    echo "Missing external/pce-286; run: git submodule update --init --checkout --depth 1 external/pce-286" >&2
    exit 2
}
if [ "${1:-}" = "-k" ]; then PATTERN=$2; fi
mkdir -p "$WORK_DIR"
echo '=== Intel 80286 PCE-286 oracle comparison ==='
gcc -O2 -w -I"$PCE" -o "$WORK_DIR/pce286_oracle" "$DESIGN_DIR/tb/pce_oracle/pce286_oracle.c" \
    "$PCE"/cpu/e8086/*.c "$PCE"/cpu/e8080/*.c
verilator --cc --exe --build -j 4 -Wall --top-module intel_80286 --Mdir "$WORK_DIR/rtl" \
    -CFLAGS -std=c++17 -o replay "$DESIGN_DIR"/src/*.sv "$DESIGN_DIR/tb/pce_oracle/replay.cpp" \
    > "$WORK_DIR/build_rtl.log" 2>&1 || { tail -30 "$WORK_DIR/build_rtl.log" >&2; exit 2; }
python3 "$SCRIPT_DIR/pce_oracle_scenarios.py" "$WORK_DIR/scn" -k "$PATTERN"
exec python3 "$SCRIPT_DIR/pce_oracle_run.py" "$WORK_DIR" "$@"
