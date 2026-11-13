#!/bin/sh
# Synthesize the IBM PC AT 5170 board top with Yosys (generic cells) and
# require a clean `check -assert`. External memory stays outside the top.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
CPU_DIR=$REPO_DIR/design/intel_80286
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
mkdir -p "$WORK_DIR/synth"
SOURCES="$CPU_DIR/src/*.sv $REPO_DIR/design/intel_8253_8254/src/intel_8253_8254.sv
 $REPO_DIR/design/intel_8237/src/intel_8237.sv
 $CPU_DIR/tb/intel_80286_at_timer.sv $CPU_DIR/tb/intel_80286_at_dma.sv
 $CPU_DIR/tb/intel_80286_at_page.sv $CPU_DIR/tb/intel_80286_at_page_map.sv
 $CPU_DIR/tb/intel_80286_at_port61.sv $CPU_DIR/tb/intel_80286_at_refresh_request.sv
 $CPU_DIR/tb/intel_80286_at_refresh_arbiter.sv $CPU_DIR/tb/intel_80286_at_refresh_detect.sv
 $CPU_DIR/tb/intel_80286_at_refresh_row.sv $CPU_DIR/tb/intel_80286_at_refresh_path.sv
 $CPU_DIR/tb/intel_80286_at_refresh_native.sv $CPU_DIR/tb/intel_80286_at_refresh_timer_native.sv
 $CPU_DIR/tb/intel_80286_at_memory_ras.sv $SYS_DIR/src/ibm_pc_at_5170.sv"
echo "== synth: ibm_pc_at_5170"
# shellcheck disable=SC2086
yosys -Q -l "$WORK_DIR/synth/ibm_pc_at_5170.log" -p "read_verilog -sv $(echo $SOURCES); \
    hierarchy -check -top ibm_pc_at_5170; synth -top ibm_pc_at_5170; check -assert; stat; \
    write_json $WORK_DIR/synth/ibm_pc_at_5170.json" > /dev/null
grep -A3 "Number of cells" "$WORK_DIR/synth/ibm_pc_at_5170.log" | tail -4
echo "PASS: ibm_pc_at_5170 synthesized; log $WORK_DIR/synth/ibm_pc_at_5170.log"
