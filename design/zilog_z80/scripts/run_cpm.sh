#!/bin/sh
# Run a CP/M-80 .com image on the Z80 core through the BDOS harness.
#
# Usage: sh design/zilog_z80/scripts/run_cpm.sh <image.com> [max_instructions]
#
# Binaries are downloaded into the ignored work/cpm directory; see
# references/README.md for provenance.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/cpm"
OBJ_DIR="$WORK_DIR/obj_dir"

mkdir -p "$WORK_DIR"

IMAGE=${1:-"$WORK_DIR/prelim.com"}
LIMIT=${2:-2000000}

VERILATOR=${VERILATOR:-verilator}

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  "$VERILATOR" \
      --cc --exe --build -j 0 -O2 \
      --top-module zilog_z80 \
      --Mdir "$OBJ_DIR" \
      -I"$DESIGN_DIR/src" \
      "$DESIGN_DIR/src/zilog_z80_alu.sv" \
      "$DESIGN_DIR/src/zilog_z80.sv" \
      "$DESIGN_DIR/tb/cpm_harness.cpp" \
      -o cpm_harness
fi

"$OBJ_DIR/cpm_harness" "$IMAGE" "$LIMIT"
