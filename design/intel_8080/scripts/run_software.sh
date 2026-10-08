#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
sh "$SCRIPT_DIR/check_oracle.sh"
WORK_DIR="$DESIGN_DIR/work/software"
mkdir -p "$WORK_DIR"
for program in TST8080 8080PRE; do
    if [ ! -f "$WORK_DIR/$program.COM" ]; then
        curl --fail --location "https://altairclone.com/downloads/cpu_tests/$program.COM" -o "$WORK_DIR/$program.COM"
    fi
done
printf '%s\n' \
    "9561c6fb6c99efe3de00eb77e4044fd102151058b39ac2d7bce10483838a08e7  $WORK_DIR/TST8080.COM" \
    "18eb3c79cba42c0718f160be6a1853cb64cdce7aa47d65780189a57bdd98c4e0  $WORK_DIR/8080PRE.COM" | sha256sum -c -
gcc -std=c99 -O2 "$SCRIPT_DIR/oracle_trace.c" \
    "$DESIGN_DIR/../amd_am9080/references/superzazu/i8080.c" -o "$WORK_DIR/oracle_trace"
verilator --lint-only -Wall --timing --top-module tb_software \
    "$DESIGN_DIR/src/intel_8080_alu.sv" "$DESIGN_DIR/src/intel_8080.sv" \
    "$DESIGN_DIR/tb/tb_software.sv"
verilator --binary --timing --top-module tb_software -j 4 \
    --Mdir "$WORK_DIR/obj" -o i8080_software \
    "$DESIGN_DIR/src/intel_8080_alu.sv" "$DESIGN_DIR/src/intel_8080.sv" \
    "$DESIGN_DIR/tb/tb_software.sv" > "$WORK_DIR/build.log" 2>&1
for program in TST8080 8080PRE; do
    echo "=== Intel 8080 original historical software: $program ==="
    "$WORK_DIR/oracle_trace" "$WORK_DIR/$program.COM" "$WORK_DIR/$program"
    "$WORK_DIR/obj/i8080_software" "+PREFIX=$WORK_DIR/$program" > "$WORK_DIR/$program.log" 2>&1
    cat "$WORK_DIR/$program.log"
    if grep -Eq '%Fatal|%Error|Assertion failed' "$WORK_DIR/$program.log"; then
        echo 'ERROR: simulator reported a failure' >&2; exit 1
    fi
    grep -q 'TEST PASSED:' "$WORK_DIR/$program.log"
    cmp "$WORK_DIR/$program.console" "$WORK_DIR/$program.rtl-console"
done
grep -q 'CPU IS OPERATIONAL' "$WORK_DIR/TST8080.console"
grep -q '8080 Preliminary tests complete' "$WORK_DIR/8080PRE.console"
echo 'Intel 8080 historical-software differential regression PASSED'
