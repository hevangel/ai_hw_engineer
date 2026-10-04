#!/bin/sh
set -eu
export LANG=C.UTF-8 LC_ALL=C.UTF-8
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
VENDOR="$DESIGN_DIR/references/am2900me/src/main/java/net/maisikoleni/am2900me"
(cd "$DESIGN_DIR/references/am2900me" && sha256sum -c SHA256SUMS)
mkdir -p "$WORK_DIR/oracle"
javac -encoding UTF-8 -d "$WORK_DIR/oracle" "$VENDOR/logic/Am2901.java" \
    "$VENDOR"/logic/microinstr/*.java "$VENDOR/util/BitUtil.java" "$SCRIPT_DIR/Oracle.java"
java -cp "$WORK_DIR/oracle" net.maisikoleni.am2900me.logic.Oracle "$WORK_DIR/vectors.txt" > "$WORK_DIR/oracle.log"
cat "$WORK_DIR/oracle.log"
verilator --cc --exe --build -Wall -fno-dfg --top-module amd_am2901 \
    --Mdir "$WORK_DIR/obj" -CFLAGS '-std=c++17 -O2' \
    "$DESIGN_DIR/src/amd_am2901_alu.sv" "$DESIGN_DIR/src/amd_am2901.sv" \
    "$DESIGN_DIR/tb/slice_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am2901" "$WORK_DIR/vectors.txt" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED: 98304 independent cases' "$WORK_DIR/run.log"
