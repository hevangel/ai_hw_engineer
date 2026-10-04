#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/uvm"
UVM_DIR=${UVM_DIR:-/opt/uvm/1800.2-2017/src}
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
xezim --simulate --sv2017 --error-exit -s tb_top \
    -I "$UVM_DIR" -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
    "$UVM_DIR/uvm_pkg.sv" "$DESIGN_DIR/src/amd_am9080_alu.sv" \
    "$DESIGN_DIR/src/amd_am9080.sv" "$DESIGN_DIR/tb/amd_am9080_if.sv" \
    "$DESIGN_DIR/tb/amd_am9080_uvm_pkg.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    --max-time 1100000ns -l "$WORK_DIR/uvm.log" > "$WORK_DIR/console.log" 2>&1
cat "$WORK_DIR/console.log"
cat "$WORK_DIR/uvm.log"
grep -q 'TEST PASSED: 15 UVM control/fault scenarios; 0 failures' "$WORK_DIR/uvm.log"
grep -Eq 'UVM_ERROR[[:space:]]*:[[:space:]]*0' "$WORK_DIR/uvm.log"
grep -Eq 'UVM_FATAL[[:space:]]*:[[:space:]]*0' "$WORK_DIR/uvm.log"
