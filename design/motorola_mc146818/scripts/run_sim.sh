#!/bin/sh
# MC146818 simulation: model self-checks, then the Verilator lockstep bench
# against the reference model (scripts/mc146818_model.py, written from the
# data sheet). Usage: run_sim.sh [RANDOM_SEEDS] [OPS_PER_SEED]
# Environment: MC146818_RTL overrides the RTL file (used by run_mutation.sh).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${MC146818_WORK_DIR:-$ROOT/work}/sim
RTL=${MC146818_RTL:-$ROOT/src/motorola_mc146818.sv}
SEEDS=${1:-32}
OPS=${2:-1500}
PY=${PYTHON:-python3}
S=$ROOT/scripts
mkdir -p "$WORK/directed" "$WORK/random" "$WORK/bios"

echo "== model: calendar arithmetic vs Python datetime"
"$PY" "$S/check_calendar.py" 20000 1

echo "== build lockstep benches"
build() {   # NAME FAST_SHIFT [NVRAM]
    g=""
    [ -n "${3:-}" ] && g="-GNVRAM_FILE=\"$3\""
    # shellcheck disable=SC2086
    verilator --cc --exe --build -O2 -j 4 --x-assign 0 --x-initial 0 -Wno-fatal \
        --top-module motorola_mc146818 -GFAST_SHIFT="$2" $g -Mdir "$WORK/obj_$1" \
        "$RTL" "$ROOT/tb/mc146818_tb.cpp" -o mc146818_tb \
        >"$WORK/build_$1.log" 2>&1 || { tail -20 "$WORK/build_$1.log"; exit 1; }
}
build fs0 0
build fs6 6
build warm 0 "$ROOT/tb/nvram/at_cmos_valid.hex"

lockstep() {   # BENCH SCRIPT OUTBASE FAST_SHIFT [NVRAM] -> model checks, RTL trace equal
    "$PY" "$S/mc146818_model.py" "$2" "$3.model" --fast-shift "$4" ${5:+--nvram "$5"} \
        --coverage "$3.cov"
    "$WORK/obj_$1/mc146818_tb" "$2" "$3.rtl"
    if ! cmp -s "$3.model" "$3.rtl"; then
        echo "FAIL: RTL differs from model: $3"
        diff "$3.model" "$3.rtl" | head -10
        exit 1
    fi
}

echo "== directed tests (expected values from the data sheet; RTL vs model)"
"$PY" "$S/directed_tests.py" "$WORK/directed"
n=0
while read -r name fs; do
    lockstep "fs$fs" "$WORK/directed/$name.txt" "$WORK/directed/$name" "$fs"
    n=$((n + 1))
done <"$WORK/directed/list.txt"
echo "PASS: $n directed tests (model meets every expectation; RTL trace identical)"

echo "== random sequences ($SEEDS seeds x $OPS operations, FAST_SHIFT 6)"
s=1
lines=0
ticks=0
while [ "$s" -le "$SEEDS" ]; do
    "$PY" "$S/gen_random_test.py" "$s" "$WORK/random/r$s.txt" "$OPS"
    lockstep fs6 "$WORK/random/r$s.txt" "$WORK/random/r$s" 6
    lines=$((lines + $(wc -l <"$WORK/random/r$s.rtl")))
    t=$(tail -1 "$WORK/random/r$s.rtl" | awk '{print $2}')
    ticks=$((ticks + t))
    s=$((s + 1))
done
echo "PASS: $SEEDS seeds identical ($lines trace lines, $ticks ticks = $((ticks / 512)) simulated seconds)"
if [ -n "${MC146818_NO_COVERAGE_GATE:-}" ]; then
    "$PY" "$S/report_coverage.py" "$WORK"/random/*.cov | tail -1
else
    "$PY" "$S/report_coverage.py" "$WORK"/random/*.cov --require
fi

echo "== IBM PC AT BIOS port 70h/71h sequences"
"$PY" "$S/bios_replay.py" gen "$WORK/bios"
lockstep fs0 "$WORK/bios/bios_cold.txt" "$WORK/bios/bios_cold" 0
"$PY" "$S/bios_replay.py" check "$WORK/bios/bios_cold.rtl" bios_cold
lockstep warm "$WORK/bios/bios_warm.txt" "$WORK/bios/bios_warm" 0 "$ROOT/tb/nvram/at_cmos_valid.hex"
"$PY" "$S/bios_replay.py" check "$WORK/bios/bios_warm.rtl" bios_warm
echo "PASS: simulation"
