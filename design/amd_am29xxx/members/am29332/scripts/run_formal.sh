#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/formal"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
sby -f "$DESIGN_DIR/formal/amd_am29332.sby" bmc 2>&1 | tee bmc.log
sby -f "$DESIGN_DIR/formal/amd_am29332.sby" prove 2>&1 | tee prove.log
sby -f "$DESIGN_DIR/formal/amd_am29332.sby" cover 2>&1 | tee cover.log
grep -q 'PASS' bmc.log
grep -q 'PASS' prove.log
grep -q 'PASS' cover.log
