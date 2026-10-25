#!/bin/sh
# Run xezim exhaustive and/or UVM simulation inside ai-hw-engineer:latest.
# Usage: ./run_sim.sh [all|exhaustive|uvm]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
UVM_HOME=${UVM_HOME_2017:-/opt/uvm/1800.2-2017}
WORK_DIR="$DESIGN_DIR/work/sim"
MODE=${1:-all}

mkdir -p "$WORK_DIR"

run_exhaustive() {
    log_file="$WORK_DIR/exhaustive.log"
    echo "=== xezim exhaustive simulation ==="
    xezim --simulate --sv2017 --error-exit \
        -s tb_exhaustive \
        "$DESIGN_DIR/src/alu_74181.sv" \
        "$DESIGN_DIR/tb/tb_exhaustive.sv" \
        --max-time 20000ns \
        -l "$log_file"
    cat "$log_file"
    grep -Fq "74181 exhaustive result: 16384 vectors, 81920 field checks," "$log_file"
    grep -Fq "Failures: 0 vectors, 0 fields" "$log_file"
    grep -Fq "TEST PASSED" "$log_file"
}

run_uvm() {
    log_file="$WORK_DIR/uvm_all_modes.log"
    echo "=== xezim UVM 1800.2-2017 all-mode simulation ==="
    xezim --simulate --sv2017 --error-exit \
        -s tb_top \
        -I "$UVM_HOME/src" \
        -I "$DESIGN_DIR/tb" \
        -D UVM_NO_DPI \
        -D UVM_REPORT_DISABLE_FILE_LINE \
        "$UVM_HOME/src/uvm_pkg.sv" \
        "$DESIGN_DIR/src/alu_74181.sv" \
        "$DESIGN_DIR/tb/alu_74181_if.sv" \
        "$DESIGN_DIR/tb/alu_74181_uvm_pkg.sv" \
        "$DESIGN_DIR/tb/tb_top.sv" \
        +UVM_TESTNAME=alu_74181_all_modes_test \
        --max-time 10000ns \
        -l "$log_file"
    cat "$log_file"
    grep -Fq "Checked 64 selector/mode/carry transactions" "$log_file"
    grep -Eq "UVM_ERROR[[:space:]]*:[[:space:]]*0" "$log_file"
    grep -Eq "UVM_FATAL[[:space:]]*:[[:space:]]*0" "$log_file"
}

case "$MODE" in
    exhaustive)
        run_exhaustive
        ;;
    uvm)
        run_uvm
        ;;
    all)
        run_exhaustive
        run_uvm
        ;;
    *)
        echo "ERROR: expected all, exhaustive, or uvm; got '$MODE'" >&2
        exit 2
        ;;
esac

echo "=== Simulation passed: $MODE ==="
