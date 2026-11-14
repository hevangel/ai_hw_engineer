#!/bin/sh
# Build the IBM PC AT 5170 board under Verilator, run the unchanged REV1 BIOS
# until the first unmodeled hardware access, and check the run three ways:
#   - it stops exactly at the boundary in scripts/expected_stop.txt;
#   - every executed 80286 instruction matches Unicorn;
#   - the 8042 on the board matches the UPI-42 reference model.
#
# Usage: scripts/run_post.sh /path/to/atbios.bin
# Output: $IBM_PC_AT_WORK_DIR (default system/ibm_pc_at_5170/work)/post
# The 8042 firmware (IBM 1503033) is rebuilt and hash-checked by
# design/intel_mcs48/intel_8042/scripts/rebuild_1503033.py.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
OUT_DIR=$WORK_DIR/post
. "$SCRIPT_DIR/sources.sh"
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
ROM=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f "$ROM" | sha256sum -c -
mkdir -p "$OUT_DIR"
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --quiet --target "$WORK_DIR/oracle" unicorn==2.1.4
fi

echo "== 8042 firmware: rebuild IBM 1503033 and verify its hash"
KBC_ROM=$(python3 "$KBC_DIR/scripts/rebuild_1503033.py" --work "$WORK_DIR/kbc")
od -An -v -tx1 -w1 "$KBC_ROM" | tr -d ' ' > "$OUT_DIR/kbc_1503033.hex"
[ "$(wc -l < "$OUT_DIR/kbc_1503033.hex")" -eq 2048 ]

# shellcheck disable=SC2086
sha256sum $BOARD_RTL "$SYS_DIR/tb/ibm_pc_at_5170_tb.sv" "$SYS_DIR/tb/post_runner.cpp" \
    "$SCRIPT_DIR/run_post.sh" "$SCRIPT_DIR/sources.sh" "$SCRIPT_DIR/check_post_trace.py" \
    "$SCRIPT_DIR/check_kbc_log.py" "$SCRIPT_DIR/expected_stop.txt" \
    "$CPU_DIR/scripts/bios_replay.py" "$CPU_DIR/scripts/generate_firmware_trace.py" \
    "$KBC_DIR/scripts/upi42_iss.py" "$KBC_ROM" "$ROM" > "$OUT_DIR/inputs.sha256"
{ verilator --version; g++ --version | head -n 1; python3 --version; } > "$OUT_DIR/toolchain.txt"

echo "== lint: ibm_pc_at_5170"
# shellcheck disable=SC2086
verilator --lint-only -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps --top-module ibm_pc_at_5170 $BOARD_RTL

echo "== build"
# shellcheck disable=SC2086
if ! verilator --cc --exe --build -j 4 -O3 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    "-GKBC_ROM_FILE=\"$OUT_DIR/kbc_1503033.hex\"" \
    --top-module ibm_pc_at_5170_tb --Mdir "$OUT_DIR/obj" $BOARD_RTL \
    "$SYS_DIR/tb/ibm_pc_at_5170_tb.sv" "$SYS_DIR/tb/post_runner.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi

EXPECTED=$(grep -v '^#' "$SCRIPT_DIR/expected_stop.txt")
STOP_AT=$(echo "$EXPECTED" | sed -n 's/.* at=\([0-9A-F]*:[0-9A-F]*\).*/\1/p')
status=0
for scenario in '0 8' '1 11'; do
    set -- $scenario
    tag=wait${1}_half${2}
    echo "== run: $tag"
    "$OUT_DIR/obj/Vibm_pc_at_5170_tb" "$ROM" "$OUT_DIR/trace_$tag.txt" "$1" "$2" \
        "$OUT_DIR/kbc_$tag.txt" | tee "$OUT_DIR/run_$tag.log"
    stop=$(sed -n 's/^STOP \(kind=[^ ]* [^ ]* *[^ ]*\) post=\([0-9A-F]*\).*/\1 post=\2/p' "$OUT_DIR/run_$tag.log")
    if [ "$stop" != "$EXPECTED" ]; then
        echo "FAIL: $tag stopped at '$stop', expected '$EXPECTED'" >&2
        status=1
        continue
    fi
    echo "== 80286 oracle: $tag"
    if ! PYTHONPATH="$WORK_DIR/oracle:$CPU_DIR/scripts${PYTHONPATH:+:$PYTHONPATH}" \
        python3 "$SCRIPT_DIR/check_post_trace.py" "$ROM" "$OUT_DIR/trace_$tag.txt" "$STOP_AT" \
        > "$OUT_DIR/oracle_$tag.log" 2>&1; then
        cat "$OUT_DIR/oracle_$tag.log" >&2
        status=1
        continue
    fi
    cat "$OUT_DIR/oracle_$tag.log"
    echo "== 8042 reference model: $tag"
    if ! python3 "$SCRIPT_DIR/check_kbc_log.py" "$KBC_ROM" "$OUT_DIR/kbc_$tag.txt" \
        > "$OUT_DIR/kbc_check_$tag.log" 2>&1; then
        cat "$OUT_DIR/kbc_check_$tag.log" >&2
        status=1
        continue
    fi
    cat "$OUT_DIR/kbc_check_$tag.log"
done
sha256sum -c "$OUT_DIR/inputs.sha256" > "$OUT_DIR/source_verification.log"
[ "$status" -eq 0 ] && echo "PASS: both scenarios stopped at: $EXPECTED"
exit "$status"
