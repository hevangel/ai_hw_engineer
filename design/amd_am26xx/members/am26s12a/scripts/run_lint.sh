#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
# The Am26S12A uses the shared am26s12 source at REVISION 1 (see the
# parent issue's revision rule); lint it with the S12A parameterization.
mkdir -p "$DESIGN_DIR/work/lint"
echo "=== Am26S12A Verilator lint (RTL, no waivers) ==="
verilator --lint-only -Wall --top-module am26s12 -GREVISION=1 \
    "$DESIGN_DIR/../am26s12/src/am26s12.sv" \
    > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
echo "=== Am26S12A Verilator lint (TB waivers) ==="
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY --timing --top-module tb_top \
    "$DESIGN_DIR/../am26s12/src/am26s12.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    > "$DESIGN_DIR/work/lint/tb.log" 2>&1
echo "Am26S12A LINT PASSED"
